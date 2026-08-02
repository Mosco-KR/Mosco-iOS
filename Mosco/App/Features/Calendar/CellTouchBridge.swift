import SwiftUI
import UIKit

/// 달 격자의 터치(누름 피드백 + 탭 선택)를 받는 UIKit 다리.
///
/// **SwiftUI 제스처를 쓰면 안 되는 이유가 있다.** 처음엔 `DragGesture(minimumDistance: 0)`을
/// `simultaneousGesture`로 얹어 눌림 상태를 받았는데, 실기기에서 **한 손가락 스와이프로
/// 달이 안 넘어갔다**(두 손가락으로는 넘어갔다). SwiftUI의 드래그 제스처가 단일 터치
/// 시퀀스를 먼저 채가서 바깥 UIScrollView의 pan이 시작조차 못 한 것이다 — 두 손가락
/// pan은 단일 터치 제스처가 안 잡으니 그때만 스크롤뷰로 넘어갔다. (시뮬레이터의 합성
/// 터치로는 이 중재가 재현되지 않는다. 실기기에서만 드러난다.)
///
/// `UILongPressGestureRecognizer`는 그런 문제가 없다:
/// - pan을 막지 않는다(요구 실패 관계를 걸지 않는 한 조상의 pan은 그대로 시작된다)
/// - `cancelsTouchesInView = false`라 터치가 뷰로 계속 흐른다
/// - 스크롤이 시작되면 UIScrollView가 콘텐츠 뷰의 터치를 취소해서 이 인식기도 함께
///   취소된다 → 눌림 하이라이트가 저절로 걷히고, 스와이프가 탭으로 잘못 처리되지도
///   않는다(예전의 `isDragging` + 지연 해제 같은 수동 억제가 필요 없어졌다)
///
/// `minimumPressDuration = 0`이라 누르는 즉시 `.began`이 온다. 다만 이동 판정은 직접
/// 해야 한다 — `allowableMovement`는 **인식되기 전까지만** 적용되는 값이라, 즉시
/// 인식되는 이 설정에서는 손가락이 아무리 움직여도 실패로 치지 않고 그대로 `.ended`가
/// 온다(그래서 스와이프가 통째로 날짜 선택으로 처리되는 버그가 났었다).
struct CellTouchBridge: UIViewRepresentable {
    /// 누르고 있는 지점(뷰 로컬 좌표). 손을 떼거나 스크롤이 시작되면 nil.
    let onPressChanged: (CGPoint?) -> Void
    /// 움직임 없이 손을 뗀 지점 — 곧 탭이다.
    let onTap: (CGPoint) -> Void
    /// 아래로 끌어내렸을 때(압축된 주간 스트립을 펼칠 때). 안 쓰면 nil.
    ///
    /// 이것도 같은 뷰에 얹어야 한다 — 형제 뷰에 올리면 위에 깔린 뷰가 터치를
    /// 가져가서 인식기까지 닿지 않는다. UIKit pan은 동시 인식을 허용하면 가로
    /// 페이징을 막지 않으므로 나란히 둘 수 있다.
    var onPullDown: (() -> Void)? = nil
    let isEnabled: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(onPressChanged: onPressChanged, onTap: onTap, onPullDown: onPullDown)
    }

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .clear

        let press = UILongPressGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handlePress(_:))
        )
        press.minimumPressDuration = 0
        press.cancelsTouchesInView = false
        press.delaysTouchesBegan = false
        press.delaysTouchesEnded = false
        press.delegate = context.coordinator
        view.addGestureRecognizer(press)

        let pull = UIPanGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handlePull(_:))
        )
        pull.cancelsTouchesInView = false
        pull.delegate = context.coordinator
        view.addGestureRecognizer(pull)

        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.onPressChanged = onPressChanged
        context.coordinator.onTap = onTap
        context.coordinator.onPullDown = onPullDown
        uiView.isUserInteractionEnabled = isEnabled
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var onPressChanged: (CGPoint?) -> Void
        var onTap: (CGPoint) -> Void
        var onPullDown: (() -> Void)?

        private var startLocation: CGPoint?
        /// 한 번이라도 이 거리를 넘으면 그 터치는 끝까지 "스와이프"로 본다 —
        /// 손을 떼는 순간 우연히 시작점 근처로 돌아와 있어도 탭이 되면 안 된다.
        private var didMove = false
        private let movementThreshold: CGFloat = 10

        init(
            onPressChanged: @escaping (CGPoint?) -> Void,
            onTap: @escaping (CGPoint) -> Void,
            onPullDown: (() -> Void)?
        ) {
            self.onPressChanged = onPressChanged
            self.onTap = onTap
            self.onPullDown = onPullDown
        }

        /// 아래로 뚜렷하게 끌어내렸을 때만 반응한다 — 가로 성분이 더 크면 그건
        /// 페이징이므로 손대지 않는다.
        @objc func handlePull(_ recognizer: UIPanGestureRecognizer) {
            guard let onPullDown, let view = recognizer.view, recognizer.state == .ended else { return }
            let translation = recognizer.translation(in: view)
            guard translation.y > 30, translation.y > abs(translation.x) else { return }
            onPullDown()
        }

        @objc func handlePress(_ recognizer: UILongPressGestureRecognizer) {
            guard let view = recognizer.view else { return }
            let location = recognizer.location(in: view)

            switch recognizer.state {
            case .began:
                startLocation = location
                didMove = false
                onPressChanged(location)

            case .changed:
                guard !didMove, let start = startLocation else { return }
                if hypot(location.x - start.x, location.y - start.y) > movementThreshold {
                    didMove = true
                    // 스와이프로 판명 — 하이라이트를 즉시 걷는다.
                    onPressChanged(nil)
                }

            case .ended:
                onPressChanged(nil)
                if !didMove { onTap(location) }
                startLocation = nil
                didMove = false

            default:
                // .cancelled(스크롤뷰가 터치를 가져감) / .failed — 선택은 일어나지 않는다.
                onPressChanged(nil)
                startLocation = nil
                didMove = false
            }
        }

        /// 바깥 스크롤뷰의 pan과 나란히 인식되게 한다 — 어느 쪽도 상대를 막지 않는다.
        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
        ) -> Bool {
            true
        }
    }
}
