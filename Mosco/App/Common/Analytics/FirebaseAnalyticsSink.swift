import FirebaseAnalytics
import FirebaseCore
import Foundation

/// Firebase로 이벤트를 보내는 sink.
struct FirebaseAnalyticsSink: AnalyticsSink {
    /// Firebase가 디버그 모드를 기억해두는 자리.
    private static let debugModeKey = "/google/measurement_debug_mode"
    /// `configure()`를 두 번 부르면 예외가 난다. `FirebaseApp.app()`으로 확인하면
    /// 그 호출이 "not yet been configured" 경고를 찍어 설정이 안 된 것처럼 보이므로,
    /// 우리 플래그로 판단한다.
    private nonisolated(unsafe) static var didConfigure = false

    /// Firebase를 켜고 sink를 돌려준다. plist가 없으면 nil — 파일을 빠뜨린 빌드에서
    /// `configure()`가 앱을 통째로 죽이는 것보다 분석만 조용히 꺼지는 게 낫다.
    static func configure() -> FirebaseAnalyticsSink? {
        guard Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") != nil else {
            return nil
        }
        guard !didConfigure else { return FirebaseAnalyticsSink() }

        // 디버그 모드는 UserDefaults에 **남는다.** 같은 기기에 디버그 빌드를
        // 올렸다가 릴리스로 덮으면 컨테이너를 공유하므로 켜진 상태가 이어지고,
        // 그 기기의 실사용 이벤트가 전부 디버그로 분류돼 일반 리포트에서 통째로
        // 빠진다. 조용히 그렇게 되므로 나중에 "왜 데이터가 적지"로만 나타난다.
        #if !DEBUG
        UserDefaults.standard.set(false, forKey: debugModeKey)
        #endif

        FirebaseApp.configure()
        didConfigure = true
        logSetupState()
        return FirebaseAnalyticsSink()
    }

    /// DebugView가 비어 있을 때 원인을 여기서 끝낸다.
    ///
    /// 이 셋이 전부 조용히 실패한다 — 이벤트는 정상 발생하고, 업로드도 204로
    /// 성공하고, 콘솔에만 아무것도 안 뜬다. 그래서 하나씩 눈으로 확인할 수 있게
    /// 찍는다. 특히 마지막(GA 속성 연결)은 Firebase가 경고조차 안 준다.
    private static func logSetupState() {
        #if DEBUG
        let plist = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist")
            .flatMap { NSDictionary(contentsOfFile: $0) }

        if plist?["BUNDLE_ID"] as? String != Bundle.main.bundleIdentifier {
            print("[Mosco][Analytics] ⚠️ plist가 이 앱의 것이 아닙니다. 번들 ID로 앱을 등록하고 받으세요.")
        }

        if !ProcessInfo.processInfo.arguments.contains("-FIRDebugEnabled") {
            print("""
            [Mosco][Analytics] ⚠️ DebugView 꺼짐 — 실행 인자가 없습니다.
            [Mosco][Analytics]    Product > Scheme > Edit Scheme > Run > Arguments 에
            [Mosco][Analytics]    -FIRDebugEnabled 추가 (스킴 파일에는 있지만 Xcode가
            [Mosco][Analytics]    켜진 채로는 다시 읽지 않습니다)
            """)
        }

        // plist에 MEASUREMENT_ID가 없고 IS_ANALYTICS_ENABLED가 false면, 이 Firebase
        // 프로젝트에 Google Analytics 속성이 붙어 있지 않다는 뜻이다. 그러면 이벤트가
        // 수집 엔드포인트까지 가서 204를 받고도 저장될 곳이 없어 **DebugView도 일반
        // 리포트도 영영 비어 있다.** SDK는 이걸 오류로 알려주지 않는다.
        if plist?["MEASUREMENT_ID"] == nil, plist?["IS_ANALYTICS_ENABLED"] as? Bool != true {
            print("""
            [Mosco][Analytics] ⚠️ 이 Firebase 프로젝트에 Google Analytics가 연결돼 있지 않습니다.
            [Mosco][Analytics]    콘솔 > 프로젝트 설정 > 통합 > Google Analytics 사용 설정 후
            [Mosco][Analytics]    GoogleService-Info.plist를 다시 받아 교체하세요.
            [Mosco][Analytics]    (새 plist에는 MEASUREMENT_ID가 생깁니다)
            """)
        }
        #endif
    }

    func send(name: String, parameters: [String: String]) {
        // 모듈 이름을 붙여 부른다 — Firebase에도 `Analytics`가 있어서 이 앱의
        // `Analytics`(Shared)와 겹치고, 안 붙이면 우리 쪽으로 붙어 무한 재귀가 된다.
        FirebaseAnalytics.Analytics.logEvent(name, parameters: parameters)
    }
}
