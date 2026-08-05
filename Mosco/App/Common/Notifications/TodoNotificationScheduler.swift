import Foundation
import Observation
import OSLog
import UserNotifications

private let logger = Logger(subsystem: "com.Mosco.App", category: "notifications")

/// 시작 시간이 있는 할 일에 대해, 그 할 일이 속한 카테고리 설정대로 "몇 분 전"
/// 로컬 알림을 예약한다.
///
/// 반복 일정은 저장소에 복제본이 없고 규칙으로 계산되므로(TodoItem+Recurrence),
/// UNCalendarNotificationTrigger의 반복 기능에 기대지 않고 앞으로 며칠치 인스턴스를
/// 직접 펼쳐서 하나씩 예약한다 — 규칙(격일, 특정 요일, N일마다 등)이 캘린더 트리거로
/// 표현되지 않는 게 많고, 표현되는 것만 따로 처리하면 두 갈래 로직이 생긴다.
///
/// 예약은 "전부 지우고 다시 깔기"로 단순하게 간다. 할 일 하나가 바뀔 때마다 어떤
/// 알림이 영향을 받는지 따지는 대신, 데이터가 바뀌면 통째로 다시 계산한다 —
/// 개인용 앱 규모에서는 이 편이 훨씬 안전하고 디버깅할 게 없다.
@Observable
final class TodoNotificationScheduler {
    /// 시스템 알림 권한 상태 — 설정 화면에서 안내 문구를 고르는 데 쓴다.
    private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined

    /// 앱 전체 알림 스위치. 카테고리별 설정은 그대로 두고 이것만 꺼서 한 번에
    /// 멈출 수 있다 — 카테고리를 하나씩 끄고 나중에 되돌리는 것보다 간단하다.
    var isEnabled: Bool {
        didSet { UserDefaults.standard.set(isEnabled, forKey: Self.enabledKey) }
    }

    private static let enabledKey = "notificationsEnabled"

    /// iOS가 앱당 허용하는 대기 중 로컬 알림은 64개다. 그 안에서 가까운 것부터
    /// 채우고, 나머지는 다음 실행 때 다시 계산되며 자연히 채워진다.
    private static let pendingLimit = 60
    /// 반복 일정을 며칠치까지 펼칠지. 너무 길게 잡아도 64개 제한에 걸려 잘린다.
    private static let horizonDays = 60

    @ObservationIgnored private let center = UNUserNotificationCenter.current()
    @ObservationIgnored private let calendar = Calendar.current
    @ObservationIgnored private let foregroundPresenter = ForegroundNotificationPresenter()

    init() {
        // 키가 없으면(첫 실행) 켜진 상태로 시작한다.
        isEnabled = UserDefaults.standard.object(forKey: Self.enabledKey) as? Bool ?? true
        // 앱을 켜둔 채로는 알림이 안 뜬다는 게 iOS 기본 동작이라, 안 붙이면
        // "예약은 됐는데 알림이 안 온다"로 보인다.
        center.delegate = foregroundPresenter
    }

    func refreshAuthorizationStatus() async {
        authorizationStatus = await center.notificationSettings().authorizationStatus
    }

    /// 사용자가 카테고리 알림을 처음 켤 때 부른다. 이미 결정된 상태면 시스템
    /// 대화상자는 안 뜨고 현재 상태만 돌려준다.
    @discardableResult
    func requestAuthorization() async -> Bool {
        let granted = (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        await refreshAuthorizationStatus()
        // 거부율이 높으면 권한을 묻는 시점 자체를 다시 봐야 한다.
        Analytics.log(.notificationPermission(granted: granted))
        return granted
    }

    /// 할 일/카테고리가 바뀔 때마다 부른다. 권한이 없으면 예약된 걸 지우기만 한다.
    func reschedule(todos: [TodoItem]) async {
        center.removeAllPendingNotificationRequests()

        guard isEnabled else {
            logger.info("알림이 전체 꺼짐 — 예약 없음")
            return
        }

        await refreshAuthorizationStatus()
        guard authorizationStatus == .authorized || authorizationStatus == .provisional else {
            logger.warning("예약 중단: 알림 권한 없음 (status=\(self.authorizationStatus.rawValue))")
            return
        }

        let requests = pendingRequests(for: todos)
        for request in requests {
            do {
                try await center.add(request)
            } catch {
                logger.error("알림 예약 실패 \(request.identifier): \(error.localizedDescription)")
            }
        }
        // 알림이 안 온다는 신고가 들어왔을 때 가장 먼저 볼 값 — 0이면 예약 자체가
        // 안 된 것이고, 그때는 시작 시간이 있는 할 일인지/카테고리 알림이 켜졌는지부터 본다.
        logger.info("알림 \(requests.count)개 예약 완료")
    }

    /// 지금 이후로 가까운 순서대로, 제한 개수만큼의 알림 요청을 만든다.
    private func pendingRequests(for todos: [TodoItem]) -> [UNNotificationRequest] {
        let now = Date()
        guard let horizon = calendar.date(byAdding: .day, value: Self.horizonDays, to: now) else { return [] }

        var fireTimes: [(date: Date, todo: TodoItem, occurrence: Date)] = []
        for todo in todos {
            guard let category = todo.category, category.notifiesBeforeStart else { continue }
            guard todo.startTime != nil else { continue }

            for occurrence in occurrences(of: todo, from: now, to: horizon) {
                guard let fireDate = fireDate(for: todo, occurrence: occurrence, leadMinutes: category.notificationLeadMinutes),
                      fireDate > now
                else { continue }
                // 이미 끝낸 인스턴스는 알릴 이유가 없다.
                guard !todo.isCompleted(on: occurrence) else { continue }
                fireTimes.append((fireDate, todo, occurrence))
            }
        }

        return fireTimes
            .sorted { $0.date < $1.date }
            .prefix(Self.pendingLimit)
            .map { entry in
                let content = UNMutableNotificationContent()
                content.title = entry.todo.title
                content.body = bodyText(for: entry.todo, category: entry.todo.category)
                content.sound = .default

                let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: entry.date)
                return UNNotificationRequest(
                    // 같은 할 일의 다른 날 인스턴스가 서로 덮어쓰지 않도록 날짜까지 넣는다.
                    identifier: "\(entry.todo.id.uuidString)-\(entry.occurrence.dayKey)",
                    content: content,
                    trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
                )
            }
    }

    private func bodyText(for todo: TodoItem, category: TodoCategory?) -> String {
        let minutes = category?.notificationLeadMinutes ?? 0
        guard let startTime = todo.startTime else { return "곧 시작해요" }
        return "\(minutes)분 뒤 \(startTime.koreanTime)에 시작해요"
    }

    /// 알림이 울릴 시각 = 그 인스턴스의 시작 날짜 + 시작 시각 - 리드타임.
    /// startTime은 시:분만 의미가 있어서(TodoItem 주석 참고) 날짜와 합쳐 써야 한다.
    private func fireDate(for todo: TodoItem, occurrence: Date, leadMinutes: Int) -> Date? {
        guard let startTime = todo.startTime else { return nil }
        let time = calendar.dateComponents([.hour, .minute], from: startTime)
        guard let start = calendar.date(
            bySettingHour: time.hour ?? 0,
            minute: time.minute ?? 0,
            second: 0,
            of: occurrence
        ) else { return nil }
        return calendar.date(byAdding: .minute, value: -leadMinutes, to: start)
    }

    /// 앱이 떠 있을 때도 알림을 배너로 띄운다. iOS 기본값은 "포그라운드면 안 띄움"이라,
    /// 앱을 보고 있는 동안 시작 시간이 되면 아무 일도 안 일어난 것처럼 보였다.
    ///
    /// 알림 **탭**도 여기서 받는다. 예전엔 `willPresent`만 구현돼 있어서, 알림이
    /// 실제로 사람을 앱으로 데려오는지 알 방법이 없었다 — 예약만 하고 효과를
    /// 모르면 알림 설계를 고칠 근거가 없다.
    private final class ForegroundNotificationPresenter: NSObject, UNUserNotificationCenterDelegate {
        func userNotificationCenter(
            _ center: UNUserNotificationCenter,
            willPresent notification: UNNotification
        ) async -> UNNotificationPresentationOptions {
            [.banner, .sound, .list]
        }

        func userNotificationCenter(
            _ center: UNUserNotificationCenter,
            didReceive response: UNNotificationResponse
        ) async {
            // 알림을 밀어서 지운 건(dismissAction) 연 게 아니다.
            guard response.actionIdentifier == UNNotificationDefaultActionIdentifier else { return }
            await MainActor.run { Analytics.log(.notificationOpened) }
        }
    }

    /// 원본 + 반복 인스턴스의 시작일들을 기간 안에서 펼친다.
    private func occurrences(of todo: TodoItem, from start: Date, to end: Date) -> [Date] {
        guard let baseDate = todo.date else { return [] }
        let baseStart = calendar.startOfDay(for: baseDate)

        guard todo.repeatRule != .none else {
            return baseStart <= calendar.startOfDay(for: end) ? [baseStart] : []
        }

        var result: [Date] = []
        if baseStart >= calendar.startOfDay(for: start) { result.append(baseStart) }

        var cursor = max(calendar.startOfDay(for: start), baseStart)
        let last = calendar.startOfDay(for: end)
        while cursor <= last {
            if todo.isRepeatStart(cursor) { result.append(cursor) }
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }
        return result
    }
}
