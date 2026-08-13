import SwiftUI
import UIKit

/// 안내를 **앱 창 위에 얹힌 별도의 창**으로 띄운다.
///
/// 처음엔 `RootTabView`의 ZStack에 형제로 얹었는데, 그렇게 하면 두 가지가 깨진다.
/// 하나는 iOS 26의 탭 바가 SwiftUI가 그리는 층보다 위에 렌더되어 **탭 바만 안
/// 어두워지는** 것이고, 다른 하나는 더 치명적이다 — 탭 뷰(UIKit이 받쳐주는 화면)가
/// 화면 전체의 터치를 먼저 가져가서 **안내의 버튼이 눌리지 않는다**. 실제로 그 상태로
/// 시작 카드의 버튼을 눌러도 아무 일도 일어나지 않았다.
///
/// 창을 하나 더 올리면 두 문제가 같이 사라진다. 창은 탭 바를 포함해 앱 전체를 덮고,
/// 터치도 위에서부터 받는다. 그리고 **구멍 안쪽에서는 `hitTest`가 nil을 돌려주므로**
/// 그 자리의 터치만 아래 앱 창으로 그대로 내려간다 — 마스크의 핵심이 이 한 줄이다.
@MainActor
final class TutorialOverlayWindow {
    static let shared = TutorialOverlayWindow()

    private var window: UIWindow?

    private init() {}

    func setVisible(_ visible: Bool) {
        guard visible else {
            window?.isHidden = true
            window = nil
            return
        }
        guard window == nil else { return }
        guard let scene = Self.activeScene else { return }

        let controller = UIHostingController(rootView: TutorialOverlay(tutorial: .shared))
        controller.view.backgroundColor = .clear
        controller.view.isOpaque = false

        let window = PassthroughWindow(windowScene: scene)
        window.rootViewController = controller
        window.backgroundColor = .clear
        window.isOpaque = false
        // 딱 한 단계만 위로. 키보드·시스템 알림창은 이보다 높은 곳에 떠서,
        // 안내가 그것들까지 덮어버리는 일은 없다.
        window.windowLevel = .normal + 1
        // **키 창은 앱 창에 그대로 둔다.** 창을 하나 띄우면 키 창이 이쪽으로 넘어올
        // 수 있는데, 그러면 아래 앱에서 편집 중이던 입력창이 키 입력을 못 받는다 —
        // 커서만 깜빡이고 글자가 안 써지는 상태가 된다(첫 단계가 바로 그 입력창이라
        // 이건 튜토리얼 전체를 못 쓰게 만드는 문제다).
        let previousKeyWindow = scene.keyWindow
        window.isHidden = false
        previousKeyWindow?.makeKey()
        self.window = window
    }

    private static var activeScene: UIWindowScene? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
            ?? UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
    }
}

/// 구멍 안쪽의 터치만 아래로 흘려보내는 창.
private final class PassthroughWindow: UIWindow {
    /// **키 창이 되면 안 된다.** 키 창이 이쪽으로 넘어오면 아래 앱에서 편집 중이던
    /// 입력창이 키 입력을 못 받는다 — 커서는 깜빡이는데 글자는 안 써지는, 첫
    /// 단계에서 바로 막히는 상태가 된다. 터치를 받는 것과는 무관한 성질이라
    /// 꺼둬도 안내의 버튼은 그대로 눌린다.
    override var canBecomeKey: Bool { false }

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let tutorial = TutorialCoordinator.shared
        // 안내가 없으면 이 창은 없는 것처럼 군다.
        guard let step = tutorial.step else { return nil }

        // 마스크를 씌우지 않는 단계(마지막 '정리')에서는 안내 카드만 터치를 받고
        // 나머지는 전부 앱으로 흘린다. 그 단계의 과제가 **시스템 메뉴를 여는 것**이라
        // 화면을 막아버리면 정작 눌러야 할 메뉴를 누를 수 없다.
        guard step.masksBackground else {
            return tutorial.guidanceFrame.contains(point) ? super.hitTest(point, with: event) : nil
        }

        // 밝게 뚫어놓은 자리 — 여기만 아래 화면이 직접 터치를 받는다.
        if let hole = tutorial.spotlightRect(), hole.contains(point) { return nil }
        return super.hitTest(point, with: event)
    }
}
