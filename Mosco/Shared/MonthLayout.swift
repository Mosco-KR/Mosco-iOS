import Foundation

/// 한 달을 주 단위로 쪼갠 격자 구조. 달마다 값이 고정이라 한 번 만들면 계속 쓴다.
///
/// 예전엔 `MonthGridView.body`에서 매번 계산했다. 42칸마다 `date(byAdding:)`와
/// `isDate(equalTo:toGranularity:)`를 부르는데 — 특히 후자는 Calendar API 중
/// 느린 축이다 — 페이지 수만큼 곱해지면서 렌더 경로에 그대로 얹혔다.
///
/// 캐시는 `MonthGridCache`가 따로 들고 있다. 이 타입 자체는 순수 계산만 하므로
/// 스냅샷 빌더가 백그라운드에서 마음대로 불러도 안전하다.
nonisolated struct MonthLayout: Sendable {
    /// 항상 실제 날짜 7개(일~토)로 구성된 주 단위 행. 이번 달이 아닌 날짜는
    /// inMonth가 false라 흐리게 표시될 뿐, 블록 이어짐 계산에는 그대로 쓰인다.
    struct WeekRow: Sendable {
        let dates: [Date]
        let inMonth: [Bool]
    }

    let weeks: [WeekRow]

    static func make(_ month: CalendarMonth, calendar: Calendar = .current) -> MonthLayout {
        let monthStart = month.startDate(calendar: calendar)
        let monthEnd = month.endDate(calendar: calendar)
        guard let firstWeek = calendar.dateInterval(of: .weekOfYear, for: monthStart) else {
            return MonthLayout(weeks: [])
        }

        var weeks: [WeekRow] = []
        var weekStart = firstWeek.start

        while weekStart < monthEnd {
            var dates: [Date] = []
            var inMonth: [Bool] = []
            var current = weekStart
            for _ in 0..<7 {
                dates.append(current)
                // isDate(equalTo:toGranularity:)를 쓰지 않는다 — 이번 달 구간에
                // 들어있는지만 보면 되고, 그 비교가 훨씬 싸다.
                inMonth.append(current >= monthStart && current < monthEnd)
                current = calendar.date(byAdding: .day, value: 1, to: current) ?? current
            }
            weeks.append(WeekRow(dates: dates, inMonth: inMonth))
            weekStart = calendar.date(byAdding: .weekOfYear, value: 1, to: weekStart) ?? monthEnd
        }

        return MonthLayout(weeks: weeks)
    }
}

/// 렌더링(항상 메인 스레드)에서 쓰는 격자 캐시. 백그라운드 스냅샷 빌더는 이걸
/// 건드리지 않고 자기 지역 캐시를 쓴다 — 공유 가변 상태를 두지 않으려는 것이다.
@MainActor
enum MonthGridCache {
    /// 사용자가 훑는 범위는 뻔해서 굳이 비우지 않는다(달 하나가 42개 Date다).
    private static var cache: [CalendarMonth: MonthLayout] = [:]

    static func layout(for month: CalendarMonth, calendar: Calendar = .current) -> MonthLayout {
        if let cached = cache[month] { return cached }
        let layout = MonthLayout.make(month, calendar: calendar)
        cache[month] = layout
        return layout
    }
}
