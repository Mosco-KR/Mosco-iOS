import SwiftUI
import UIKit

/// 캘린더 캐러셀의 좌우 페이지 넘기기와 바깥 ScrollView의 상하 스크롤이 서로
/// 자기 축만 가져가게 조정하는 다리 역할.
///
/// SwiftUI의 `DragGesture` + `simultaneousGesture`만으로는 안 됐다 — 버튼/블록
/// 위에서 시작한 터치는 (가로는 되지만) ScrollView의 세로 인식을 막아버리고,
/// 반대로 빈 영역에서 시작한 터치는 (세로는 되지만) 가로 페이징을 인식하지
/// 못했다. SwiftUI 제스처 시스템은 "이겼다"고 판단된 인식기를 명시적으로 취소할
/// 방법이 없어서, 방향이 갈리는 순간 진 쪽(ScrollView의 pan)을 UIKit 레벨에서
/// 직접 취소해야만 둘이 서로 침범하지 않는다.
///
/// 새 뷰를 얹어 히트테스트 순서를 바꾸는 대신, 발견한 조상 UIScrollView에
/// 우리 UIPanGestureRecognizer를 "같이" 얹는다 — ScrollView가 원래 자기
/// 서브뷰(버튼 등)와 동시 인식하는 방식 그대로, 우리 인식기도 얹혀가는 것이라
/// 히트테스트 경로를 새로 만들 필요가 없다.
final class DirectionalPanCoordinator: NSObject, UIGestureRecognizerDelegate {
    var onHorizontalChange: (CGFloat) -> Void = { _ in }
    var onHorizontalEnd: (CGFloat) -> Void = { _ in }
    var isEnabled: () -> Bool = { true }

    private(set) var recognizer: UIPanGestureRecognizer?
    private weak var scrollView: UIScrollView?

    private enum Lock { case none, horizontal, vertical }
    private var lock: Lock = .none

    func attachIfNeeded(from anchor: UIView) {
        guard recognizer == nil, let scrollView = findAncestorScrollView(from: anchor) else { return }
        self.scrollView = scrollView
        let recognizer = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        recognizer.delegate = self
        recognizer.cancelsTouchesInView = false
        scrollView.addGestureRecognizer(recognizer)
        self.recognizer = recognizer
    }

    @objc private func handlePan(_ recognizer: UIPanGestureRecognizer) {
        guard isEnabled(), let view = recognizer.view else {
            lock = .none
            return
        }
        let translation = recognizer.translation(in: view)

        switch recognizer.state {
        case .began:
            lock = .none
        case .changed:
            if lock == .none {
                let threshold: CGFloat = 8
                if abs(translation.x) > threshold || abs(translation.y) > threshold {
                    if abs(translation.x) > abs(translation.y) {
                        lock = .horizontal
                        // 세로 스크롤이 이 터치를 계속 못 가져가도록 진행 중인
                        // 인식을 취소한다(끔-켬이 UIKit에서 통하는 취소 트릭).
                        scrollView?.panGestureRecognizer.isEnabled = false
                        scrollView?.panGestureRecognizer.isEnabled = true
                    } else {
                        lock = .vertical
                    }
                }
            }
            if lock == .horizontal {
                onHorizontalChange(translation.x)
            }
        case .ended, .cancelled, .failed:
            if lock == .horizontal {
                onHorizontalEnd(translation.x)
            }
            lock = .none
        default:
            break
        }
    }

    private func findAncestorScrollView(from view: UIView) -> UIScrollView? {
        var current: UIView? = view.superview
        while let candidate = current {
            if let scrollView = candidate as? UIScrollView { return scrollView }
            current = candidate.superview
        }
        return nil
    }

    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        true
    }
}

/// 보이지 않는 앵커 뷰 하나만 심어서, 조상 ScrollView를 찾아 그 위에 직접
/// pan 인식기를 추가한다 — 새 뷰가 화면 히트테스트 순서에 끼어들지 않는다.
struct DirectionalCarouselGesture: UIViewRepresentable {
    let isEnabled: Bool
    let onChanged: (CGFloat) -> Void
    let onEnded: (CGFloat) -> Void

    func makeCoordinator() -> DirectionalPanCoordinator {
        DirectionalPanCoordinator()
    }

    func makeUIView(context: Context) -> UIView {
        let anchor = UIView(frame: .zero)
        anchor.isHidden = true
        anchor.isUserInteractionEnabled = false
        context.coordinator.onHorizontalChange = onChanged
        context.coordinator.onHorizontalEnd = onEnded
        DispatchQueue.main.async {
            context.coordinator.attachIfNeeded(from: anchor)
        }
        return anchor
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.onHorizontalChange = onChanged
        context.coordinator.onHorizontalEnd = onEnded
        let enabled = isEnabled
        context.coordinator.isEnabled = { enabled }
        if context.coordinator.recognizer == nil {
            context.coordinator.attachIfNeeded(from: uiView)
        }
    }
}
