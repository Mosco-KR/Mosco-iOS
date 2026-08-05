import Foundation

#if canImport(FirebaseCore) && canImport(FirebaseAnalytics)
import FirebaseCore
import FirebaseAnalytics

/// Firebase로 이벤트를 보내는 sink.
///
/// **`#if canImport`으로 감싼 이유**: Firebase SDK를 아직 패키지로 추가하지
/// 않아도 이 파일이 컴파일을 깨뜨리지 않게 하려는 것이다. SPM으로 패키지를
/// 넣는 순간 이 블록이 살아나고, 그 전까지는 아래 no-op 쪽이 쓰인다 —
/// 호출부(`MoscoApp`)는 어느 쪽이든 똑같이 생겼다.
struct FirebaseAnalyticsSink: AnalyticsSink {
    /// 두 번 부르면 configure()가 예외를 던진다. `FirebaseApp.app()`으로 확인할
    /// 수도 있지만, 그 호출 자체가 "not yet been configured" 경고를 콘솔에 찍어서
    /// **설정이 안 된 것처럼 보이게** 만든다 — 실제로는 바로 다음 줄에서 설정된다.
    /// 우리 쪽 플래그로 판단해 그 오해를 없앤다.
    private nonisolated(unsafe) static var didConfigure = false

    /// `FirebaseApp.configure()`까지 여기서 한다 — 앱 델리게이트에 Firebase
    /// 관련 코드가 흩어지지 않게.
    static func configure() -> FirebaseAnalyticsSink? {
        // GoogleService-Info.plist가 번들에 없으면 configure()가 크래시한다.
        // 파일을 아직 안 넣었거나 타겟 멤버십을 빠뜨린 빌드에서 앱이 통째로
        // 죽는 것보다, 분석만 조용히 꺼지는 편이 낫다.
        guard let path = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") else {
            return nil
        }
        if !didConfigure {
            assertBundleIDMatches(plistAt: path)
            FirebaseApp.configure()
            didConfigure = true
        }
        return FirebaseAnalyticsSink()
    }

    /// plist에 적힌 번들 ID가 이 앱과 다르면 이벤트가 **다른 앱 등록으로 흘러가서**
    /// 콘솔에서는 아무것도 안 보인다. Firebase는 경고만 남기고 계속 도는데, 그
    /// 경고는 다른 로그에 파묻히기 쉬워서 개발 빌드에서는 크게 티를 낸다.
    private static func assertBundleIDMatches(plistAt path: String) {
        #if DEBUG
        guard let plist = NSDictionary(contentsOfFile: path),
              let expected = plist["BUNDLE_ID"] as? String,
              let actual = Bundle.main.bundleIdentifier,
              expected != actual
        else { return }
        assertionFailure("""
        GoogleService-Info.plist가 이 앱의 것이 아닙니다.
        plist: \(expected) / 이 앱: \(actual)
        Firebase 콘솔에서 '\(actual)' 번들 ID로 iOS 앱을 등록하고 그 plist를 받으세요.
        """)
        #endif
    }

    func send(name: String, parameters: [String: String]) {
        // Firebase 이벤트 이름 규칙: 40자 이하, 영문자로 시작, 영숫자와 밑줄만.
        // `AnalyticsEvent.name`이 이미 그 규칙을 지키는 snake_case다.
        //
        // 모듈 이름까지 붙여 부른다 — Firebase에도 `Analytics`가 있어서 이 앱의
        // `Analytics`(Shared)와 이름이 겹친다. 안 붙이면 우리 쪽으로 붙어서
        // 무한 재귀가 된다.
        FirebaseAnalytics.Analytics.logEvent(name, parameters: parameters)
    }
}

#else

/// Firebase 패키지가 아직 없을 때 자리를 지키는 쪽. 아무것도 보내지 않는다.
struct FirebaseAnalyticsSink: AnalyticsSink {
    static func configure() -> FirebaseAnalyticsSink? { nil }
    func send(name: String, parameters: [String: String]) {}
}

#endif
