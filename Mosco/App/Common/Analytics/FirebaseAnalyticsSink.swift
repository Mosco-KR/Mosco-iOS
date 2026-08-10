import FirebaseAnalytics
import FirebaseCore
import Foundation

/// Firebase로 이벤트를 보내는 sink.
struct FirebaseAnalyticsSink: AnalyticsSink {
    /// `configure()`를 두 번 부르면 예외가 난다.
    private nonisolated(unsafe) static var didConfigure = false

    /// 개발 중에 켜고 싶을 때만 주는 실행 인자
    /// (Xcode: Scheme > Run > Arguments Passed On Launch).
    static let debugSendLaunchArgument = "-MoscoFirebaseSend"

    /// 이 빌드가 Firebase로 이벤트를 보내도 되는가.
    ///
    /// **디버그 빌드는 기본적으로 보내지 않는다.** 예전엔 빌드 구성과 무관하게
    /// 보냈는데, 그래서 개발 중의 시뮬레이터·개발 기기 실행이 전부 실사용자로
    /// 집계됐다 — 다운로드 3회인 앱의 활성 기기가 10대 넘게 잡힌 원인이다.
    /// Firebase의 앱 인스턴스 ID는 설치할 때마다 새로 생기므로, 시뮬레이터를
    /// 지웠다 깔 때마다 없는 기기가 한 대씩 늘어난다.
    ///
    /// 이벤트 이름·파라미터를 DebugView로 확인해야 할 때는 실행 인자로 **그때만**
    /// 켠다. 코드에 켜둔 채로 두면 잊어버리고 다시 오염시키게 된다.
    static var shouldSend: Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains(debugSendLaunchArgument)
        #else
        true
        #endif
    }

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
