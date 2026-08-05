import FirebaseAnalytics
import FirebaseCore
import Foundation

/// Firebase로 이벤트를 보내는 sink.
struct FirebaseAnalyticsSink: AnalyticsSink {
    /// `configure()`를 두 번 부르면 예외가 난다.
    private nonisolated(unsafe) static var didConfigure = false

    /// Firebase를 켜고 sink를 돌려준다. plist가 없으면 nil — 파일을 빠뜨린 빌드에서
    /// `configure()`가 앱을 통째로 죽이는 것보다 분석만 조용히 꺼지는 게 낫다.
    static func configure() -> FirebaseAnalyticsSink? {
        guard Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") != nil else {
            return nil
        }
        if !didConfigure {
            FirebaseApp.configure()
            didConfigure = true
        }
        return FirebaseAnalyticsSink()
    }

    func send(name: String, parameters: [String: String]) {
        // 모듈 이름을 붙여 부른다 — Firebase에도 `Analytics`가 있어서 이 앱의
        // `Analytics`(Shared)와 겹치고, 안 붙이면 우리 쪽으로 붙어 무한 재귀가 된다.
        FirebaseAnalytics.Analytics.logEvent(name, parameters: parameters)
    }
}
