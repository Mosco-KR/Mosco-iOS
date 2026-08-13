import Foundation
import Observation
import SwiftUI

extension Optional where Wrapped == TutorialCoordinator {
    /// 튜토리얼이 없을 수도 있는 자리(옵셔널 환경 값)에서 지금 단계를 꺼낸다.
    /// 옵셔널 체이닝을 그대로 쓰면 이중 옵셔널이 되어 `switch`가 지저분해진다.
    @MainActor
    var currentStep: TutorialStep? { self?.step ?? nil }
}

/// 튜토리얼의 진행을 혼자 들고 있는 곳. 화면들은 **자기가 한 일을 알리기만** 하고,
/// 다음에 무엇을 보여줄지는 전부 여기서 정한다.
///
/// **원칙 셋.**
/// 1. 사용자가 실제로 그 행동을 해야 다음으로 간다 — 읽고 넘기는 안내가 아니라
///    한 번 해본 것이 남아야 손이 기억한다.
/// 2. 되돌아갈 수 있어야 한다 — 시간 칩을 지우면 그 단계로 되돌아가고, 하루
///    페이지에서 뒤로 나가면 그 앞 단계로 되돌아간다. 못 따라가면 멈추는 게 아니라
///    되돌아가야 길을 잃지 않는다.
/// 3. **막다른 길이 없어야 한다** — 한 단계에 오래 머물면 대신 해주겠다는 링크가
///    나온다(`assist`). 한 걸음 막힌 것 때문에 나머지를 통째로 잃지 않게.
@MainActor
@Observable
final class TutorialCoordinator {
    /// **하나만 있어야 한다.** 안내는 앱 창 위에 얹힌 별도의 창에서 그려지는데
    /// (`TutorialOverlayWindow`), 그 창과 앱 화면이 서로 다른 진행 상태를 보고 있으면
    /// 스포트라이트가 엉뚱한 데를 겨눈다. 잠금화면 컨트롤러가 같은 이유로 공유본이다.
    static let shared = TutorialCoordinator()

    private init() {}

    // MARK: - 상태

    /// nil이면 튜토리얼이 돌고 있지 않다. 이 값 하나가 오버레이의 유무를 정한다.
    private(set) var step: TutorialStep?
    /// 튜토리얼 중에 사용자가 직접 만든 연습용 할 일. 스포트라이트가 겨눌 줄을
    /// 정확히 하나로 좁히는 열쇠라, 목록에 다른 할 일이 아무리 많아도 헷갈리지 않는다.
    private(set) var practiceTodoID: UUID?
    /// 화면들이 재어 올린 스포트라이트 대상의 자리(전역 좌표).
    private(set) var frames: [TutorialTargetID: CGRect] = [:]
    /// 이 단계에 오래 머물러 있다 — 도움 링크는 이때만 나온다.
    private(set) var isStuck = false
    /// 연습용 할 일을 대신 만들어달라는 요청(카운터). `RootTabView`가 받는다.
    private(set) var practiceTodoRequest = 0
    /// 하루 페이지를 대신 열어달라는 요청(카운터). `CalendarScreen`이 받는다.
    private(set) var openDayRequest = 0
    /// 안내 카드(말풍선)가 차지한 자리. 마스크를 안 씌우는 단계에서 **이 자리만**
    /// 터치를 받게 하려고 창이 참조한다.
    private(set) var guidanceFrame: CGRect = .zero

    var isRunning: Bool { step != nil }

    /// 튜토리얼이 도는 동안에는 셀을 꾹 눌러도 메뉴가 안 뜬다 — 시스템 메뉴는
    /// 마스크 위로 떠서 화면을 통째로 덮기 때문에, 지금 따라가야 할 지시가 가려진다.
    /// 정리(`cleanUp`) 단계에서만 연다. 그 단계는 그 메뉴를 여는 것이 곧 과제다.
    var suppressesRowMenu: Bool {
        guard let step else { return false }
        return step != .cleanUp
    }

    /// 목록/달력의 스크롤을 잠글지. 겨누고 있는 자리가 손가락에 밀려 화면 밖으로
    /// 나가버리면, 사용자는 어두운 화면만 보고 무엇을 눌러야 할지 알 수 없게 된다.
    var locksScroll: Bool { isRunning }

    private var stuckTask: Task<Void, Never>?
    private var pendingTask: Task<Void, Never>?
    private var defaults: UserDefaults { .standard }

    private enum Key {
        /// 시작 카드에 답을 한 적이 있는지(했다 / 나중에 볼래요 둘 다 포함).
        static let answered = "tutorialAnswered"
        /// 끝까지 본 적이 있는지.
        static let completed = "tutorialCompleted"
    }

    /// 한 단계에 이만큼 머물면 도움 링크를 내민다. 더 짧으면 읽는 중에 튀어나와
    /// 재촉하는 것처럼 읽히고, 더 길면 이미 포기한 뒤에 도착한다.
    private static let stuckSeconds: Double = 12

    // MARK: - 시작과 끝

    /// 앱을 처음 켠 사람에게만 시작 카드를 띄운다.
    ///
    /// **이미 할 일이 있는 사람에게는 띄우지 않는다.** 기기를 바꿔 iCloud에서
    /// 데이터가 내려온 경우가 그렇다 — 쓰던 사람에게 "처음 오셨네요"는 틀린 인사다.
    ///
    /// 곧 띄울 참이면 true를 돌려준다 — 호출부는 그동안 시스템 권한창을 띄우지
    /// 않고 기다린다(첫 화면에서 결정을 두 개 요구하지 않으려는 것이다).
    @discardableResult
    func startIfFirstLaunch(hasExistingData: Bool) -> Bool {
        guard !defaults.bool(forKey: Key.answered) else { return false }
        guard !hasExistingData else {
            // 물어본 셈 치고 다시 묻지 않는다. 설정에 언제나 열려 있다.
            defaults.set(true, forKey: Key.answered)
            return false
        }
        pendingTask?.cancel()
        pendingTask = Task { [weak self] in
            // 첫 화면이 다 그려진 뒤에 얹는다 — 뜨자마자 덮치면 앱을 아직 보지도
            // 못한 채로 결정을 요구하는 셈이 된다.
            try? await Task.sleep(for: .seconds(0.7))
            guard !Task.isCancelled else { return }
            self?.present(.welcome, source: "first_launch")
        }
        return true
    }

    /// 설정에서 직접 불렀을 때. 이미 하겠다고 고른 셈이라 시작 카드는 건너뛴다.
    func startFromSettings() {
        present(.typeTitle, source: "settings")
    }

    private func present(_ step: TutorialStep, source: String) {
        guard self.step == nil else { return }
        practiceTodoID = nil
        frames = [:]
        Analytics.log(.tutorialStarted(source: source))
        move(to: step)
    }

    /// 시작 카드에서 "해볼게요".
    func accept() {
        guard step == .welcome else { return }
        defaults.set(true, forKey: Key.answered)
        move(to: .typeTitle)
    }

    /// 시작 카드에서 "혼자 둘러볼게요", 또는 진행 중 "건너뛰기".
    ///
    /// **확인을 한 번 더 묻지 않는다.** 그만두겠다는 사람을 붙잡는 창은 다음 화면을
    /// 하나 더 만드는 것이지 마음을 돌리는 것이 아니다.
    func skip() {
        defaults.set(true, forKey: Key.answered)
        Analytics.log(.tutorialSkipped(step: String(describing: step ?? .welcome)))
        close()
    }

    /// 끝맺음 카드에서 "시작하기".
    func finish() {
        defaults.set(true, forKey: Key.answered)
        defaults.set(true, forKey: Key.completed)
        Analytics.log(.tutorialFinished)
        close()
    }

    private func close() {
        stuckTask?.cancel()
        pendingTask?.cancel()
        step = nil
        practiceTodoID = nil
        frames = [:]
        guidanceFrame = .zero
        isStuck = false
        TutorialOverlayWindow.shared.setVisible(false)
    }

    // MARK: - 단계 이동

    private func move(to next: TutorialStep) {
        guard step != next else { return }
        // **앞으로 갈 때만 "해냈다"로 센다.** 되돌아가는 이동(적었던 시간을 지웠거나,
        // 하루 페이지에서 뒤로 나갔거나)까지 세면 완료율이 실제보다 부풀어서,
        // 어느 단계에서 막히는지를 보려던 지표가 그 답을 못 하게 된다.
        if let step, step != .welcome, next.rawValue > step.rawValue {
            Analytics.log(.tutorialStepCompleted(step: String(describing: step)))
        }
        withAnimation(.easeInOut(duration: 0.28)) {
            step = next
        }
        // 창은 첫 단계에서 한 번 올라오고, 끝날 때 `close`가 내린다.
        TutorialOverlayWindow.shared.setVisible(true)
        restartStuckTimer()
    }

    /// 지금 화면이 바뀌는 중이라 잠깐 기다렸다 옮기는 경우(페이지 밀려 들어오기,
    /// 줄이 사라지는 애니메이션). 눈에 보이는 변화가 끝난 뒤에 말을 걸어야 읽힌다.
    private func move(to next: TutorialStep, after seconds: Double) {
        pendingTask?.cancel()
        pendingTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(seconds))
            guard !Task.isCancelled else { return }
            self?.move(to: next)
        }
    }

    private func restartStuckTimer() {
        stuckTask?.cancel()
        isStuck = false
        guard step?.assistLabel != nil else { return }
        stuckTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(Self.stuckSeconds))
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.2)) {
                self?.isStuck = true
            }
        }
    }

    /// 도움 링크를 눌렀을 때. 단계마다 "대신 해주기"의 뜻이 다르다.
    func assist() {
        guard let step else { return }
        Analytics.log(.tutorialAssisted(step: String(describing: step)))
        switch step {
        case .typeTitle, .pickTime, .send:
            // 대신 만들어준다. 만들어진 결과는 `didCreateTodo`로 다시 들어온다.
            practiceTodoRequest += 1
        case .complete:
            move(to: .openDay)
        case .openDay:
            openDayRequest += 1
        case .cleanUp:
            move(to: .finish)
        case .welcome, .finish:
            break
        }
    }

    // MARK: - 화면이 알려오는 것들

    /// 입력창에 제목이 남아 있는지. 시간만 적고 칩을 눌러 확정하면(예: "7시")
    /// 제목이 비어서 보내기 버튼이 잠긴다 — 그때 "버튼을 누르세요"라고 계속 말하면
    /// 누를 수 없는 것을 누르라고 시키는 셈이라, 할 말을 바꾼다.
    private(set) var composeHasTitle = false

    func noteComposeTitle(isEmpty: Bool) {
        let hasTitle = !isEmpty
        guard composeHasTitle != hasTitle else { return }
        composeHasTitle = hasTitle
    }

    /// 입력창에서 시간 표현이 인식됐거나(칩이 떴거나) 사라졌다.
    func noteTimeSuggestion(isVisible: Bool) {
        switch step {
        case .typeTitle where isVisible: move(to: .pickTime)
        // 적었던 시간을 지운 경우 — 앞 단계로 되돌아가야 지시와 화면이 어긋나지 않는다.
        case .pickTime where !isVisible: move(to: .typeTitle)
        default: break
        }
    }

    /// 시간 칩을 눌러 확정했다.
    func didApplyTimeSuggestion() {
        guard step == .pickTime else { return }
        move(to: .send)
    }

    /// 할 일이 새로 만들어졌다.
    ///
    /// 시간 칩을 안 거치고 바로 보내버린 경우까지 받아준다 — 순서를 안 지켰다고
    /// 멈춰 세우면, 방금 자기 손으로 만든 할 일을 앱이 못 본 척하는 셈이 된다.
    func didCreateTodo(_ todo: TodoItem) {
        switch step {
        case .typeTitle, .pickTime, .send:
            practiceTodoID = todo.id
            move(to: .complete)
        default:
            break
        }
    }

    /// 할 일의 완료 상태가 바뀌었다.
    func didToggleCompletion(id: UUID, completed: Bool) {
        guard step == .complete, id == practiceTodoID, completed else { return }
        move(to: .openDay)
    }

    /// 달력에서 하루 페이지를 열었다.
    func didOpenDay(_ date: Date) {
        guard step == .openDay else { return }
        guard Calendar.current.isDateInToday(date) else { return }
        // 페이지가 밀려 들어오는 동안 말을 걸면 글자가 화면과 함께 미끄러진다.
        move(to: .cleanUp, after: 0.5)
    }

    /// 하루 페이지에서 뒤로 나갔다. 정리 단계는 그 페이지 위에서만 성립하므로
    /// 달력 단계로 되돌린다 — 없는 줄을 가리키고 있는 것보다 낫다.
    func didCloseDay() {
        guard step == .cleanUp else { return }
        pendingTask?.cancel()
        move(to: .openDay)
    }

    /// 할 일이 지워졌다.
    func didDelete(ids: [UUID]) {
        guard step == .cleanUp, let practiceTodoID, ids.contains(practiceTodoID) else { return }
        self.practiceTodoID = nil
        // 줄이 사라지는 것을 눈으로 본 다음에 끝맺음이 와야 "정리됐다"로 읽힌다.
        move(to: .finish, after: 0.4)
    }

    // MARK: - 스포트라이트

    /// 지금 단계가 겨누는 자리들. 둘 이상이면 그 둘을 함께 감싸는 구멍이 된다.
    var spotlightTargets: [TutorialTargetID] {
        guard let step else { return [] }
        switch step {
        case .welcome, .finish:
            return []
        // 시간 칩은 입력창에 얹힌 오버레이라 따로 재지 않는다 — 입력창 위쪽을
        // 넉넉히 열어두면(`holeInsets`) 칩이 그 안에 들어온다. 입력창 자체도 계속
        // 열려 있어야 잘못 적은 것을 지우고 다시 적을 수 있다.
        case .typeTitle, .pickTime, .send:
            return [.composeBar]
        case .complete:
            return practiceTodoID.map { [.todayRow($0)] } ?? []
        case .openDay:
            return [.todayCell]
        case .cleanUp:
            return practiceTodoID.map { [.dayRow($0)] } ?? []
        }
    }

    /// 이 자리를 지금 재야 하는가. **겨누는 자리 하나만 잰다** — 목록의 모든 줄이
    /// 늘 자기 좌표를 올려보내면 그 비용이 평소 스크롤에까지 얹힌다.
    func needsFrame(for id: TutorialTargetID) -> Bool {
        spotlightTargets.contains(id)
    }

    func reportGuidanceFrame(_ frame: CGRect) {
        guard guidanceFrame != frame else { return }
        guidanceFrame = frame
    }

    func report(_ frame: CGRect, for id: TutorialTargetID) {
        guard frames[id] != frame else { return }
        frames[id] = frame
    }

    func clearFrame(for id: TutorialTargetID) {
        frames.removeValue(forKey: id)
    }

    /// 뚫을 구멍. 아직 자리를 못 받았으면 nil이고, 그때 오버레이는 구멍 없이
    /// 안내만 띄운다(화면이 바뀌는 짧은 사이에 실제로 그렇다).
    func spotlightRect() -> CGRect? {
        guard let step else { return nil }
        let rects = spotlightTargets.compactMap { frames[$0] }
        guard let first = rects.first else { return nil }
        let union = rects.dropFirst().reduce(first) { $0.union($1) }
        guard union.width > 1, union.height > 1 else { return nil }

        let insets = step.holeInsets
        return CGRect(
            x: union.minX - insets.leading,
            y: union.minY - insets.top,
            width: union.width + insets.leading + insets.trailing,
            height: union.height + insets.top + insets.bottom
        )
    }
}
