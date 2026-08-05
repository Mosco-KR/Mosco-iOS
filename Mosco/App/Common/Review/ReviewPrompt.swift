import Foundation

/// 앱스토어 리뷰를 언제 부탁할지 정한다.
///
/// **시스템이 1년에 최대 3번만 실제로 띄운다.** 그래서 "언제 부르는가"가 코드보다
/// 중요하다 — 아무 때나 부르면 시스템이 무시해버리고, 정작 부탁하기 좋은 순간이
/// 왔을 때 쓸 기회가 남아있지 않다. 그래서 여기 조건은 일부러 빡빡하다.
///
/// 부탁하는 시점은 **할 일을 완료한 직후**다. 앱이 사용자에게 뭔가를 해준 순간이라
/// 기분이 좋을 때고, 화면 전환도 없어서 흐름을 끊지 않는다. 반대로 앱을 켜자마자,
/// 온보딩 중에, 뭔가 실패한 뒤에는 절대 묻지 않는다.
@MainActor
enum ReviewPrompt {
    /// 처음 쓴 날로부터 이만큼은 지나야 묻는다. 막 깔아본 사람에게 묻는 건
    /// 답을 받는 게 아니라 기회를 버리는 것이다.
    private static let minimumDaysSinceFirstLaunch = 3
    /// 완료한 할 일이 이만큼 쌓여야 한다 — 앱을 실제로 쓰고 있다는 최소한의 증거.
    private static let minimumCompletions = 10
    /// 한 번 물어본 뒤 다시 묻기까지. 시스템 한도(연 3회)보다 넉넉하게 잡는다.
    private static let minimumDaysBetweenPrompts = 120

    private enum Key {
        static let firstLaunch = "reviewPromptFirstLaunchDate"
        static let completions = "reviewPromptCompletionCount"
        static let lastVersion = "reviewPromptLastVersion"
        static let lastDate = "reviewPromptLastDate"
    }

    private static var defaults: UserDefaults { .standard }

    /// 앱을 처음 연 날을 기록해둔다(이미 있으면 그대로). 실행할 때 한 번 부른다.
    static func registerLaunch() {
        guard defaults.object(forKey: Key.firstLaunch) == nil else { return }
        defaults.set(Date.now, forKey: Key.firstLaunch)
    }

    /// 할 일을 **완료**했을 때 부른다(해제는 세지 않는다).
    /// 지금 물어봐도 되면 true를 돌려주고, 그 즉시 "물어봤다"고 기록한다.
    ///
    /// 판단과 기록을 한 번에 하는 게 중요하다. 여러 행이 거의 동시에 완료되면
    /// 각자 조건을 통과해 리뷰창을 두 번 띄우려 할 수 있는데, 여기서 바로
    /// 잠가버리면 그 창이 없다.
    static func recordCompletionAndAsk() -> Bool {
        let count = defaults.integer(forKey: Key.completions) + 1
        defaults.set(count, forKey: Key.completions)

        guard isEligible(completionCount: count) else { return false }
        markRequested()
        return true
    }

    private static func isEligible(completionCount: Int) -> Bool {
        guard completionCount >= minimumCompletions else { return false }

        guard let firstLaunch = defaults.object(forKey: Key.firstLaunch) as? Date,
              let daysSinceFirstLaunch = Calendar.current.dateComponents(
                  [.day], from: firstLaunch, to: .now
              ).day,
              daysSinceFirstLaunch >= minimumDaysSinceFirstLaunch
        else { return false }

        // 같은 버전에서 두 번 묻지 않는다. 새 버전이 나오면 다시 물어볼 만하다 —
        // 그 사이 앱이 나아졌을 수 있으니 평가도 달라질 수 있다.
        if defaults.string(forKey: Key.lastVersion) == currentVersion { return false }

        if let lastDate = defaults.object(forKey: Key.lastDate) as? Date,
           let daysSinceLastPrompt = Calendar.current.dateComponents(
               [.day], from: lastDate, to: .now
           ).day,
           daysSinceLastPrompt < minimumDaysBetweenPrompts {
            return false
        }

        return true
    }

    private static func markRequested() {
        defaults.set(currentVersion, forKey: Key.lastVersion)
        defaults.set(Date.now, forKey: Key.lastDate)
    }

    private static var currentVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
    }
}
