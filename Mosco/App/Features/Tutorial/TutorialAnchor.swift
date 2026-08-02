import SwiftUI

/// 튜토리얼이 조명할 수 있는 자리들. 각 화면이 자기 요소에 `.tutorialAnchor(...)`를
/// 붙여 위치를 알려주면, 오버레이가 그 위치만 뚫고 나머지를 덮는다.
enum TutorialTarget: Hashable {
    case monthGrid
    case weekStrip
    case composeField
    case sendButton
    case firstTodoCheck
    case firstTodoRow
    case timeSuggestion
    case categoryButton
    case categoryPopup
}

/// 화면 곳곳에 흩어진 대상들의 좌표를 오버레이 한 곳으로 모은다.
struct TutorialAnchorKey: PreferenceKey {
    static var defaultValue: [TutorialTarget: Anchor<CGRect>] = [:]

    static func reduce(
        value: inout [TutorialTarget: Anchor<CGRect>],
        nextValue: () -> [TutorialTarget: Anchor<CGRect>]
    ) {
        value.merge(nextValue()) { _, latest in latest }
    }
}

extension View {
    /// 이 뷰를 튜토리얼이 가리킬 수 있는 대상으로 등록한다.
    /// nil을 넘기면 등록하지 않는다 — 목록의 첫 행만 가리키는 식으로 쓸 때 편하다.
    @ViewBuilder
    func tutorialAnchor(_ target: TutorialTarget?) -> some View {
        if let target {
            anchorPreference(key: TutorialAnchorKey.self, value: .bounds) { [target: $0] }
        } else {
            self
        }
    }
}
