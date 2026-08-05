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
    /// `FirebaseApp.configure()`까지 여기서 한다 — 앱 델리게이트에 Firebase
    /// 관련 코드가 흩어지지 않게.
    static func configure() -> FirebaseAnalyticsSink? {
        // GoogleService-Info.plist가 번들에 없으면 configure()가 크래시한다.
        // 파일을 아직 안 넣었거나 타겟 멤버십을 빠뜨린 빌드에서 앱이 통째로
        // 죽는 것보다, 분석만 조용히 꺼지는 편이 낫다.
        guard Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") != nil else {
            return nil
        }
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }
        return FirebaseAnalyticsSink()
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
