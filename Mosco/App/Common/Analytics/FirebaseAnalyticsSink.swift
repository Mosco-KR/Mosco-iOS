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
    /// **Firebase가 보는 것만 본다.** 한때 우리가 써넣은 UserDefaults 키를 도로
    /// 읽어 "켜짐"이라고 찍었는데, 그건 우리가 뭘 시도했는지를 말할 뿐이라
    /// DebugView가 비어 있는데도 로그만 "켜짐"이라 원인을 엉뚱한 데서 찾게 했다.
    /// 확실한 신호는 실행 인자 하나뿐이다.
    private static func logSetupState() {
        #if DEBUG
        guard !ProcessInfo.processInfo.arguments.contains("-FIRDebugEnabled") else {
            print("[Mosco][Analytics] Firebase 준비됨 · DebugView 켜짐")
            return
        }
        print("""
        [Mosco][Analytics] Firebase 준비됨 · DebugView 꺼짐
        [Mosco][Analytics] Xcode > Product > Scheme > Edit Scheme > Run > Arguments 에서
        [Mosco][Analytics] 'Arguments Passed On Launch'에 -FIRDebugEnabled 를 추가하세요.
        [Mosco][Analytics] (스킴 파일에는 이미 있지만, Xcode가 켜진 채로는 다시 읽지 않습니다)
        """)
        #endif
    }

    func send(name: String, parameters: [String: String]) {
        // 모듈 이름을 붙여 부른다 — Firebase에도 `Analytics`가 있어서 이 앱의
        // `Analytics`(Shared)와 겹치고, 안 붙이면 우리 쪽으로 붙어 무한 재귀가 된다.
        FirebaseAnalytics.Analytics.logEvent(name, parameters: parameters)
    }
}
