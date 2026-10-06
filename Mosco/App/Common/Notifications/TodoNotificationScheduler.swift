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
/// 예약할 것을 정하는 계산은 `ReminderPlan`(Shared)에 있다. 여기 남은 일은
/// 시스템 알림 센터와 이야기하는 것과 문구를 만드는 것뿐이다 — 그 둘은 테스트로
/// 덮을 수 없고, 덮을 수 있는 것은 전부 저쪽으로 옮겼다.
///
/// **"전부 지우고 다시 깔기"는 그만뒀다.** 데이터가 바뀌면 통째로 다시 계산하는
/// 것은 그대로지만, 먼저 다 지우면 지운 직후부터 다시 깔기까지 알림이 **하나도
/// 없는 창**이 생긴다. 그 사이에 작업이 취소되면(`.task(id:)`는 키가 바뀌는 즉시
/// 취소된다 — 할 일을 연달아 고치면 실제로 그렇게 된다) 알림이 걷힌 채로 남는다.
/// 그래서 지금은 **필요 없어진 것만 걷어내고 필요한 것은 그대로 다시 깐다.**
/// 같은 식별자로 `add`하면 교체되므로, 시각이 바뀐 알림도 이 길로 갱신된다.
/// 중간에 끊겨도 남아 있는 쪽은 멀쩡하고, 두 번 겹쳐 돌아도 결과가 같다.
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

    /// 시스템 권한을 화면이 쓰는 형태로. `provisional`(조용한 알림)과 `ephemeral`은
    /// 알림이 실제로 도착하므로 허용으로 친다.
    var permission: PermissionState {
        switch authorizationStatus {
        case .authorized, .provisional, .ephemeral: .granted
        case .denied: .denied
        case .notDetermined: .notDetermined
        @unknown default: .notDetermined
        }
    }

    /// 스위치에 표시할 값 — 켜뒀어도 권한이 없으면 꺼진 것으로 보인다.
    var isEffectivelyOn: Bool {
        PermissionGate.isOn(userPreference: isEnabled, permission: permission)
    }

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

    /// 앱을 켤 때마다 부른다. 아직 한 번도 안 물어봤을 때만 시스템 대화상자를 띄운다.
    ///
    /// **권한은 앱을 시작할 때 받는다.** 예전엔 설정 화면의 알림 토글을 켜야 비로소
    /// 물었는데, 설정까지 들어가는 사람은 많지 않아서 대부분은 권한이 없는 채로
    /// 남았다 — 카테고리마다 "몇 분 전에 알림"을 정해두고도 알림이 한 번도 오지
    /// 않았고, 그 이유가 화면 어디에도 없었다.
    ///
    /// 거부하면 앱 전체 스위치도 함께 내린다. 스위치는 켜져 있는데 알림은 안 오는
    /// 상태가 제일 헷갈린다(설정 화면이 같은 규칙으로 움직인다).
    func requestAuthorizationOnFirstLaunch() async {
        await refreshAuthorizationStatus()
        guard authorizationStatus == .notDetermined else { return }
        let granted = await requestAuthorization()
        if !granted { isEnabled = false }
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

    /// 할 일/카테고리가 바뀔 때마다 부른다. 권한이 없거나 전체 스위치가 꺼져 있으면
    /// 예약된 것을 걷어내기만 한다.
    ///
    /// **입력을 값으로 먼저 베낀다.** `TodoItem`은 `@Model`이라 자기 컨텍스트의
    /// 스레드 밖에서 만지면 안 되는데, 이 함수는 `await` 뒤로 그 스레드를 떠난다.
    func reschedule(todos: [TodoItem]) async {
        let sources = await MainActor.run { todos.compactMap { ReminderSource($0) } }

        guard isEnabled else {
            center.removeAllPendingNotificationRequests()
            logger.info("알림이 전체 꺼짐 — 예약 없음")
            return
        }

        await refreshAuthorizationStatus()
        guard authorizationStatus == .authorized || authorizationStatus == .provisional else {
            center.removeAllPendingNotificationRequests()
            logger.warning("예약 중단: 알림 권한 없음 (status=\(self.authorizationStatus.rawValue))")
            return
        }

        let planned = ReminderPlan.make(from: sources, now: Date(), calendar: calendar)
        await apply(planned)
    }

    /// 계획과 지금 걸려 있는 것을 맞춘다 — **없어진 것만 걷어내고, 필요한 것은
    /// 그대로 다시 깐다.** 먼저 전부 지우지 않는 이유는 머리 주석에 있다.
    private func apply(_ planned: [PlannedReminder]) async {
        let wanted = Set(planned.map(\.id))
        let pending = await center.pendingNotificationRequests().map(\.identifier)
        let stale = pending.filter { !wanted.contains($0) }
        if !stale.isEmpty {
            center.removePendingNotificationRequests(withIdentifiers: stale)
        }

        var added = 0
        for reminder in planned {
            do {
                // 같은 식별자면 교체된다 — 시각이나 제목이 바뀐 알림이 이 길로 갱신된다.
                try await center.add(request(for: reminder))
                added += 1
            } catch {
                logger.error("알림 예약 실패 \(reminder.id): \(error.localizedDescription)")
            }
        }
        // 알림이 안 온다는 신고가 들어왔을 때 가장 먼저 볼 값 — 0이면 예약 자체가
        // 안 된 것이고, 그때는 시작 시간이 있는 할 일인지/카테고리 알림이 켜졌는지부터 본다.
        logger.info("알림 \(added)개 예약, \(stale.count)개 걷어냄")
    }

    private func request(for reminder: PlannedReminder) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.title = reminder.title
        content.body = bodyText(for: reminder)
        content.sound = .default

        let components = calendar.dateComponents(
            [.year, .month, .day, .hour, .minute], from: reminder.fireDate
        )
        return UNNotificationRequest(
            identifier: reminder.id,
            content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        )
    }

    /// 리드타임이 0분이면 "0분 뒤"가 아니라 지금 시작하는 것이다 — 그대로 끼워
    /// 넣으면 "0분 뒤 오후 7시에 시작해요"라는 말이 된다.
    private func bodyText(for reminder: PlannedReminder) -> String {
        guard reminder.leadMinutes > 0 else {
            return String(localized: "\(reminder.startDate.localizedTime)에 시작해요")
        }
        return String(localized: "\(reminder.leadMinutes)분 뒤 \(reminder.startDate.localizedTime)에 시작해요")
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
}
