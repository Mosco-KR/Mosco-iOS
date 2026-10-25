import Foundation
import Testing

/// 앱스토어 리뷰를 언제 부탁하나. 조건이 여럿 곱해지는 곳이라, 조건 하나를 바꾸면
/// 무엇이 달라지는지 여기서 보인다.
///
/// 시스템은 리뷰창을 1년에 3번까지만 띄운다. 그래서 **안 띄운 기회를 쓴 것으로
/// 적는 것**이 가장 비싼 실수다 — 1.3.1 전에는 깃발만 세우고 실제 요청이 나가기 전에
/// 그 버전의 기회와 90일을 적어버렸다. 1.5.3부터는 한 발 더 나가서, 요청을 냈어도
/// **창이 실제로 안 떴으면** 기회를 쓴 것으로 치지 않는다.
@MainActor
struct ReviewPromptTests {

    /// 테스트마다 새 저장소. 진짜 `UserDefaults.standard`를 건드리지 않는다.
    private let defaults: UserDefaults
    private var clock: Date

    init() {
        defaults = UserDefaults(suiteName: "ReviewPromptTests-\(UUID().uuidString)")!
        clock = Calendar.current.date(from: DateComponents(year: 2026, month: 9, day: 1, hour: 9))!
    }

    private func prompt(version: String = "1.5.3", at date: Date) -> ReviewPrompt {
        ReviewPrompt(defaults: defaults, currentVersion: version, now: { date })
    }

    private func days(_ n: Int, from date: Date) -> Date {
        Calendar.current.date(byAdding: .day, value: n, to: date)!
    }

    /// 첫날 실행 → 다음 날 다시 실행. 날짜 조건(쓴 날 2일)을 채운 상태.
    private func usedForTwoDays(version: String = "1.5.3") -> ReviewPrompt {
        prompt(version: version, at: clock).registerLaunch()
        let later = prompt(version: version, at: days(1, from: clock))
        later.registerLaunch()
        return later
    }

    private func complete(_ count: Int, on prompt: ReviewPrompt) {
        for _ in 0..<count { prompt.recordCompletion() }
    }

    // MARK: 문턱

    @Test("다음_날_다시_열고_완료_3개째에_묻는다")
    func 완료_세_개() {
        let p = usedForTwoDays()
        complete(2, on: p)
        #expect(!p.isPending)
        complete(1, on: p)
        #expect(p.isPending)
    }

    @Test("오늘_할_일을_다_끝낸_순간은_완료_1개면_묻는다")
    func 하루_다_끝냄() {
        let p = usedForTwoDays()
        p.recordDayCleared()
        #expect(!p.isPending, "아무것도 끝낸 적이 없으면 묻지 않는다")
        complete(1, on: p)
        p.recordDayCleared()
        #expect(p.isPending)
    }

    @Test("깐_첫날에는_완료가_많아도_묻지_않는다")
    func 첫날() {
        let p = prompt(at: clock)
        p.registerLaunch()
        complete(10, on: p)
        #expect(!p.isPending, "막 깔아본 사람에게 묻는 건 기회를 버리는 것이다")
    }

    @Test("시간만_흐르고_연_날이_하루뿐이면_묻지_않는다")
    func 쓴_날_하루() {
        prompt(at: clock).registerLaunch()
        let p = prompt(at: days(5, from: clock))  // 실행 기록 없이 5일 뒤
        complete(10, on: p)
        #expect(!p.isPending)
    }

    // MARK: 쓴 날 세기

    /// `registerLaunch`는 실행 때만이 아니라 **앱이 앞으로 나올 때마다** 불린다.
    /// iOS가 앱을 며칠씩 메모리에 들고 있어서, 실행 때만 세면 매일 여는 사람도
    /// 쓴 날이 하루에서 안 올라갔다. 여러 번 불러도 하루는 하루여야 한다.
    @Test("같은_날_여러_번_앞으로_나와도_쓴_날은_하루다")
    func 하루에_여러_번() {
        let first = prompt(at: clock)
        first.registerLaunch()
        first.registerLaunch()
        prompt(at: Calendar.current.date(byAdding: .hour, value: 6, to: clock)!).registerLaunch()
        complete(10, on: first)
        #expect(!first.isPending, "하루를 세 번 세서 문턱을 넘기면 안 된다")

        let nextDay = prompt(at: days(1, from: clock))
        nextDay.registerLaunch()
        nextDay.recordCompletion()
        #expect(nextDay.isPending, "다음 날 다시 열면 그때는 센다")
    }

    // MARK: 기회를 언제 쓴 것으로 치나

    @Test("깃발만_서고_요청이_안_나갔으면_기회를_쓴_것으로_치지_않는다")
    func 요청_전엔_안_쓴다() {
        let p = usedForTwoDays()
        complete(3, on: p)
        #expect(p.isPending)

        // 요청이 나가기 전에 앱이 종료됐다 — 깃발은 메모리에만 있으니 사라진다.
        let relaunched = prompt(at: days(1, from: clock))
        relaunched.recordCompletion()
        #expect(relaunched.isPending, "창은 한 번도 안 떴는데 이 버전에서 다시 못 묻는다")
    }

    @Test("창이_떴으면_같은_버전에서_다시_묻지_않는다")
    func 요청_뒤엔_안_묻는다() {
        let p = usedForTwoDays()
        complete(3, on: p)
        p.didRequest(outcome: .shown)
        #expect(!p.isPending)

        let later = prompt(at: days(200, from: clock))
        later.recordCompletion()
        #expect(!later.isPending)
    }

    @Test("새_버전이어도_창이_뜬_뒤_90일이_안_지났으면_묻지_않는다")
    func 구십일() {
        let p = usedForTwoDays(version: "1.5.3")
        complete(3, on: p)
        p.didRequest(outcome: .shown)

        let soon = prompt(version: "1.5.4", at: days(60, from: clock))
        soon.recordCompletion()
        #expect(!soon.isPending)

        let late = prompt(version: "1.5.4", at: days(100, from: clock))
        late.recordCompletion()
        #expect(late.isPending)
    }

    // MARK: 요청을 냈는데 창이 안 떴을 때

    /// 가장 비싼 실수가 여기 있었다. 시스템이 조용히 아무것도 안 띄웠는데 90일과
    /// 그 버전을 같이 태우면, 아무것도 보여주지 않고 그 사람을 분기째 잃는다.
    @Test("창이_안_떴으면_같은_버전에서도_다시_묻는다")
    func 안_뜨면_다시() {
        let p = usedForTwoDays(version: "1.5.3")
        complete(3, on: p)
        p.didRequest(outcome: .unseen)
        #expect(!p.isPending)

        let later = prompt(version: "1.5.3", at: days(10, from: clock))
        later.recordCompletion()
        #expect(later.isPending, "보여준 게 없으니 이 버전에서 한 번 더 물어볼 수 있다")
    }

    /// 그렇다고 다음 완료마다 다시 부를 일은 아니다 — 시스템이 누르고 있는 중이면
    /// 내일도 똑같이 안 뜬다.
    @Test("창이_안_떠도_일주일_안에는_다시_묻지_않는다")
    func 안_뜬_뒤_일주일() {
        let p = usedForTwoDays(version: "1.5.3")
        complete(3, on: p)
        p.didRequest(outcome: .unseen)

        let soon = prompt(version: "1.5.3", at: days(4, from: clock))
        soon.recordCompletion()
        #expect(!soon.isPending)
    }

    @Test("창이_안_떴으면_90일_간격도_새로_걸리지_않는다")
    func 안_뜨면_구십일도_없다() {
        let p = usedForTwoDays(version: "1.5.3")
        complete(3, on: p)
        p.didRequest(outcome: .unseen)

        let next = prompt(version: "1.5.4", at: days(8, from: clock))
        next.recordCompletion()
        #expect(next.isPending)
    }

    @Test("요청을_내기_직전에_깃발을_내려_두_번_내지_않는다")
    func 깃발_먼저_내린다() {
        let p = usedForTwoDays()
        complete(3, on: p)
        #expect(p.isPending)
        p.willRequest()
        #expect(!p.isPending, "떴는지 확인하는 사이에 다른 길이 또 내면 안 된다")
    }

    // MARK: 1.2.0에서 올라온 사람

    /// 1.4.0 전에는 깃발을 세우는 순간 기회를 쓴 것으로 적었다. 앱스토어에 그 코드로
    /// 나간 1.2.0이 돌던 8~9월 내내 요청은 0건이었으니, 그 자국은 **뜬 적 없는 창**의
    /// 자국이다. 들고 올라온 사람을 90일 동안 막아둘 이유가 없다.
    @Test("1_2_0에서_올라온_자국은_한_번_지운다")
    func 옛_자국_지우기() {
        defaults.set("1.2.0", forKey: "reviewPromptLastVersion")
        defaults.set(days(-5, from: clock), forKey: "reviewPromptLastDate")

        let p = usedForTwoDays(version: "1.5.3")
        complete(3, on: p)
        #expect(p.isPending, "본 적도 없는 창 때문에 막혀 있으면 안 된다")
    }

    /// 지우는 건 **한 번뿐**이다. 1.5.3에서 실제로 뜬 창의 자국까지 매번 지우면
    /// 90일 간격이 아무 의미가 없어진다.
    @Test("자국_지우기는_한_번만_돈다")
    func 옛_자국은_한_번만() {
        defaults.set("1.2.0", forKey: "reviewPromptLastVersion")
        defaults.set(days(-5, from: clock), forKey: "reviewPromptLastDate")

        let p = usedForTwoDays(version: "1.5.3")
        complete(3, on: p)
        p.didRequest(outcome: .shown)

        let later = prompt(version: "1.5.4", at: days(30, from: clock))
        later.registerLaunch()
        later.recordCompletion()
        #expect(!later.isPending, "이번 자국은 진짜 뜬 창의 것이라 지우면 안 된다")
    }
}

/// 창 목록의 변화로 "시스템 리뷰창이 떴나"를 어림하는 쪽.
///
/// 식별자는 **살아 있는 객체**에서 가져온다. 임시로 만든 객체에서 뽑으면 그 자리에
/// 다음 객체가 들어앉아 같은 식별자가 두 번 나올 수 있다.
@Suite("리뷰창이_떴는지_창_목록으로_보기")
struct ReviewPromptWindowsTests {
    private let windows = (0..<3).map { _ in NSObject() }
    private let newcomer = NSObject()

    private var existing: [(id: ObjectIdentifier, className: String)] {
        windows.map { (id: ObjectIdentifier($0), className: "UIWindow") }
    }

    @Test("새_창이_하나도_없으면_안_뜬_것이다")
    func 변화_없음() {
        let shown = ReviewPromptWindows.didPresentReviewWindow(
            before: Set(existing.map(\.id)),
            after: existing
        )
        #expect(!shown)
    }

    @Test("못_보던_창이_올라오면_뜬_것으로_본다")
    func 새_창() {
        let shown = ReviewPromptWindows.didPresentReviewWindow(
            before: Set(existing.map(\.id)),
            after: existing + [(id: ObjectIdentifier(newcomer), className: "UIWindow")]
        )
        #expect(shown)
    }

    /// 완료 직후에는 입력창이 다시 뜨면서 키보드 창이 같이 올라올 수 있다.
    /// 그걸 리뷰창으로 세면 안 떴는데 떴다고 적게 된다.
    @Test("키보드_창은_리뷰창으로_세지_않는다")
    func 키보드는_제외() {
        let shown = ReviewPromptWindows.didPresentReviewWindow(
            before: Set(existing.map(\.id)),
            after: existing + [(id: ObjectIdentifier(newcomer), className: "UIRemoteKeyboardWindow")]
        )
        #expect(!shown)
    }
}
