import SwiftUI
import UIKit

/// 하루치 할 일 리스트를 좌우로 넘겨 날짜를 이동하는 제스처 다리.
///
/// `DirectionalCarouselGesture`와 목적은 같지만 방향이 반대다. 그쪽은 세로
/// 스크롤이 "조상"(바깥 ScrollView)이라 위로 올라가며 찾았지만, 여기서는 세로
/// 스크롤이 "자손"(각 페이지의 List)이다. 그래서 공통 컨테이너에 인식기를 얹고,
/// 가로로 방향이 확정되는 순간 아래쪽 List들의 pan을 꺼서 세로 스크롤이 이 터치를
/// 더 가져가지 못하게 한다(끔-켬이 UIKit에서 통하는 취소 트릭).
///
/// SwiftUI의 DragGesture만으로는 안 되는 이유도 같다 — List가 자기 스크롤 제스처를
/// 먼저 가져가면 가로 드래그가 아예 안 잡히고, simultaneous로 붙이면 이번엔 가로로
/// 미는 동안 세로로도 같이 흘러서 화면이 비스듬히 끌려간다.
final class HorizontalPagingCoordinator: NSObject, UIGestureRecognizerDelegate {
    var onChanged: (CGFloat) -> Void = { _ in }
    var onEnded: (CGFloat) -> Void = { _ in }
    var isEnabled: () -> Bool = { true }

    private(set) var recognizer: UIPanGestureRecognizer?
    private weak var container: UIView?

    private enum Lock { case none, horizontal, vertical }
    private var lock: Lock = .none

    /// 리스트들을 실제로 품고 있는 조상에 얹어야, 리스트 위에서 시작한 터치도 이
    /// 인식기로 들어온다. `.background`로 심은 앵커의 바로 위(superview)는 배경
    /// 레이어용 컨테이너라 리스트를 포함하지 않을 수 있어서, 자손에 UIScrollView(=각
    /// 페이지의 List)가 실제로 들어있는 첫 조상까지 거슬러 올라간다.
    @discardableResult
    func attachIfNeeded(from anchor: UIView) -> Bool {
        guard recognizer == nil else { return true }
        var candidate: UIView? = anchor.superview
        while let view = candidate, !containsScrollView(view) {
            candidate = view.superview
        }
        guard let container = candidate else { return false }

        self.container = container
        let recognizer = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        recognizer.delegate = self
        recognizer.cancelsTouchesInView = false
        container.addGestureRecognizer(recognizer)
        self.recognizer = recognizer
        return true
    }

    private func containsScrollView(_ view: UIView) -> Bool {
        for subview in view.subviews {
            if subview is UIScrollView { return true }
            if containsScrollView(subview) { return true }
        }
        return false
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
                        cancelDescendantScrolling()
                    } else {
                        lock = .vertical
                    }
                }
            }
            if lock == .horizontal {
                onChanged(translation.x)
            }
        case .ended, .cancelled, .failed:
            if lock == .horizontal {
                onEnded(translation.x)
            }
            lock = .none
        default:
            break
        }
    }

    private func cancelDescendantScrolling() {
        guard let container else { return }
        forEachScrollView(in: container) { scrollView in
            scrollView.panGestureRecognizer.isEnabled = false
            scrollView.panGestureRecognizer.isEnabled = true
        }
    }

    private func forEachScrollView(in view: UIView, _ body: (UIScrollView) -> Void) {
        for subview in view.subviews {
            if let scrollView = subview as? UIScrollView { body(scrollView) }
            forEachScrollView(in: subview, body)
        }
    }

    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        true
    }

    /// 리스트 셀 위에서 시작한 터치는 아예 받지 않는다 — 셀의 좌우 스와이프
    /// 액션(메모/삭제)과 방향이 같아서, 받으면 그쪽이 통째로 먹힌다.
    /// 셀 바깥(빈 영역)에서 시작한 가로 드래그만 날짜 페이징으로 쓴다.
    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldReceive touch: UITouch
    ) -> Bool {
        var view: UIView? = touch.view
        while let current = view {
            if current is UICollectionViewCell || current is UITableViewCell { return false }
            view = current.superview
        }
        return true
    }
}

struct HorizontalPagingGesture: UIViewRepresentable {
    let isEnabled: Bool
    let onChanged: (CGFloat) -> Void
    let onEnded: (CGFloat) -> Void

    func makeCoordinator() -> HorizontalPagingCoordinator {
        HorizontalPagingCoordinator()
    }

    func makeUIView(context: Context) -> UIView {
        let anchor = UIView(frame: .zero)
        anchor.isHidden = true
        anchor.isUserInteractionEnabled = false
        context.coordinator.onChanged = onChanged
        context.coordinator.onEnded = onEnded
        // 리스트(UIScrollView)까지 다 올라오기 전에는 붙을 조상을 못 찾는다 —
        // 한 번에 안 되면 몇 프레임 뒤에 다시 시도한다.
        retryAttach(context.coordinator, from: anchor, remaining: 10)
        return anchor
    }

    private func retryAttach(_ coordinator: HorizontalPagingCoordinator, from anchor: UIView, remaining: Int) {
        guard remaining > 0 else { return }
        DispatchQueue.main.async {
            if !coordinator.attachIfNeeded(from: anchor) {
                retryAttach(coordinator, from: anchor, remaining: remaining - 1)
            }
        }
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.onChanged = onChanged
        context.coordinator.onEnded = onEnded
        let enabled = isEnabled
        context.coordinator.isEnabled = { enabled }
        if context.coordinator.recognizer == nil {
            context.coordinator.attachIfNeeded(from: uiView)
        }
    }
}
