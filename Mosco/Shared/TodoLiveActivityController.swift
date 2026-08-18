import ActivityKit
import Foundation
import Observation
import OSLog
import SwiftData

private let logger = Logger(subsystem: "com.Mosco.App", category: "live-activity")

/// 사용자가 고른 할 일 하나의 **남은 시간**을 잠금화면과 다이나믹 아일랜드에 띄운다.
///
/// **앱이 알아서 띄우지 않는다.** 목록에서 할 일을 꾹 눌러 직접 고를 때만 올라간다.
/// 예전엔 오늘 일정을 훑어 시작 30분 전인 것을 자동으로 띄웠는데, 그 방식에는
/// 고칠 수 없는 구멍이 있었다 — **앱은 자기 자신을 깨울 수 없다.** 로컬 알림으로도,
/// 백그라운드 작업으로도 라이브 액티비티를 시작시킬 수 없고, "2시 46분 일정이니
/// 2시 16분에 알아서"는 `pushToStartToken`을 받아 APNs로 쏘는 **서버**가 있어야
/// 가능하다. 서버가 없으니 자동 시작은 사실상 "앱을 열어야 뜬다"였고, 그럴 바에는
/// 사용자가 고르는 편이 정직하다 — 고르는 순간 앱은 반드시 앞에 나와 있다.
///
/// 대신 **한 번 올라간 뒤로는 앱 없이도 산다.** 남은 시간은 뷰의 `Text(timerInterval:)`이
/// 시스템에서 직접 세고, 시작 시각이 되면 `staleDate`로 표기가 걷힌다.
/// 활동을 실제로 내리는 것만 앱이 다음에 돌 때 한다(`sync`).
///
/// **`Shared/`에 있는 이유가 있다.** 잠금화면에서 완료를 누르면 `LiveActivityIntent`가
/// 앱 프로세스에서 돌면서 이 타입을 불러야 하는데, 그 인텐트는 위젯 타깃에도 함께
/// 컴파일된다 — 앱 전용 폴더에 두면 위젯 빌드가 깨진다.
@MainActor
@Observable
final class TodoLiveActivityController {
    /// 인텐트도 이 하나를 부른다. 인스턴스가 둘이면 각자 다른 활동을 들고 있게 되고,
    /// 그러면 잠금화면에 같은 것이 두 개 뜬다.
    static let shared = TodoLiveActivityController()

    /// 이보다 멀리 있는 일정은 띄우지 못한다.
    ///
    /// **시스템이 활동을 8시간까지만 살려둔다.** 띄우는 순간부터 세기 시작해서,
    /// 8시간이 지나면 시스템이 강제로 끝낸다 — 12시간 뒤 일정을 지금 띄우면
    /// 정작 그 일정이 다가올 즈음엔 이미 사라지고 없다. 띄우지 못하게 막는 편이
    /// 떠 있다가 조용히 없어지는 것보다 낫다.
    static let maxLeadTime: TimeInterval = 8 * 60 * 60

    /// 띄우기를 시도한 결과. 실패한 이유마다 사용자에게 할 말이 달라서
    /// 성공/실패가 아니라 경우를 그대로 돌려준다.
    enum StartResult {
        case started
        /// 시작까지 8시간 넘게 남았다.
        case tooFar
        /// 시작 시각이 이미 지났거나, 시각 자체를 안 적어둔 할 일이다.
        case notUpcoming
        /// 앱 설정 또는 시스템 설정에서 라이브 액티비티가 꺼져 있다.
        case unavailable
    }

    /// 사용자 스위치. 시스템 설정에도 라이브 액티비티 항목이 있지만 그건 앱 전체를
    /// 끄는 것이고, 여기서는 **이 앱의 이 기능만** 끈다 — 알림은 받고 싶은데
    /// 잠금화면이 붐비는 건 싫은 경우가 실제로 있다.
    var isEnabled: Bool {
        didSet { UserDefaults.standard.set(isEnabled, forKey: Self.enabledKey) }
    }

    private static let enabledKey = "liveActivityEnabled"

    /// 지금 잠금화면에 떠 있는 할 일. 없으면 nil.
    ///
    /// **관찰되는 값이다**(`@ObservationIgnored`를 붙이지 않았다). 목록의 컨텍스트
    /// 메뉴는 셀 body와 함께 만들어져서, 관찰되지 않는 값을 읽으면 띄운 뒤에도
    /// 문구가 "표시"인 채로 남는다 — 메뉴가 꾹 누를 때마다 새로 그려지지 않는다.
    private(set) var showingTodoID: String?

    @ObservationIgnored private let calendar = Calendar.current
    /// 지금 띄워둔 활동. 앱을 껐다 켜면 시스템이 들고 있던 것을 되찾는다.
    @ObservationIgnored private var activity: Activity<TodoActivityAttributes>?

    private init() {
        // 키가 없으면(첫 실행) 켜진 상태로 시작한다 — 알림 스위치와 같은 규칙.
        isEnabled = UserDefaults.standard.object(forKey: Self.enabledKey) as? Bool ?? true
    }

    /// 시스템의 라이브 액티비티 허용 여부. 여기엔 "아직 안 물어봄"이 없다 —
    /// 사용자가 설정에서 켜고 끄는 것이라 앱이 물어볼 수 있는 창 자체가 없다.
    var permission: PermissionState {
        ActivityAuthorizationInfo().areActivitiesEnabled ? .granted : .denied
    }

    /// 스위치에 표시할 값 — 켜뒀어도 시스템에서 꺼져 있으면 꺼진 것으로 보인다.
    var isEffectivelyOn: Bool {
        PermissionGate.isOn(userPreference: isEnabled, permission: permission)
    }

    // MARK: - 띄우기

    /// 이 할 일의 남은 시간을 띄운다. 목록에서 꾹 눌러 고를 때 부른다.
    ///
    /// 이미 다른 할 일이 떠 있으면 그것을 내리고 새로 띄운다 — 한 번에 하나다.
    /// 여러 개를 띄우면 아일랜드는 어차피 하나만 크게 보여주고 나머지는 점으로
    /// 밀어내는데, 그 상태에서는 "무엇을 기다리는 중인지"를 알 수 없다.
    @discardableResult
    func start(todo: TodoItem, on day: Date, now: Date = .now) async -> StartResult {
        guard isEnabled, ActivityAuthorizationInfo().areActivitiesEnabled else {
            logger.info("라이브 액티비티가 꺼져 있어 띄우지 못함")
            return .unavailable
        }

        guard let start = startDate(of: todo, on: day), start > now else { return .notUpcoming }
        guard start.timeIntervalSince(now) <= Self.maxLeadTime else { return .tooFar }

        await end()

        let attributes = TodoActivityAttributes(dayKey: day.dayKey, todoID: todo.id.uuidString)
        do {
            activity = try Activity.request(
                attributes: attributes,
                content: content(for: todo, on: day, start: start),
                // 푸시 서버가 없으므로 갱신은 전부 앱이 직접 한다.
                pushType: nil
            )
            showingTodoID = attributes.todoID
            logger.info("라이브 액티비티 시작")
            // 이벤트는 부른 쪽(TodoRow)이 결과와 함께 한 번만 남긴다 —
            // 여기서도 남기면 성공만 두 번 세어져 성공률이 부풀어 오른다.
            return .started
        } catch {
            // 권한이 꺼졌거나 시스템 한도에 걸린 경우. 앱이 죽을 이유는 아니다.
            logger.error("라이브 액티비티 시작 실패: \(error.localizedDescription)")
            return .unavailable
        }
    }

    /// 사용자가 직접 내린다. 목록의 같은 메뉴에서 부른다.
    func stop() async {
        await end()
    }

    // MARK: - 유지·정리

    /// 떠 있는 활동을 지금 상태에 맞춘다. 할 일이 바뀌거나, 앱이 앞으로 나오거나,
    /// 잠금화면에서 완료를 눌렀을 때 부른다.
    ///
    /// **여기서 새로 띄우는 일은 없다.** 띄우는 건 사용자가 고를 때뿐이고, 이 함수는
    /// 이미 떠 있는 것을 고치거나 내리기만 한다.
    ///
    /// 인자를 받지 않고 **저장소에서 직접 읽는다.** 잠금화면의 인텐트에는 넘겨줄
    /// `@Query` 배열이 없고, 그렇다고 경로를 둘로 나누면 "앱에서 볼 때와 잠금화면에서
    /// 볼 때가 다르다"는 종류의 버그가 생길 자리가 된다.
    func sync(now: Date = .now) async {
        adoptRunningActivity()
        guard let activity else { return }

        guard isEnabled, ActivityAuthorizationInfo().areActivitiesEnabled else {
            logger.info("라이브 액티비티가 꺼짐 — 떠 있던 것을 걷는다")
            await end()
            return
        }

        let attributes = activity.attributes
        guard let day = Self.day(fromKey: attributes.dayKey),
              let todo = todo(withID: attributes.todoID),
              !todo.isCompleted(on: day),
              let start = startDate(of: todo, on: day)
        else {
            // 지웠거나, 끝냈거나, 시각을 지운 할 일. 더 셀 것이 없다.
            logger.info("대상 할 일이 사라져 활동을 걷는다")
            await end()
            return
        }

        // **시작 시각이 지나면 내린다.** '진행중'으로 바꿔 붙들지 않는다 — 이 기능은
        // "언제 시작하나"에 답하는 것이고, 시작한 뒤에는 답할 것이 남아 있지 않다.
        // 앱이 자는 동안에는 못 내리므로 그 사이에는 `staleDate`가 표기를 걷는다.
        guard start > now else {
            logger.info("시작 시각이 지나 활동을 걷는다")
            await end()
            return
        }

        await activity.update(content(for: todo, on: day, start: start))
    }

    /// 앱이 꺼져 있는 동안에도 활동은 살아 있다. 다시 켰을 때 그걸 못 찾으면
    /// 새로 하나 더 띄워서 같은 것이 두 개 뜬다.
    ///
    /// **뷰를 그리는 도중에는 부르지 않는다** — 관찰되는 `showingTodoID`를 건드리므로,
    /// body 안에서 부르면 그리는 중에 상태를 바꾸는 꼴이 된다. `sync()`가 앱이
    /// 앞으로 나올 때와 할 일이 바뀔 때마다 부르므로 그것으로 충분하다.
    private func adoptRunningActivity() {
        guard activity == nil else { return }
        activity = Activity<TodoActivityAttributes>.activities.first
        showingTodoID = activity?.attributes.todoID
    }

    private func end() async {
        showingTodoID = nil
        guard let activity else { return }
        await activity.end(nil, dismissalPolicy: .immediate)
        self.activity = nil
    }

    // MARK: - 내용

    private func content(
        for todo: TodoItem,
        on day: Date,
        start: Date
    ) -> ActivityContent<TodoActivityAttributes.ContentState> {
        let event = TodoActivityAttributes.Event(
            title: todo.title,
            categoryName: todo.category?.name,
            colorHex: todo.category?.colorHex,
            calendarName: todo.calendar?.name,
            isRepeating: todo.repeatRule != .none,
            isDDay: todo.isDDay,
            startDate: start,
            startLabel: start.koreanTime,
            endLabel: endDate(of: todo, on: day, start: start)?.koreanTime,
            memo: todo.memo
        )

        // 시작 시각이 지나면 셀 것이 없다. 앱이 자고 있어 못 내리더라도 시스템이
        // 그때 활동을 stale로 바꿔주고, 뷰는 그걸 보고 남은 시간 표기를 걷는다.
        return ActivityContent(
            state: TodoActivityAttributes.ContentState(event: event),
            staleDate: start
        )
    }

    // MARK: - 저장소

    private func todo(withID id: String) -> TodoItem? {
        guard let container = SharedModelContainer.sharedIfAvailable,
              let all = try? container.mainContext.fetch(FetchDescriptor<TodoItem>())
        else { return nil }
        return all.first { $0.id.uuidString == id }
    }

    private static func day(fromKey key: String) -> Date? {
        guard let seconds = TimeInterval(key) else { return nil }
        return Date(timeIntervalSince1970: seconds)
    }

    /// `startTime`/`endTime`은 시·분만 의미가 있어서(`TodoItem` 참고) 날짜와 합쳐야
    /// 실제 시각이 된다.
    private func startDate(of todo: TodoItem, on day: Date) -> Date? {
        guard let startTime = todo.startTime else { return nil }
        return combine(day: day, time: startTime)
    }

    /// 종료 시각. 안 적었거나 시작보다 앞서면(잘못 들어간 값) nil이다 —
    /// **임의의 길이를 지어내지 않는다.**
    private func endDate(of todo: TodoItem, on day: Date, start: Date) -> Date? {
        guard let endTime = todo.endTime,
              let end = combine(day: day, time: endTime),
              end > start
        else { return nil }
        return end
    }

    private func combine(day: Date, time: Date) -> Date? {
        let components = calendar.dateComponents([.hour, .minute], from: time)
        return calendar.date(
            bySettingHour: components.hour ?? 0,
            minute: components.minute ?? 0,
            second: 0,
            of: day
        )
    }
}
