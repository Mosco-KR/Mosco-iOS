import SwiftUI

/// 스포트라이트가 겨눌 수 있는 자리들.
///
/// 같은 할 일이 '할 일' 탭 목록과 하루치 페이지에 **동시에** 그려질 수 있어서
/// 줄은 화면까지 키에 담는다 — 하나로 두면 지금 안 보이는 쪽이 마지막에 자리를
/// 덮어써서, 스포트라이트가 화면 밖을 겨누게 된다.
enum TutorialTargetID: Hashable {
    /// 하단 입력창(QuickAddView) 전체. 위에 떠오르는 시간 칩까지 이 자리를
    /// 넓혀서 함께 덮는다(`TutorialStep.holeInsets`).
    case composeBar
    /// '할 일' 탭 목록의 그 줄.
    case todayRow(UUID)
    /// 하루치 페이지 목록의 그 줄.
    case dayRow(UUID)
    /// 달력 격자에서 오늘 칸.
    case todayCell
}

extension View {
    /// 이 자리를 튜토리얼이 겨눌 수 있게 등록한다.
    ///
    /// 평소에는 **아무 일도 하지 않는다** — 지금 겨누고 있는 자리일 때만
    /// GeometryReader가 생기고, 그 하나만 좌표를 올려보낸다.
    func tutorialTarget(_ id: TutorialTargetID) -> some View {
        modifier(TutorialTargetModifier(id: id))
    }
}

private struct TutorialTargetModifier: ViewModifier {
    /// 튜토리얼이 없는 자리(프리뷰 등)에서도 안전하도록 옵셔널로 받는다.
    @Environment(TutorialCoordinator.self) private var tutorial: TutorialCoordinator?
    let id: TutorialTargetID

    func body(content: Content) -> some View {
        // 조건을 **배경 안쪽**에 둔다. 바깥에 두면 튜토리얼이 켜지고 꺼질 때마다
        // 내용물의 정체성이 바뀌어서, 리스트의 줄이 통째로 다시 만들어진다.
        content.background {
            if tutorial?.needsFrame(for: id) == true {
                GeometryReader { proxy in
                    // 오버레이도 같은 좌표계(.global)로 환산해서 쓴다. 탭 뷰나
                    // 내비게이션 스택을 사이에 두고 preference를 올려보내는 방식은
                    // 컨테이너에 따라 값이 안 올라오는 일이 있어서, 좌표를 직접 잰다.
                    let frame = proxy.frame(in: .global)
                    Color.clear
                        .onAppear { tutorial?.report(frame, for: id) }
                        .onChange(of: frame) { _, updated in
                            tutorial?.report(updated, for: id)
                        }
                        .onDisappear { tutorial?.clearFrame(for: id) }
                }
            }
        }
    }
}
