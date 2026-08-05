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

    /// 앱 쪽에서 **확인 가능한 것만** 찍는다.
    ///
    /// 한때 plist의 `MEASUREMENT_ID`가 없는 걸로 "GA가 연결 안 됐다"고 경고했는데,
    /// 그 키는 애초에 **iOS plist에 없는 키**였다(Firebase 공식 예제에도 없다).
    /// 확인할 수 없는 것을 추측해서 경고하면 엉뚱한 곳을 파게 만든다 —
    /// 실제로 그렇게 시간을 버렸다. 그래서 여기서는 번들 ID와 실행 인자,
    /// 둘 다 이 프로세스 안에서 참/거짓이 확정되는 것만 본다.
    ///
    /// 이 둘이 통과하면 앱 쪽은 끝이다. 그 뒤로도 DebugView가 비어 있다면
    /// 원인은 콘솔(속성 선택·기기 선택·데이터 필터)에 있고, 코드로는 알 수 없다.
    private static func logSetupState() {
        #if DEBUG
        let plistBundleID = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist")
            .flatMap { NSDictionary(contentsOfFile: $0) }?["BUNDLE_ID"] as? String

        if plistBundleID != Bundle.main.bundleIdentifier {
            print("[Mosco][Analytics] ⚠️ plist가 이 앱의 것이 아닙니다(\(plistBundleID ?? "없음")).")
        }

        if ProcessInfo.processInfo.arguments.contains("-FIRDebugEnabled") {
            print("[Mosco][Analytics] 준비됨 · DebugView 켜짐")
        } else {
            print("""
            [Mosco][Analytics] ⚠️ DebugView 꺼짐 — 실행 인자가 없습니다.
            [Mosco][Analytics]    Product > Scheme > Edit Scheme > Run > Arguments 에
            [Mosco][Analytics]    -FIRDebugEnabled 를 추가하세요.
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
