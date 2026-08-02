import Foundation
import SwiftUI

/// 앱을 처음 켰을 때 한 번, 실제 화면 위에서 핵심 기능을 체험시키는 참여형
/// 튜토리얼의 상태 머신. 기능을 훑어보는 단계는 언제든 건너뛸 수 있지만, 이
/// 앱의 뼈대인 "날짜를 골라 할 일을 만들고, 시간을 자동으로 인식시키고, 다시
/// 지워보는" 네 가지 핵심 동작만큼은 실제로 해봐야 다음으로 넘어간다 — 버튼
/// 하나로 넘기게 하면 이 앱이 뭘 하는 앱인지 모른 채 시작하게 된다.
@Observable
final class TutorialManager {
    enum Step: Int, CaseIterable {
        case welcome
        case selectDate
        case timeDetection
        case addTodo
        case deleteTodo
        case autoCategory
        case manualCategory
        case scheduleDetail
        case completeTodo
        case weekStrip
        case calendarSwitcher
        case todoTab
        case todayPlanning
        case upcomingTab
        case help
        case finish

        /// 이 단계는 실제로 해내야만 다음으로 넘어간다 — 건너뛰기 버튼 자체가 없다.
        var isEssential: Bool {
            switch self {
            case .selectDate, .timeDetection, .addTodo, .deleteTodo: true
            default: false
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
            finish()
            return
        }
        withAnimation(.easeInOut(duration: 0.25)) {
            step = next
        }
    }

    /// 건너뛰기 가능한 단계에서만 호출된다(필수 단계는 버튼이 안 보이니 여기까지
    /// 안 온다) — 남은 안내를 전부 건너뛰고 튜토리얼을 종료한다.
    func skipAll() {
        finish()
    }

    func finish() {
        withAnimation(.easeInOut(duration: 0.3)) {
            isActive = false
        }
        UserDefaults.standard.set(true, forKey: Self.storageKey)
    }

    /// 설정 등에서 다시 보고 싶을 때를 위한 재시작 훅.
    func restart() {
        UserDefaults.standard.set(false, forKey: Self.storageKey)
        step = .welcome
        withAnimation(.easeInOut(duration: 0.3)) {
            isActive = true
        }
    }

    // MARK: - 실제 행동 감지

    /// CalendarScreen에서 날짜를 실제로 선택하면 호출된다.
    func userDidSelectDate() {
        guard isActive, step == .selectDate else { return }
        advance()
    }

    /// QuickAddView에서 실제로 새 할 일을 저장하면 호출된다(수정 모드는 제외).
    func userDidAddTodo() {
        guard isActive, step == .addTodo else { return }
        advance()
    }

    /// QuickAddView에서 시간 추천 칩을 실제로 탭해 적용하면 호출된다.
    func userDidApplyTimeSuggestion() {
        guard isActive, step == .timeDetection else { return }
        advance()
    }

    /// 할 일을 실제로 삭제하면 호출된다.
    func userDidDeleteTodo() {
        guard isActive, step == .deleteTodo else { return }
        advance()
    }
}
