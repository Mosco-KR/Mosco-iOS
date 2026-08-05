import Foundation
import OSLog

/// 이 앱이 남기는 이벤트 목록. **여기 없는 이벤트는 안 보낸다** — 어떤 데이터를
/// 모으는지가 코드 한곳에 다 적혀 있어야 나중에 개인정보 처리방침과 대조할 수 있다.
///
/// 이름은 `snake_case`로 고정한다. 대부분의 분석 도구(Firebase·Amplitude 등)가
/// 그 규칙을 쓰고, 도구를 바꿔도 과거 데이터와 이어 붙일 수 있어야 한다.
///
/// **개인 식별 정보는 담지 않는다.** 할 일 제목·메모·카테고리 이름은 절대 보내지
/// 않고, 대신 "제목 길이", "시간이 있는지" 같은 모양만 보낸다. 무엇을 적었는지는
/// 분석에 필요 없고, 한번 보내면 되돌릴 수 없다.
enum AnalyticsEvent {
    // MARK: 사용 흐름

    /// 앱이 전면으로 올라옴. 세션 수·리텐션의 기준.
    case appOpened(isColdStart: Bool)
    /// 탭 이동 — 세 탭 중 실제로 쓰는 게 무엇인지.
    case tabViewed(tab: String)

    // MARK: 핵심 행동

    /// 할 일 생성. 어디서 만들었는지가 제일 중요하다(빠른 추가 vs 상세 시트).
    case todoCreated(source: String, hasTime: Bool, hasRepeat: Bool, isMultiDay: Bool, titleLength: Int)
    /// 완료/해제. `source`로 앱과 위젯을 가른다.
    case todoCompletionToggled(source: String, completed: Bool, isRepeating: Bool)
    case todoDeleted(source: String)
    case todoEdited(field: String)

    // MARK: 기능 채택

    /// 위젯이 실제로 그려짐 — 어떤 위젯·크기가 정말 쓰이는지 알 수 있는 유일한 신호다.
    /// 위젯은 홈 화면에 올려둔 걸 앱이 알 방법이 없어서, 그리는 순간을 세는 수밖에 없다.
    case widgetRendered(kind: String, family: String)
    case categoryCreated(count: Int)
    case calendarCreated(count: Int)
    case dDaySet
    /// 알림 권한 요청 결과 — 거부율이 높으면 요청 시점을 다시 봐야 한다.
    case notificationPermission(granted: Bool)

    // MARK: 온보딩

    case tutorialStepShown(step: String)
    case tutorialFinished(completed: Bool)

    var name: String {
        switch self {
        case .appOpened: "app_opened"
        case .tabViewed: "tab_viewed"
        case .todoCreated: "todo_created"
        case .todoCompletionToggled: "todo_completion_toggled"
        case .todoDeleted: "todo_deleted"
        case .todoEdited: "todo_edited"
        case .widgetRendered: "widget_rendered"
        case .categoryCreated: "category_created"
        case .calendarCreated: "calendar_created"
        case .dDaySet: "dday_set"
        case .notificationPermission: "notification_permission"
        case .tutorialStepShown: "tutorial_step_shown"
        case .tutorialFinished: "tutorial_finished"
        }
    }

    var parameters: [String: String] {
        switch self {
        case let .appOpened(isColdStart):
            ["is_cold_start": String(isColdStart)]
        case let .tabViewed(tab):
            ["tab": tab]
        case let .todoCreated(source, hasTime, hasRepeat, isMultiDay, titleLength):
            [
                "source": source,
                "has_time": String(hasTime),
                "has_repeat": String(hasRepeat),
                "is_multi_day": String(isMultiDay),
                // 길이만. 제목 자체는 개인 정보라 보내지 않는다.
                "title_length_bucket": Self.bucket(titleLength)
            ]
        case let .todoCompletionToggled(source, completed, isRepeating):
            ["source": source, "completed": String(completed), "is_repeating": String(isRepeating)]
        case let .todoDeleted(source):
            ["source": source]
        case let .todoEdited(field):
            ["field": field]
        case let .widgetRendered(kind, family):
            ["kind": kind, "family": family]
        case let .categoryCreated(count):
            ["total_count": String(count)]
        case let .calendarCreated(count):
            ["total_count": String(count)]
        case .dDaySet:
            [:]
        case let .notificationPermission(granted):
            ["granted": String(granted)]
        case let .tutorialStepShown(step):
            ["step": step]
        case let .tutorialFinished(completed):
            ["completed": String(completed)]
        }
    }

    /// 자유 입력 길이는 그대로 보내면 그 자체가 지문이 될 수 있다 — 구간으로 뭉갠다.
    private static func bucket(_ length: Int) -> String {
        switch length {
        case ..<5: "0-4"
        case ..<10: "5-9"
        case ..<20: "10-19"
        default: "20+"
        }
    }
}

/// 이벤트를 실제로 보내는 쪽. 앱은 이 프로토콜만 알고, 어떤 분석 도구를 쓰는지는
/// 모른다 — 도구를 붙이거나 바꿀 때 호출부를 하나도 안 건드리려는 것이다.
protocol AnalyticsSink: Sendable {
    func send(name: String, parameters: [String: String])
}

/// 개발 중 확인용. 콘솔에만 남기고 아무 데도 보내지 않는다.
struct ConsoleAnalyticsSink: AnalyticsSink {
    private let logger = Logger(subsystem: "com.Mosco.App", category: "analytics")

    func send(name: String, parameters: [String: String]) {
        logger.debug("\(name, privacy: .public) \(parameters.description, privacy: .public)")
    }
}

/// 이벤트 창구.
///
/// **아직 실제 분석 도구는 붙어 있지 않다.** SDK를 정하면 그 SDK를 감싼
/// `AnalyticsSink`를 하나 만들어 `Analytics.register(_:)`로 꽂으면 되고,
/// 이 파일 밖은 손댈 게 없다.
///
/// 수집 동의를 받기 전이라면 `isEnabled`를 false로 두면 전부 조용히 버려진다 —
/// 호출부에 조건문을 흩어놓지 않으려는 것이다.
@MainActor
enum Analytics {
    /// 동의를 받기 전/거부한 사용자는 여기서 막는다.
    static var isEnabled = true

    private static var sinks: [any AnalyticsSink] = [ConsoleAnalyticsSink()]

    static func register(_ sink: any AnalyticsSink) {
        sinks.append(sink)
    }

    static func log(_ event: AnalyticsEvent) {
        guard isEnabled else { return }
        for sink in sinks {
            sink.send(name: event.name, parameters: event.parameters)
        }
    }

    /// 위젯이 App Group에 쌓아둔 이벤트를 비워서 함께 보낸다.
    /// 앱이 전면으로 올라올 때 부른다(`RootTabView`).
    static func flushPendingFromExtensions() {
        guard isEnabled else {
            AnalyticsBuffer.drain()
            return
        }
        for pending in AnalyticsBuffer.drain() {
            for sink in sinks {
                sink.send(name: pending.name, parameters: pending.parameters)
            }
        }
    }
}

/// 위젯 익스텐션에서 남긴 이벤트를 앱이 대신 보내주기 위한 임시 보관소.
///
/// 익스텐션은 몇백 밀리초 살고 죽어서 네트워크 전송을 끝까지 책임질 수 없다.
/// 그래서 위젯은 App Group `UserDefaults`에 적어만 두고, 앱이 다음에 열릴 때
/// 한꺼번에 보낸다. 그래서 위젯 이벤트는 **실시간이 아니다** — 지표를 볼 때
/// 이 지연을 감안해야 한다.
enum AnalyticsBuffer {
    struct Pending: Codable {
        let name: String
        let parameters: [String: String]
        let timestamp: Date
    }

    private static let key = "pendingAnalyticsEvents"
    /// 앱을 오래 안 열어도 무한히 쌓이지 않게 자른다.
    private static let limit = 200

    private static var defaults: UserDefaults? {
        UserDefaults(suiteName: SharedModelContainer.appGroupID)
    }

    static func record(_ event: AnalyticsEvent) {
        guard let defaults else { return }
        var stored = load(from: defaults)
        stored.append(Pending(name: event.name, parameters: event.parameters, timestamp: .now))
        if stored.count > limit { stored.removeFirst(stored.count - limit) }
        guard let data = try? JSONEncoder().encode(stored) else { return }
        defaults.set(data, forKey: key)
    }

    static func drain() -> [Pending] {
        guard let defaults else { return [] }
        let stored = load(from: defaults)
        defaults.removeObject(forKey: key)
        return stored
    }

    private static func load(from defaults: UserDefaults) -> [Pending] {
        guard let data = defaults.data(forKey: key),
              let decoded = try? JSONDecoder().decode([Pending].self, from: data)
        else { return [] }
        return decoded
    }
}
