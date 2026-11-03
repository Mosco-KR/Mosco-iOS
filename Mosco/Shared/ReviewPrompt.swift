import Foundation
import Observation

/// 앱스토어 리뷰를 언제 부탁할지 정한다.
///
/// **시스템이 1년에 최대 3번만 실제로 띄운다.** 그래서 "언제 부르는가"가 코드보다
/// 중요하다 — 아무 때나 부르면 시스템이 무시해버리고, 정작 부탁하기 좋은 순간이
/// 왔을 때 쓸 기회가 남아있지 않다.
///
/// 다만 조건이 너무 빡빡하면 반대쪽 실패가 난다. **한 번도 안 뜨는 것**이다.
/// 예전 조건(완료 10개 + 설치 후 3일 + 요청 간격 120일)은 서로 곱해져서, 실제로
/// 통과하는 사람이 거의 없었다. 지금은 문턱을 낮추고, 대신 **부탁하기 좋은 순간을
/// 하나 더** 만들었다 — 오늘 할 일을 다 끝낸 순간이다. 그건 완료 하나보다 훨씬
/// 분명한 성취라 문턱도 더 낮게 잡는다.
///
/// **요청을 내는 자리도 옮겼다.** 예전엔 할 일 셀(`TodoRow`)이 직접 `requestReview`를
/// 불렀는데, 셀은 완료 직후 목록에서 걸러져 사라질 수 있는 뷰다 — 1.2초 뒤 화면에
/// 없는 뷰가 시트를 띄우려 하는 셈이었다. 지금은 이 타입이 "부탁할 때가 됐다"는
/// 깃발만 세우고, 앱이 살아있는 한 항상 떠 있는 `RootTabView`가 실제 요청을 낸다.
///
/// **기회를 썼다고 적는 건 실제로 요청을 낸 뒤다**(`didRequest`). 1.3.1 전에는 깃발을
/// 세우는 순간 적었는데, 깃발은 메모리에만 있어서 요청이 나가기 전에 앱이 종료되면
/// 창은 한 번도 안 떴는데 그 버전의 기회와 90일이 같이 날아갔다.
///
/// **1.4.0 다음에 문턱을 한 번 더 낮췄다.** 2026년 9월 한 달 동안 `review_prompt_requested`가
/// 한 건도 없었다. 설치 후 2일 · 쓴 날 2일 · 완료 5개를 다 채우는 사람이 없었던 것이다 —
/// 다섯 중 넷이 첫날로 끝나는 앱에서 그 조건은 사실상 "묻지 않는다"였다. 같은 달 숫자를
/// 보면 **다음 날 다시 연 사람은 대체로 남았다.** 그래서 지금은 "둘째 날에 다시 열었다"를
/// 좋게 쓰고 있다는 증거로 삼고, 그날 완료 3개(오늘을 다 끝냈으면 1개)면 묻는다.
/// 첫날에는 여전히 묻지 않는다. **그 문턱은 지금 맞다** — 2026-10-25에 콘솔을 보니
/// 28일 동안 할 일을 완료한 44명 중 10명(23%)에게 요청이 나갔다. 더 낮출 이유가 없다.
///
/// **1.5.3에서 "요청을 냈다"와 "창이 떴다"를 갈랐다.** 이게 지금 이 파일에서 가장 중요한
/// 구분이다. `requestReview()`는 조건이 안 맞으면 **아무 말 없이 아무것도 안 한다** —
/// 연 3회를 이미 썼거나, 시스템이 자기 사정으로 누르고 있거나, 앱이 그 순간 창을 올릴
/// 상태가 아니거나. 10월에 요청 11건이 나갔는데 평점은 한 개도 안 늘었다. 그런데 그게
/// "떴는데 다 닫았다"인지 "한 번도 안 떴다"인지 알 길이 없었다. 둘은 고칠 곳이 완전히
/// 다르다. 지금은 `ReviewPromptWindows`가 창이 올라왔는지 보고, **안 떴으면 기회를
/// 쓴 것으로 치지 않는다** — 버전 자국도 남기지 않고, 짧은 간격만 두고 다시 묻는다.
/// 안 뜬 요청에 90일을 태우는 것은 아무것도 보여주지 않고 사람 하나를 분기째 잃는 일이다.
///
/// `Shared/`에 두는 건 조건들을 테스트로 덮기 위해서다(`ReviewPromptTests`) —
/// 저장소·버전·시각을 밖에서 넣을 수 있다.
@Observable
@MainActor
final class ReviewPrompt {
    /// 지금 리뷰창을 띄워야 하는지. `RootTabView`가 이것만 지켜보고 있다.
    private(set) var isPending = false

    /// 앱스토어의 리뷰 작성 화면. 설정의 '앱 평가하기'가 여기로 보낸다.
    ///
    /// **시스템 리뷰창과 나눠 맡는다.** 시스템 창은 연 3회 한도가 있고 실제로
    /// 떴는지도 알 수 없는 반면, 이 링크는 한도를 쓰지 않고 누른 것도 확실히 안다 —
    /// 대신 스스로 설정까지 찾아온 사람에게만 닿는다. 둘 중 하나만 두면 각각의
    /// 약점이 그대로 구멍이 된다.
    static let writeReviewURL = URL(
        string: "https://apps.apple.com/app/id6796924940?action=write-review"
    )!

    /// 앱을 연 날이 이만큼은 돼야 한다. 막 깔아본 사람에게 묻는 건 답을 받는 게
    /// 아니라 기회를 버리는 것이라 첫날은 뺀다. "설치 후 며칠"로 세지 않는 건, 그러면
    /// 깔아두고 안 쓴 사람도 시간만 흐르면 통과하기 때문이다.
    private static let minimumActiveDays = 2
    /// 완료한 할 일이 이만큼 쌓여야 한다 — 앱을 실제로 쓰고 있다는 최소한의 증거.
    /// 안내에서 연습으로 끝낸 하나도 여기 들어간다.
    private static let minimumCompletions = 3
    /// 오늘 할 일을 다 끝낸 순간은 더 좋은 자리라 문턱을 낮춘다.
    private static let minimumCompletionsWhenDayCleared = 1
    /// 창이 **실제로 뜬** 뒤 다시 묻기까지. 시스템 한도(연 3회)보다 넉넉하게 잡는다.
    private static let minimumDaysBetweenPrompts = 90
    /// 요청을 냈는데 **창이 안 뜬** 뒤 다시 묻기까지. 보여준 게 없으니 90일을 태울
    /// 이유가 없다. 그렇다고 다음 완료마다 다시 부르는 것도 의미가 없다 — 시스템이
    /// 누르고 있는 중이면 내일도 똑같이 안 뜬다. 일주일이면 사정이 달라질 만하다.
    private static let minimumDaysAfterUnseen = 7

    private enum Key {
        static let completions = "reviewPromptCompletionCount"
        static let lastVersion = "reviewPromptLastVersion"
        static let lastDate = "reviewPromptLastDate"
        static let activeDays = "reviewPromptActiveDayCount"
        static let lastActiveDay = "reviewPromptLastActiveDay"
        static let lastUnseenDate = "reviewPromptLastUnseenDate"
        static let legacyBurnCleared = "reviewPromptLegacyBurnCleared"
    }

    /// 창이 떴는지 안 떴는지. 이 둘에 따라 다음에 다시 묻기까지가 달라진다.
    enum Outcome {
        case shown
        case unseen
    }

    private let defaults: UserDefaults
    private let currentVersion: String
    private let now: () -> Date

    init(
        defaults: UserDefaults = .standard,
        currentVersion: String = Bundle.main.object(
            forInfoDictionaryKey: "CFBundleShortVersionString"
        ) as? String ?? "?",
        now: @escaping () -> Date = { .now }
    ) {
        self.defaults = defaults
        self.currentVersion = currentVersion
        self.now = now
    }

    /// 앱이 앞으로 나올 때마다 부른다. 오늘 처음 연 것이면 "쓴 날" 수를 하나 올린다.
    ///
    /// **실행 때 한 번이 아니라 앞으로 나올 때마다인 것이 중요하다.** 예전엔
    /// `RootTabView`의 시작 작업에서만 불렀는데, 그건 프로세스가 새로 뜰 때만 돈다.
    /// iOS는 앱을 며칠씩 메모리에 들고 있어서, 매일 여는 사람도 "쓴 날"이 하루에서
    /// 안 올라갈 수 있었다 — 둘째 날에 묻겠다는 조건이 셋째 날에도 안 차는 것이다.
    func registerLaunch() {
        clearLegacyBurnIfNeeded()

        let today = Calendar.current.startOfDay(for: now())
        let lastActive = defaults.object(forKey: Key.lastActiveDay) as? Date
        guard lastActive.map({ Calendar.current.startOfDay(for: $0) }) != today else { return }
        defaults.set(today, forKey: Key.lastActiveDay)
        defaults.set(defaults.integer(forKey: Key.activeDays) + 1, forKey: Key.activeDays)
    }

    /// 할 일을 **완료**했을 때 부른다(해제는 세지 않는다).
    ///
    /// 여러 행이 거의 동시에 완료되면 각자 조건을 통과해 리뷰창을 두 번 예약하려 할
    /// 수 있다. 깃발이 서 있는 동안은 다시 세우지 않으므로 그 창이 없다.
    func recordCompletion() {
        let count = defaults.integer(forKey: Key.completions) + 1
        defaults.set(count, forKey: Key.completions)
        askIfEligible(completionCount: count, threshold: Self.minimumCompletions)
    }

    /// 오늘 할 일을 **전부** 끝낸 순간에 부른다. 완료 하나보다 분명한 성취라,
    /// 같은 조건을 낮은 문턱으로 다시 본다 — 완료 개수가 모자라 방금 놓친
    /// 경우라도 이 순간에는 물어볼 만하다.
    func recordDayCleared() {
        askIfEligible(
            completionCount: defaults.integer(forKey: Key.completions),
            threshold: Self.minimumCompletionsWhenDayCleared
        )
    }

    /// 요청을 내보내기 **직전**에 부른다. 깃발을 먼저 내려서, 떴는지를 확인하는
    /// 사이에 다른 길(앞으로 나오기)이 같은 요청을 한 번 더 내는 것을 막는다.
    func willRequest() {
        isPending = false
    }

    /// 실제로 요청을 내보낸 뒤 `RootTabView`가 부른다. **여기서 기회를 쓴 것으로 적는다** —
    /// 단, 창이 실제로 떴을 때만 그렇다. 안 떴으면 보여준 게 없으니 짧은 간격만 둔다.
    func didRequest(outcome: Outcome) {
        isPending = false
        switch outcome {
        case .shown:
            defaults.set(currentVersion, forKey: Key.lastVersion)
            defaults.set(now(), forKey: Key.lastDate)
        case .unseen:
            defaults.set(now(), forKey: Key.lastUnseenDate)
        }
    }

    private func askIfEligible(completionCount: Int, threshold: Int) {
        guard !isPending else { return }
        guard isEligible(completionCount: completionCount, threshold: threshold) else { return }
        isPending = true
    }

    private func isEligible(completionCount: Int, threshold: Int) -> Bool {
        guard completionCount >= threshold else { return false }
        guard defaults.integer(forKey: Key.activeDays) >= Self.minimumActiveDays else { return false }

        // 같은 버전에서 두 번 묻지 않는다. 새 버전이 나오면 다시 물어볼 만하다 —
        // 그 사이 앱이 나아졌을 수 있으니 평가도 달라질 수 있다. **창이 뜬 적이
        // 있을 때만 적히는 자국이다** — 안 뜬 요청은 여기 아무것도 남기지 않는다.
        if defaults.string(forKey: Key.lastVersion) == currentVersion { return false }

        if daysSince(Key.lastDate).map({ $0 < Self.minimumDaysBetweenPrompts }) == true {
            return false
        }
        if daysSince(Key.lastUnseenDate).map({ $0 < Self.minimumDaysAfterUnseen }) == true {
            return false
        }

        return true
    }

    private func daysSince(_ key: String) -> Int? {
        guard let date = defaults.object(forKey: key) as? Date else { return nil }
        return Calendar.current.dateComponents([.day], from: date, to: now()).day
    }

    /// 1.4.0 **전**에는 깃발을 세우는 순간 기회를 쓴 것으로 적었다. 앱스토어에 그 코드로
    /// 나간 것은 1.2.0 하나뿐인데, 그 버전이 돌던 8~9월 내내 `review_prompt_requested`는
    /// 0건이었다 — 창은 아무에게도 안 떴다는 뜻이다. 그런데 그때 적힌 자국을 들고
    /// 올라온 사람은 **본 적도 없는 창 때문에** 90일 동안 막혀 있다. 한 번만 지운다.
    private func clearLegacyBurnIfNeeded() {
        guard !defaults.bool(forKey: Key.legacyBurnCleared) else { return }
        defaults.set(true, forKey: Key.legacyBurnCleared)

        guard let last = defaults.string(forKey: Key.lastVersion),
              last.compare("1.4.0", options: .numeric) == .orderedAscending
        else { return }
        defaults.removeObject(forKey: Key.lastVersion)
        defaults.removeObject(forKey: Key.lastDate)
    }
}
