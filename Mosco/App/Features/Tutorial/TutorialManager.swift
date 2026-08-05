import Foundation
import SwiftUI
import UIKit

/// 참여형 튜토리얼의 상태 머신.
///
/// **기능을 하나씩 나열하지 않고 "해보는 흐름"을 따라가게 한다.** 1장에서는 평범한
/// 일정 하나를 시간까지 붙여 만들고, 완료했다가 지워본다. 2장에서는 카테고리를
/// 직접 만들고 자동 분류가 걸리는 걸 본다. 3장은 화면을 옮겨 다니는 법이다.
/// 기능 이름을 외우는 게 아니라 한 번 해본 기억이 남는 게 목적이다.
///
/// 각 단계는 **그 단계에서 의미 있는 일이 실제로 벌어졌을 때만** 넘어간다.
/// 예전엔 제목에 한 글자만 들어가도 다음으로 넘겼는데, 그래서 "오후 3시"를 다
/// 치기도 전에 단계가 지나가 시간 칩을 눌러볼 기회 자체가 없었다.
@Observable
final class TutorialManager {
    enum Step: Int, CaseIterable {
        case welcome

        // 일정 하나를 처음부터 끝까지 만들어보는 흐름
        case selectDate
        case writeWithTime
        case categoryHint
        case sendTodo
        case completeTodo
        case longPressTodo
        case deleteTodo

        case swipeWeek

        case finish

        /// 읽고 누르는 카드인지, 실제 조작을 기다리는 단계인지.
        var isCard: Bool {
            self == .welcome || self == .finish
        }

        /// 해볼 것 없이 **알려주기만** 하는 단계. 아무 데나 누르면 넘어간다.
        ///
        /// 카테고리는 원래 "직접 만들어보세요"로 한 장을 통째로 썼는데, 자동 분류가
        /// 이 앱의 기본 동작이라 사용자가 손댈 일이 거의 없다 — 손이 갈 일 없는 걸
        /// 굳이 시키면 튜토리얼만 길어진다. 어디를 보면 되는지 화살표로 짚어주는
        /// 것으로 충분하다.
        var isHint: Bool { self == .categoryHint }

        /// 이 단계에서 조명할 자리. nil이면 화면 전체를 덮는 카드다.
        var target: TutorialTarget? {
            switch self {
            case .welcome, .finish: nil
            case .selectDate: .monthGrid
            case .writeWithTime: .composeField
            case .categoryHint: .categoryButton
            case .sendTodo: .sendButton
            case .completeTodo: .firstTodoCheck
            case .longPressTodo, .deleteTodo: .firstTodoRow
            case .swipeWeek: .weekStrip
            }
        }

        var gesture: TutorialGestureHint? {
            switch self {
            case .selectDate, .sendTodo, .completeTodo:
                .tap
            case .swipeWeek: .swipeHorizontal
            case .deleteTodo: .swipeLeft
            case .longPressTodo: .longPress
            // 안내 단계는 "여기를 보세요"라 손짓 대신 가리키는 화살표를 쓴다.
            case .categoryHint: .pointAt
            case .writeWithTime, .welcome, .finish: nil
            }
        }

        /// 조명한 자리 말고 다른 곳의 조작을 막을지.
        ///
        /// **손가락을 끌어야 하는 단계에서는 막지 않는다.** 가림막은 탭뿐 아니라
        /// 드래그도 함께 흡수해서, 스와이프 단계에서 켜두면 정작 밀어야 할 행이
        /// 안 밀린다(삭제 튜토리얼에서 터치가 막혀 있던 원인). 글을 쓰는 단계도
        /// 마찬가지로 열어둔다 — 입력 중에 갇히는 게 제일 나쁘다.
        var blocksInteraction: Bool {
            switch self {
            // 카테고리 단계는 버튼을 누르면 그 위로 목록 팝업이 뜬다 — 팝업까지
            // 밝히더라도 차단이 걸려 있으면 그 안의 항목이 안 눌려 진행이 막힌다.
            case .swipeWeek, .deleteTodo, .longPressTodo, .writeWithTime: false
            default: true
            }
        }
    }

    private static let storageKey = "hasCompletedTutorial"

    private(set) var isActive: Bool
    private(set) var step: Step = .welcome

    init(forceActive: Bool = false) {
        isActive = forceActive || !UserDefaults.standard.bool(forKey: Self.storageKey)
    }

    func advance() {
        guard let next = Step(rawValue: step.rawValue + 1) else {
            Analytics.log(.tutorialFinished(completed: true))
            finish()
            return
        }
        withAnimation(.easeInOut(duration: 0.3)) {
            step = next
        }
        // 어느 단계에서 사람들이 멈추는지 보려면 단계별 도달을 세야 한다.
        Analytics.log(.tutorialStepShown(step: String(describing: next)))
    }

    /// 시작 카드에서만 내민다 — 도중에 빠져나갈 문이 계속 보이면 어려워서가
    /// 아니라 그냥 눈에 띄어서 누르게 된다.
    func skipAll() {
        // 끝까지 간 것과 중간에 나간 것을 갈라야 튜토리얼이 어디서 버려지는지 보인다.
        Analytics.log(.tutorialFinished(completed: false))
        finish()
    }

    func finish() {
        dismissKeyboard()
        withAnimation(.easeInOut(duration: 0.3)) {
            isActive = false
        }
        UserDefaults.standard.set(true, forKey: Self.storageKey)
    }

    func restart() {
        UserDefaults.standard.set(false, forKey: Self.storageKey)
        step = .welcome
        withAnimation(.easeInOut(duration: 0.3)) {
            isActive = true
        }
    }

    private func dismissKeyboard() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil, from: nil, for: nil
        )
    }

    // MARK: - 실제 행동 감지

    func userDidSelectDate() {
        advanceIfWaiting(for: .selectDate)
    }

    /// 시간 추천 칩을 **실제로 눌렀을 때만** 넘어간다.
    ///
    /// 예전엔 "글자가 들어갔을 때", 그다음엔 "추천이 떴을 때" 넘겼는데 둘 다 일렀다 —
    /// "오후 3시"까지만 쳐도 추천은 뜨므로, "회의"를 치기도 전에 단계가 지나가
    /// 정작 칩을 눌러볼 수가 없었다. 쓰기와 칩 누르기를 한 단계로 합치고, 끝을
    /// 칩 탭 하나로 정한다.
    func userDidApplyTimeSuggestion() {
        advanceIfWaiting(for: .writeWithTime)
    }

    func userDidAddTodo() {
        guard isActive, step == .sendTodo else { return }
        // 다음은 목록을 눌러야 하는데 키보드가 절반을 덮고 있으면 조명한 자리가
        // 안 보인다.
        dismissKeyboard()
        advance()
    }

    /// 안내 단계의 '다음' 버튼.
    func userDidAcknowledgeHint() {
        guard isActive, step.isHint else { return }
        advance()
    }

    func userDidCompleteTodo() {
        advanceIfWaiting(for: .completeTodo)
    }

    /// 꾹 눌러 연 메뉴에서 디데이를 켰을 때.
    ///
    /// "메뉴가 열렸는가"가 아니라 **결과**를 본다. contextMenu는 열렸다는 걸
    /// 알려주지 않아서 길게 누르기를 따로 듣게 했었는데, 그 제스처가 메뉴를
    /// 여는 UIKit 인터랙션과 부딪혀 메뉴 자체가 안 열렸다. 모델이 바뀌는 걸
    /// 보면 부딪힐 것이 없고, 별이 붙는 눈에 보이는 결과로 단계가 끝난다.
    func userDidMarkDDay() {
        advanceIfWaiting(for: .longPressTodo)
    }

    func userDidDeleteTodo() {
        advanceIfWaiting(for: .deleteTodo)
    }

    func userDidSwipeWeek() {
        advanceIfWaiting(for: .swipeWeek)
    }

    private func advanceIfWaiting(for expected: Step) {
        guard isActive, step == expected else { return }
        advance()
    }
}

/// 어떤 손짓이 필요한지 — 오버레이가 이걸 보고 화살표/원을 그린다.
enum TutorialGestureHint {
    case tap
    case swipeHorizontal
    case swipeLeft
    case longPress
    /// 조작 없이 "여기를 보세요"만 가리킨다.
    case pointAt
}
