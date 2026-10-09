import Foundation
import Testing

/// 하루 요약 알림을 언제 몇 개 걸 것인가.
///
/// 알림은 **눈으로 확인하기 가장 비싼 기능**이다 — 시각을 기다려야 하고, 안 오는
/// 것과 안 걸린 것을 구분할 수 없다. 그래서 눈으로 볼 것을 줄이는 쪽이 특히
/// 값어치가 크다(`ReminderPlanTests`와 같은 이유).
@Suite("하루 요약 알림")
struct DailySummaryPlanTests {

    private let calendar = TestCalendar.korea
    private let evening = DateComponents(hour: 21, minute: 0)

    /// 2026-10-09 오전 10시 — 그날 저녁 9시가 아직 안 왔다.
    private var morning: Date {
        calendar.date(bySettingHour: 10, minute: 0, second: 0, of: day("2026-10-09"))!
    }

    private func todo(
        _ title: String,
        on date: String,
        end: String? = nil,
        repeats: RepeatRule = .none,
        completed: Bool = false,
        completedDayKeys: [String] = []
    ) -> TodoSnapshot {
        TodoSnapshot(
            title: title,
            start: day(date, calendar: calendar),
            end: day(end ?? date, calendar: calendar),
            repeatRule: repeats,
            completedDayKeys: completedDayKeys,
            isCompleted: completed
        )
    }

    private func plan(
        _ todos: [TodoSnapshot],
        backlog: Int = 0,
        now: Date? = nil
    ) -> [PlannedSummary] {
        DailySummaryPlan.make(
            from: todos,
            backlogCount: backlog,
            at: evening,
            now: now ?? morning,
            calendar: calendar
        )
    }

    // MARK: - 언제 거나

    @Test("오늘_저녁이_아직_안_왔으면_오늘_것부터_건다")
    func 오늘부터() throws {
        let planned = plan([todo("오늘 일", on: "2026-10-09")])
        let first = try #require(planned.first)

        #expect(calendar.component(.hour, from: first.fireDate) == 21)
        #expect(calendar.isDate(first.fireDate, inSameDayAs: day("2026-10-09", calendar: calendar)))
    }

    /// 이미 지난 시각은 시스템이 조용히 버린다. 걸어봐야 자리만 차지한다.
    @Test("오늘_저녁이_지났으면_오늘_것은_안_건다")
    func 저녁이_지남() throws {
        let 밤 = calendar.date(bySettingHour: 23, minute: 0, second: 0, of: day("2026-10-09"))!
        let planned = plan([todo("내일 일", on: "2026-10-10")], now: 밤)
        let first = try #require(planned.first)

        #expect(calendar.isDate(first.fireDate, inSameDayAs: day("2026-10-10", calendar: calendar)))
    }

    // MARK: - 무엇을 세나

    /// **셋을 함께 세는 것이 이 알림의 요점이다.** 시작 전 알림은 시간을 적은
    /// 할 일만 챙기고, 나머지 셋은 지금까지 알림을 한 번도 못 받았다.
    @Test("그날_할_일과_지난_일과_날짜_없는_일을_함께_센다")
    func 셋을_센다() throws {
        let planned = plan(
            [
                todo("오늘 일", on: "2026-10-09"),
                todo("지난 일", on: "2026-10-05")
            ],
            backlog: 2
        )
        let today = try #require(planned.first)

        #expect(today.remaining == 4, "오늘 1 + 지난 1 + 날짜 없음 2")
    }

    @Test("끝낸_일은_세지_않는다")
    func 완료는_빠진다() throws {
        let planned = plan([
            todo("끝냄", on: "2026-10-09", completed: true),
            todo("안 끝냄", on: "2026-10-09")
        ])

        #expect(try #require(planned.first).remaining == 1)
    }

    @Test("반복은_그날_회차가_안_끝났을_때만_센다")
    func 반복() throws {
        let 매일 = todo(
            "매일 운동",
            on: "2026-10-01",
            repeats: .daily,
            completedDayKeys: [day("2026-10-09", calendar: calendar).dayKey]
        )

        let planned = plan([매일])
        let first = try #require(planned.first)

        // 오늘 회차는 끝냈으니 오늘 요약은 아예 안 걸리고, 내일 것이 첫 줄이어야 한다.
        #expect(calendar.isDate(first.fireDate, inSameDayAs: day("2026-10-10", calendar: calendar)))
        #expect(first.remaining == 1, "내일 회차는 아직 안 끝났다")
    }

    // MARK: - 안 거는 경우

    /// 0개짜리 저녁 알림은 그 자체로 알림을 끄고 싶은 이유가 된다.
    @Test("남은_게_없으면_아예_안_건다")
    func 조용한_날() {
        #expect(plan([todo("끝냄", on: "2026-10-09", completed: true)]).isEmpty)
    }

    @Test("할_일이_하나도_없으면_아무것도_안_건다")
    func 텅_빈_경우() {
        #expect(plan([]).isEmpty)
    }

    // MARK: - 숫자를 아는 날과 모르는 날

    /// 로컬 알림은 내용을 예약할 때 정해야 한다. 먼 날의 개수는 맞을 가능성이 낮고,
    /// **틀린 숫자는 안 보여주는 것보다 나쁘다** — 한 번 틀리면 그다음부터 안 믿는다.
    @Test("오늘과_내일만_숫자를_싣고_그_뒤는_안_싣는다")
    func 숫자를_아는_날() {
        // 날짜 없는 할 일이 있으니 먼 날까지 걸린다.
        let planned = plan([todo("오늘 일", on: "2026-10-09")], backlog: 1)

        #expect(planned.count == DailySummaryPlan.horizonDays)
        #expect(planned.prefix(2).allSatisfy { $0.remaining != nil })
        #expect(planned.dropFirst(2).allSatisfy { $0.remaining == nil })
    }

    /// 지금 아무것도 안 밀려 있으면 일주일치 알림을 미리 깔아둘 이유가 없다.
    /// 앞으로의 일정은 그날이 오기 전에 앱을 열면 다시 계산된다.
    @Test("밀린_게_없으면_먼_날까지_걸지_않는다")
    func 먼_날은_조건부() {
        let planned = plan([todo("오늘 일", on: "2026-10-09")])

        #expect(planned.allSatisfy { $0.remaining != nil }, "숫자를 모르는 날은 걸리지 않아야 한다")
        #expect(planned.count <= DailySummaryPlan.countedDays)
    }

    // MARK: - 식별자

    /// 할 일별 알림과 섞이면 걷어낼 때 서로를 지운다.
    @Test("요약_식별자는_할_일_알림과_구분된다")
    func 식별자() {
        let planned = plan([todo("오늘 일", on: "2026-10-09")])

        #expect(planned.allSatisfy { DailySummaryPlan.isSummary(id: $0.id) })
        #expect(!DailySummaryPlan.isSummary(id: "\(UUID().uuidString)-12345"))
    }

    @Test("날마다_다른_식별자를_받는다")
    func 날마다_다름() {
        let planned = plan([todo("오늘 일", on: "2026-10-09")], backlog: 1)
        #expect(Set(planned.map(\.id)).count == planned.count)
    }

    // MARK: - 알림 예산

    /// 요약이 할 일별 알림에 밀리면, **알림이 하나도 없는 사람에게 아무것도 안 가는**
    /// 상황만 남는다 — 요약은 그런 사람을 위해 만든 것이다.
    @Test("요약과_할_일_알림을_합쳐도_iOS_한도_안이다")
    func 예산() {
        #expect(ReminderPlan.limit + DailySummaryPlan.horizonDays <= 64)
    }

    // MARK: - 설정

    @Test("처음_열면_켜져_있고_저녁_아홉_시다")
    func 기본값() {
        let defaults = UserDefaults(suiteName: "summary-test-\(UUID().uuidString)")!

        #expect(DailySummarySettings.isEnabled(in: defaults))
        #expect(DailySummarySettings.time(in: defaults).hour == 21)
        #expect(DailySummarySettings.time(in: defaults).minute == 0)
    }

    @Test("고른_시각이_저장되고_그대로_읽힌다")
    func 시각_저장() {
        let defaults = UserDefaults(suiteName: "summary-test-\(UUID().uuidString)")!

        DailySummarySettings.setTime(DateComponents(hour: 8, minute: 30), in: defaults)

        #expect(DailySummarySettings.time(in: defaults).hour == 8)
        #expect(DailySummarySettings.time(in: defaults).minute == 30)
    }
}
