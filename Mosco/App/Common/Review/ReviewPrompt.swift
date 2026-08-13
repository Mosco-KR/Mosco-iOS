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

    /// 처음 쓴 날로부터 이만큼은 지나야 묻는다. 막 깔아본 사람에게 묻는 건
    /// 답을 받는 게 아니라 기회를 버리는 것이다.
    private static let minimumDaysSinceFirstLaunch = 2
    /// 앱을 연 날이 이만큼은 돼야 한다. "설치 후 며칠"만 보면 깔아두고 안 쓴
    /// 사람도 시간만 흐르면 통과하는데, 그런 사람의 평가는 받아봐야 낮다.
    private static let minimumActiveDays = 2
    /// 완료한 할 일이 이만큼 쌓여야 한다 — 앱을 실제로 쓰고 있다는 최소한의 증거.
    private static let minimumCompletions = 5
    /// 오늘 할 일을 다 끝낸 순간은 더 좋은 자리라 문턱을 낮춘다.
    private static let minimumCompletionsWhenDayCleared = 3
    /// 한 번 물어본 뒤 다시 묻기까지. 시스템 한도(연 3회)보다 넉넉하게 잡는다.
    private static let minimumDaysBetweenPrompts = 90

    private enum Key {
        static let firstLaunch = "reviewPromptFirstLaunchDate"
        static let completions = "reviewPromptCompletionCount"
        static let lastVersion = "reviewPromptLastVersion"
        static let lastDate = "reviewPromptLastDate"
        static let activeDays = "reviewPromptActiveDayCount"
        static let lastActiveDay = "reviewPromptLastActiveDay"
    }

    private var defaults: UserDefaults { .standard }

    /// 실행할 때 한 번 부른다. 앱을 처음 연 날을 기록하고(이미 있으면 그대로),
    /// 오늘이 처음이면 "쓴 날" 수를 하나 올린다.
    func registerLaunch() {
        if defaults.object(forKey: Key.firstLaunch) == nil {
            defaults.set(Date.now, forKey: Key.firstLaunch)
        }

        let today = Calendar.current.startOfDay(for: .now)
        let lastActive = defaults.object(forKey: Key.lastActiveDay) as? Date
        guard lastActive.map({ Calendar.current.startOfDay(for: $0) }) != today else { return }
        defaults.set(today, forKey: Key.lastActiveDay)
        defaults.set(defaults.integer(forKey: Key.activeDays) + 1, forKey: Key.activeDays)
    }

    /// 할 일을 **완료**했을 때 부른다(해제는 세지 않는다).
    ///
    /// 판단과 기록을 한 번에 하는 게 중요하다. 여러 행이 거의 동시에 완료되면
    /// 각자 조건을 통과해 리뷰창을 두 번 예약하려 할 수 있는데, 여기서 바로
    /// 잠가버리면 그 창이 없다.
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

    /// 실제로 요청을 내보낸 뒤 `RootTabView`가 부른다.
    func consumePending() {
        isPending = false
    }

    private func askIfEligible(completionCount: Int, threshold: Int) {
        guard !isPending else { return }
        guard isEligible(completionCount: completionCount, threshold: threshold) else { return }
        markRequested()
        isPending = true
    }

    private func isEligible(completionCount: Int, threshold: Int) -> Bool {
        guard completionCount >= threshold else { return false }
        guard defaults.integer(forKey: Key.activeDays) >= Self.minimumActiveDays else { return false }

        guard let firstLaunch = defaults.object(forKey: Key.firstLaunch) as? Date,
              let daysSinceFirstLaunch = Calendar.current.dateComponents(
                  [.day], from: firstLaunch, to: .now
              ).day,
              daysSinceFirstLaunch >= Self.minimumDaysSinceFirstLaunch
        else { return false }

        // 같은 버전에서 두 번 묻지 않는다. 새 버전이 나오면 다시 물어볼 만하다 —
        // 그 사이 앱이 나아졌을 수 있으니 평가도 달라질 수 있다.
        if defaults.string(forKey: Key.lastVersion) == currentVersion { return false }

        if let lastDate = defaults.object(forKey: Key.lastDate) as? Date,
           let daysSinceLastPrompt = Calendar.current.dateComponents(
               [.day], from: lastDate, to: .now
           ).day,
           daysSinceLastPrompt < Self.minimumDaysBetweenPrompts {
            return false
        }

        return true
    }

    private func markRequested() {
        defaults.set(currentVersion, forKey: Key.lastVersion)
        defaults.set(Date.now, forKey: Key.lastDate)
    }

    private var currentVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
    }
}
