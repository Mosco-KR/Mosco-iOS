import Foundation
import Testing

/// 앱스토어 리뷰를 언제 부탁하나. 조건이 여럿 곱해지는 곳이라, 조건 하나를 바꾸면
/// 무엇이 달라지는지 여기서 보인다.
///
/// 시스템은 리뷰창을 1년에 3번까지만 띄운다. 그래서 **안 띄운 기회를 쓴 것으로
/// 적는 것**이 가장 비싼 실수다 — 1.3.1 전에는 깃발만 세우고 실제 요청이 나가기 전에
/// 그 버전의 기회와 90일을 적어버렸다.
@MainActor
struct ReviewPromptTests {

    /// 테스트마다 새 저장소. 진짜 `UserDefaults.standard`를 건드리지 않는다.
    private let defaults: UserDefaults
    private var clock: Date

    init() {
        defaults = UserDefaults(suiteName: "ReviewPromptTests-\(UUID().uuidString)")!
        clock = Calendar.current.date(from: DateComponents(year: 2026, month: 9, day: 1, hour: 9))!
    }

    private func prompt(version: String = "1.3.1", at date: Date) -> ReviewPrompt {
        ReviewPrompt(defaults: defaults, currentVersion: version, now: { date })
    }

    private func days(_ n: Int, from date: Date) -> Date {
        Calendar.current.date(byAdding: .day, value: n, to: date)!
    }

    /// 첫날 실행 → n일 뒤 다시 실행. 날짜 조건(설치 후 2일 · 쓴 날 2일)을 채운 상태.
    private func usedForTwoDays(version: String = "1.3.1") -> ReviewPrompt {
        prompt(version: version, at: clock).registerLaunch()
        let later = prompt(version: version, at: days(3, from: clock))
        later.registerLaunch()
        return later
    }

    private func complete(_ count: Int, on prompt: ReviewPrompt) {
        for _ in 0..<count { prompt.recordCompletion() }
    }

    // MARK: 문턱

    @Test("완료_5개째에_묻는다")
    func 완료_다섯_개() {
        let p = usedForTwoDays()
        complete(4, on: p)
        #expect(!p.isPending)
        complete(1, on: p)
        #expect(p.isPending)
    }

    @Test("오늘_할_일을_다_끝낸_순간은_완료_3개면_묻는다")
    func 하루_다_끝냄() {
        let p = usedForTwoDays()
        complete(2, on: p)
        p.recordDayCleared()
        #expect(!p.isPending)
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

    // MARK: 기회를 언제 쓴 것으로 치나

    @Test("깃발만_서고_요청이_안_나갔으면_기회를_쓴_것으로_치지_않는다")
    func 요청_전엔_안_쓴다() {
        let p = usedForTwoDays()
        complete(5, on: p)
        #expect(p.isPending)

        // 요청이 나가기 전에 앱이 종료됐다 — 깃발은 메모리에만 있으니 사라진다.
        let relaunched = prompt(at: days(3, from: clock))
        relaunched.recordCompletion()
        #expect(relaunched.isPending, "창은 한 번도 안 떴는데 이 버전에서 다시 못 묻는다")
    }

    @Test("요청을_내보낸_뒤에는_같은_버전에서_다시_묻지_않는다")
    func 요청_뒤엔_안_묻는다() {
        let p = usedForTwoDays()
        complete(5, on: p)
        p.didRequest()
        #expect(!p.isPending)

        let later = prompt(at: days(200, from: clock))
        later.recordCompletion()
        #expect(!later.isPending)
    }

    @Test("새_버전이어도_마지막_요청에서_90일이_안_지났으면_묻지_않는다")
    func 구십일() {
        let p = usedForTwoDays(version: "1.3.1")
        complete(5, on: p)
        p.didRequest()

        let soon = prompt(version: "1.4.0", at: days(60, from: clock))
        soon.recordCompletion()
        #expect(!soon.isPending)

        let late = prompt(version: "1.4.0", at: days(100, from: clock))
        late.recordCompletion()
        #expect(late.isPending)
    }
}
