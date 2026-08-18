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

    // MARK: - 핵심 루프

    /// 할 일이 만들어졌다.
    ///
    /// **예전엔 이게 `create_schedule`과 `create_task` 둘이었다.** 날짜가 있으면
    /// 달력에 자리를 갖는 "일정", 없으면 목록에만 있는 "할 일"이라 다른 것으로
    /// 다뤘는데, 그러면 "얼마나 만드는가"를 볼 때마다 두 지표를 더해야 했고
    /// 비율을 보려면 또 나눠야 했다. `has_date` 하나로 같은 답이 나온다.
    ///
    /// 제목 길이는 뺐다. 구간으로 뭉개서 보내고 있었지만, 그 값이 어느 쪽으로
    /// 나오든 다음에 만들 것이 달라지지 않았다.
    case todoCreated(source: String, hasDate: Bool, hasTime: Bool, repeatRule: String, isMultiDay: Bool)

    /// 완료/해제. `source`로 앱·위젯·잠금화면을 가른다 — 위젯을 계속 만들지
    /// 정하는 근거가 이 값이다.
    ///
    /// 해제(`completed=false`)도 함께 센다. 이 앱은 **셀 몸통을 누르면 완료**라
    /// 잘못 눌리기 쉬운 구조인데, 해제 비율이 그 위험을 재는 유일한 눈금이다.
    ///
    /// 이름이 `complete_task`가 아닌 건 **과거 데이터를 끊어내기 위해서다.**
    /// 앱 경로에서 `completed`가 뒤집혀 기록되던 버그가 오래 있었고(`TodoRow`
    /// 참고), 위젯 경로는 정상이었다 — 한 지표 안에 반대 뜻의 값이 섞여 있어
    /// 되살릴 수 없다. 이름을 갈아야 "언제부터 믿을 수 있는지"를 사람이
    /// 기억하지 않아도 된다.
    case todoCompleted(source: String, completed: Bool, isRepeating: Bool)

    // MARK: - 값이 있는지 확인해야 하는 기능들
    //
    // 여기 있는 것들은 전부 "코드가 비싼데 정말 쓰이는가"에 답하려고 남긴다.
    // 안 쓰이면 걷어낼 후보라는 뜻이다.

    /// 제목을 보고 카테고리를 자동으로 골라줬고, 결과가 있었는지.
    /// 임베딩 분류기가 실제로 맞히는지를 재는 값이 이것뿐이다(docs/CATEGORIZATION.md).
    case categorySuggested(matched: Bool)
    /// 자동으로 고른 카테고리를 사람이 바꿨다. 위 이벤트와 **짝이어야** 의미가
    /// 있다 — 이 비율이 높으면 분류기가 돕는 게 아니라 방해하고 있다는 뜻이다.
    case categoryOverridden
    /// 제목에서 찾아낸 시간을 실제로 적용했다("7시 러닝" → 오후 7시).
    case timeSuggestionApplied
    /// 복사해둔 할 일을 다른 날에 붙여넣었다. 클립보드 층(붙여넣기 줄·칩)을
    /// 계속 들고 갈지 정하는 근거다.
    case todoDuplicated
    /// 디데이로 표시했다.
    case dDaySet
    /// 캘린더를 껐다 켰다. 여러 캘린더를 정말 나눠 쓰는지 — 안 쓰면 이 층 자체가
    /// 사람들에게 없는 개념이라는 뜻이다.
    case calendarFilterChanged(visibleCount: Int, totalCount: Int)
    /// 잠금화면 표시 시도의 결과. **막힌 이유까지 한 이벤트에 담는다** —
    /// 성공만 세면 채택률이 낮을 때 "안 쓰는 것"인지 "8시간 조건에 걸리는 것"인지
    /// 구분할 수 없고, 그 둘은 할 일이 완전히 다르다.
    case liveActivity(result: String)

    // MARK: - 밖에서 앱으로 들어오는 문

    /// 위젯이 홈 화면에 올라가 있다. **하루에 종류당 한 번만** 보낸다 —
    /// 타임라인이 다시 그려질 때마다 보내면 App Group 버퍼(200개)가 이것으로
    /// 가득 차서 정작 중요한 이벤트가 밀려난다.
    case widgetRendered(kind: String, family: String)
    /// 위젯을 눌러 앱이 열렸다. 위젯이 보기용인지 진입로인지를 가른다.
    case widgetTapped(kind: String)
    /// 알림을 눌러 앱이 열렸다.
    ///
    /// 이름 뒤에 `ed`가 붙은 건 취향이 아니다. `notification_open`은 Firebase의
    /// **예약어**(FCM 자동 이벤트)라 그 이름으로 보내면 조용히 버려진다.
    case notificationOpened
    /// 알림 권한 요청 결과. 거부율이 높으면 묻는 시점을 다시 봐야 한다.
    case notificationPermission(granted: Bool)

    // MARK: - 첫 경험

    /// 튜토리얼 시작. `source`로 첫 실행과 설정에서 다시 부른 것을 가른다.
    case tutorialStarted(source: String)
    /// 한 단계의 결과. `outcome`은 직접 해낸 것(`completed`)과 "대신 해주세요"를
    /// 누른 것(`assisted`)을 가른다 — **어느 단계가 어려운지는 후자가 말해준다.**
    case tutorialStep(step: String, outcome: String)
    /// 튜토리얼이 끝난 자리와 방식(`finished` / `skipped`).
    /// 어디서 빠져나가는지가 이 안내를 고칠 유일한 근거다.
    /// reason은 `TutorialOutcome` — finished / skipped / **abandoned**.
    /// 건너뛰기("필요 없다")와 이탈("막혔다")은 다른 신호라 따로 센다.
    case tutorialEnded(step: String, reason: String)

    // MARK: - 건강 상태

    /// 앱을 열 때 한 번. 사람들이 실제로 몇 건을 들고 쓰는지 모르면 성능 작업의
    /// 목표를 정할 수 없다. 카테고리·캘린더 개수도 여기 함께 담는다 —
    /// 만들 때마다 따로 세던 이벤트를 걷어내고 이 스냅샷 하나로 합쳤다.
    case dataScale(todoCount: Int, categoryCount: Int, calendarCount: Int)
    /// iCloud 저장소를 못 열어 로컬 전용으로 물러났다. 드물지만 사용자가
    /// 데이터를 잃는 경로라, 조용히 넘어가면 안 된다.
    case storeLocalFallback
    /// 익명 식별자가 어디서 왔는가 — 새로 만들었는지, iCloud에서 되찾았는지.
    /// 재설치를 건너온 비율이 이 값으로 보인다.
    case analyticsIdentity(origin: String)
    /// 앱스토어 리뷰창을 띄워달라고 시스템에 요청했다. **실제로 떴는지는 알 수
    /// 없다** — 이건 "부탁할 조건이 얼마나 자주 차는가"를 재는 값이고, 조건을
    /// 다시 조일지 풀지 정하는 데 쓴다.
    case reviewPromptRequested

    var name: String {
        switch self {
        case .todoCreated: "todo_created"
        case .todoCompleted: "todo_completed"
        case .categorySuggested: "category_suggested"
        case .categoryOverridden: "category_overridden"
        case .timeSuggestionApplied: "time_suggestion_applied"
        case .todoDuplicated: "todo_duplicated"
        case .dDaySet: "dday_set"
        case .calendarFilterChanged: "calendar_filter_changed"
        case .liveActivity: "live_activity"
        case .widgetRendered: "widget_rendered"
        case .widgetTapped: "widget_tapped"
        case .notificationOpened: "notification_opened"
        case .notificationPermission: "notification_permission"
        case .tutorialStarted: "tutorial_started"
        case .tutorialStep: "tutorial_step"
        case .tutorialEnded: "tutorial_ended"
        case .dataScale: "data_scale"
        case .storeLocalFallback: "store_local_fallback"
        case .analyticsIdentity: "analytics_identity"
        case .reviewPromptRequested: "review_prompt_requested"
        }
    }

    var parameters: [String: String] {
        switch self {
        case let .todoCreated(source, hasDate, hasTime, repeatRule, isMultiDay):
            [
                "source": source,
                "has_date": String(hasDate),
                "has_time": String(hasTime),
                "repeat_rule": repeatRule,
                "is_multi_day": String(isMultiDay)
            ]
        case let .todoCompleted(source, completed, isRepeating):
            ["source": source, "completed": String(completed), "is_repeating": String(isRepeating)]
        case let .categorySuggested(matched):
            ["matched": String(matched)]
        case .categoryOverridden:
            [:]
        case .timeSuggestionApplied:
            [:]
        case .todoDuplicated:
            [:]
        case .dDaySet:
            [:]
        case let .calendarFilterChanged(visibleCount, totalCount):
            ["visible_count": String(visibleCount), "total_count": String(totalCount)]
        case let .liveActivity(result):
            ["result": result]
        case let .widgetRendered(kind, family):
            ["kind": kind, "family": family]
        case let .widgetTapped(kind):
            ["kind": kind]
        case .notificationOpened:
            [:]
        case let .notificationPermission(granted):
            ["granted": String(granted)]
        case let .tutorialStarted(source):
            ["source": source]
        case let .tutorialStep(step, outcome):
            ["step": step, "outcome": outcome]
        case let .tutorialEnded(step, reason):
            ["step": step, "reason": reason]
        case let .analyticsIdentity(origin):
            ["origin": origin]
        case let .dataScale(todoCount, categoryCount, calendarCount):
            [
                // 정확한 개수는 필요 없고 규모만 알면 된다.
                "todo_count_bucket": Self.countBucket(todoCount),
                "category_count": String(categoryCount),
                "calendar_count": String(calendarCount)
            ]
        case .storeLocalFallback:
            [:]
        case .reviewPromptRequested:
            [:]
        }
    }

    /// 보유 건수는 그대로 보내면 개인을 특정하는 데만 쓸모가 있다 — "몇 건대인지"만
    /// 알면 성능 목표를 정할 수 있다.
    private static func countBucket(_ count: Int) -> String {
        switch count {
        case 0: "0"
        case ..<10: "1-9"
        case ..<50: "10-49"
        case ..<200: "50-199"
        case ..<1000: "200-999"
        default: "1000+"
        }
    }
}

/// 이벤트를 실제로 보내는 쪽. 앱은 이 프로토콜만 알고, 어떤 분석 도구를 쓰는지는
/// 모른다 — 도구를 붙이거나 바꿀 때 호출부를 하나도 안 건드리려는 것이다.
protocol AnalyticsSink: Sendable {
    func send(name: String, parameters: [String: String])
    /// 같은 사람의 이벤트를 하나로 묶기 위한 익명 식별자.
    /// 기본 구현이 아무것도 안 하므로, 지원하지 않는 sink는 그냥 무시한다.
    func setUserID(_ id: String)
}

extension AnalyticsSink {
    func setUserID(_ id: String) {}
}

/// 개발 중 확인용. 콘솔에만 남기고 아무 데도 보내지 않는다.
struct ConsoleAnalyticsSink: AnalyticsSink {
    private let logger = Logger(subsystem: "com.Mosco.App", category: "analytics")

    func send(name: String, parameters: [String: String]) {
        logger.debug("\(name, privacy: .public) \(parameters.description, privacy: .public)")
    }
}

/// 이벤트 창구. 앱은 `log(_:)`만 알고, 어디로 보내는지는 sink가 정한다 —
/// 분석 도구를 바꿀 때 호출부를 하나도 안 건드리려는 것이다.
///
/// 수집 동의를 받기 전이라면 `isEnabled`를 false로 두면 전부 조용히 버려진다.
@MainActor
enum Analytics {
    /// 동의를 받기 전/거부한 사용자는 여기서 막는다.
    static var isEnabled = true

    /// 콘솔 sink는 개발 중에만. 릴리스에서는 Firebase만 남는다.
    #if DEBUG
    private static var sinks: [any AnalyticsSink] = [ConsoleAnalyticsSink()]
    #else
    private static var sinks: [any AnalyticsSink] = []
    #endif

    static func register(_ sink: any AnalyticsSink) {
        sinks.append(sink)
        // 늦게 붙은 sink(Firebase는 앱 시작 뒤에 붙는다)도 식별자를 알아야 한다.
        if let userID { sink.setUserID(userID) }
    }

    private static var userID: String?

    /// 앱 시작 때 한 번. 같은 사람을 같은 사람으로 세기 위한 익명 식별자를 정하고
    /// 모든 sink에 알린다 — 이게 없으면 앱을 지웠다 깔 때마다 새 사람이 된다.
    ///
    /// 값을 정하는 규칙은 `AnalyticsIdentity`에 있고 테스트로 덮여 있다.
    /// 여기서는 실제 저장소를 붙이는 일만 한다.
    static func identify() {
        let (id, origin) = AnalyticsIdentity.resolve(
            cloud: CloudIdentityStore(),
            local: UserDefaults.standard
        )
        userID = id
        for sink in sinks { sink.setUserID(id) }
        // 어디서 온 값인지 한 번 남긴다 — "재설치했는데 다른 사람으로 잡힌다"를
        // 나중에 추적하려면 이 분포가 필요하다.
        log(.analyticsIdentity(origin: String(describing: origin)))
    }

    static func log(_ event: AnalyticsEvent) {
        send(name: event.name, parameters: event.parameters)
    }

    /// 위젯이 App Group에 쌓아둔 이벤트를 비워서 함께 보낸다.
    /// 앱이 전면으로 올라올 때 부른다(`RootTabView`).
    ///
    /// 꺼져 있어도 비우기는 한다 — 안 그러면 동의하지 않은 사용자의 기기에
    /// 이벤트가 무한정 쌓인다.
    static func flushPendingFromExtensions() {
        for pending in AnalyticsBuffer.drain() {
            send(name: pending.name, parameters: pending.parameters)
        }
    }

    private static func send(name: String, parameters: [String: String]) {
        guard isEnabled else { return }
        for sink in sinks {
            sink.send(name: name, parameters: parameters)
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

    /// **하루에 한 번만** 기록한다. 위젯 렌더처럼 계속 되풀이되는 사실은 매번
    /// 담아봐야 같은 말을 반복할 뿐이고, 200칸짜리 이 버퍼를 가득 채워서 정작
    /// 드물고 중요한 이벤트(저장소 실패, 위젯에서 누른 완료)를 밀어낸다.
    ///
    /// `token`은 이벤트를 구분하는 열쇠다(예: 위젯 종류+크기).
    static func recordOncePerDay(_ event: AnalyticsEvent, token: String) {
        guard let defaults else { return }
        let key = "analyticsOncePerDay.\(token)"
        let today = Calendar.current.startOfDay(for: .now)
        if let last = defaults.object(forKey: key) as? Date,
           Calendar.current.startOfDay(for: last) == today {
            return
        }
        defaults.set(today, forKey: key)
        record(event)
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
