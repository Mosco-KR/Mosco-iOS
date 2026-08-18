import Foundation
import Testing

/// 날짜 경계 — `docs/harness/rules.md` R7 표의 첫 줄.
/// 월말/월초에 같은 날짜가 두 번 나오는 증상이 반복해서 돌아왔다.
@Suite("월 격자")
struct MonthLayoutTests {

    private let calendar = TestCalendar.korea

    private func layout(_ year: Int, _ month: Int) -> MonthLayout {
        MonthLayout.make(CalendarMonth(year: year, month: month), calendar: calendar)
    }

    private func allDates(_ layout: MonthLayout) -> [Date] {
        layout.weeks.flatMap(\.dates)
    }

    @Test("같은_날짜가_월말월초에_두_번_나오지_않는다", arguments: [
        (2026, 8), (2026, 2), (2026, 3), (2025, 12), (2026, 1), (2024, 2),
    ])
    func 날짜가_중복되지_않는다(year: Int, month: Int) {
        let dates = allDates(layout(year, month))
        let unique = Set(dates.map { label($0) })
        #expect(
            unique.count == dates.count,
            "\(year)-\(month) 격자에 같은 날짜가 두 번 있다: \(dates.map { label($0) })"
        )
    }

    @Test("격자는_빈틈없이_하루씩_이어진다", arguments: [
        (2026, 8), (2026, 2), (2025, 12), (2026, 5),
    ])
    func 날짜가_연속한다(year: Int, month: Int) {
        let dates = allDates(layout(year, month))
        for (previous, next) in zip(dates, dates.dropFirst()) {
            let gap = calendar.dateComponents([.day], from: previous, to: next).day
            #expect(gap == 1, "\(label(previous)) 다음이 \(label(next))다 — 하루가 아니다")
        }
    }

    @Test("모든_주는_일곱_칸이다", arguments: [(2026, 8), (2026, 2), (2025, 12)])
    func 주는_일곱_칸(year: Int, month: Int) {
        for week in layout(year, month).weeks {
            #expect(week.dates.count == 7)
            #expect(week.inMonth.count == 7)
        }
    }

    @Test("격자는_일요일에_시작한다", arguments: [(2026, 8), (2026, 2), (2025, 12)])
    func 일요일_시작(year: Int, month: Int) {
        for week in layout(year, month).weeks {
            let weekday = calendar.component(.weekday, from: week.dates[0])
            #expect(weekday == 1, "\(label(week.dates[0]))는 일요일이 아니다")
        }
    }

    @Test("그_달의_모든_날이_정확히_한_번씩_들어있다", arguments: [
        (2026, 8), (2026, 2), (2024, 2), (2025, 12),
    ])
    func 그_달이_다_들어있다(year: Int, month: Int) {
        let grid = layout(year, month)
        let inMonthDates = zip(grid.weeks.flatMap(\.dates), grid.weeks.flatMap(\.inMonth))
            .filter { $0.1 }
            .map { label($0.0) }

        let month = CalendarMonth(year: year, month: month)
        let expected = calendar.range(of: .day, in: .month, for: month.startDate(calendar: calendar))!
        #expect(inMonthDates.count == expected.count)
        #expect(Set(inMonthDates).count == expected.count, "그 달 날짜가 중복됐다")
    }

    @Test("이_달_바깥_날짜는_inMonth가_false다")
    func 바깥_날짜_표시() {
        let grid = layout(2026, 8)   // 2026-08-01은 토요일 → 앞에 7월 26~31이 붙는다
        let first = grid.weeks[0]
        #expect(first.inMonth[0] == false, "7월 26일이 8월로 잡혔다")
        #expect(label(first.dates[0]) == "2026-07-26")
        #expect(first.inMonth[6] == true, "8월 1일이 이 달 바깥으로 잡혔다")
        #expect(label(first.dates[6]) == "2026-08-01")
    }

    @Test("윤년_2월이_29일까지_들어간다")
    func 윤년() {
        let grid = layout(2024, 2)
        let inMonth = zip(grid.weeks.flatMap(\.dates), grid.weeks.flatMap(\.inMonth))
            .filter { $0.1 }.map { label($0.0) }
        #expect(inMonth.contains("2024-02-29"))
        #expect(inMonth.count == 29)
    }
}
