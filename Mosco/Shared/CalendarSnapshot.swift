import Foundation

/// 캘린더가 그릴 모든 것을 담은 **불변** 스냅샷. 뷰는 이걸 읽기만 하고 아무것도
/// 계산하지 않는다.
///
/// `==`가 `version`만 보는 게 핵심이다. 달을 넘기는 동안 페이지마다 이 비교가
/// 도는데, 딕셔너리를 통째로 비교하면 일정 수에 비례하는 비용(O(N))이 그대로
/// 프레임 예산을 먹는다. 스냅샷은 통째로 교체될 때만 새 버전을 받으므로 정수
/// 하나면 충분하다.
nonisolated struct CalendarSnapshot: Equatable, Sendable {
    let version: Int
    /// 계산해둔 범위 안의 달들. 범위 밖 달은 키가 없다(= 일정 없음으로 그린다).
    let months: [CalendarMonth: MonthEventLayout]

    static let empty = CalendarSnapshot(version: 0, months: [:])

    static func == (lhs: CalendarSnapshot, rhs: CalendarSnapshot) -> Bool {
        lhs.version == rhs.version
    }

    func layout(for month: CalendarMonth) -> MonthEventLayout {
        months[month] ?? .empty
    }
}

/// 할 일 목록 → 스냅샷. 순수 함수라 메인 스레드 밖에서 돈다.
///
/// 이 파일이 `Shared`에 있는 건 **위젯도 같은 막대 배치를 써야** 하기 때문이다.
/// 위젯이 자기만의 계산을 들고 있으면, 같은 달을 앱과 위젯이 서로 다른 줄에
/// 그리게 된다(특히 겹치는 일정의 행 배정과 다일 일정의 이어짐 처리).
nonisolated enum CalendarSnapshotBuilder {
    /// 계산해둘 범위의 반경(개월). 페이저는 훨씬 넓은 범위를 넘길 수 있지만,
    /// 무한한 반복을 미리 다 펼칠 수는 없으니 보고 있는 달 주변만 계산하고
    /// 가장자리에 가까워지면 다시 잡는다(`CalendarSnapshotStore.focus`).
    static let windowRadius = 8

    static func build(
        todos: [TodoSnapshot],
        center: CalendarMonth,
        version: Int,
        calendar: Calendar = .current
    ) -> CalendarSnapshot {
        let first = center.advanced(by: -windowRadius)
        let last = center.advanced(by: windowRadius)
        let window = DateInterval(
            start: first.startDate(calendar: calendar),
            end: last.endDate(calendar: calendar)
        )

        let events = CalendarEventExpander.expand(todos: todos, in: window, calendar: calendar)
        let positioned = EventRowAssigner.assign(events)

        var months: [CalendarMonth: MonthEventLayout] = [:]
        months.reserveCapacity(windowRadius * 2 + 1)
        for offset in -windowRadius...windowRadius {
            let month = center.advanced(by: offset)
            // 격자는 여기서 지역적으로 만든다 — 메인 스레드의 MonthGridCache를
            // 백그라운드에서 건드리지 않으려는 것이다.
            let grid = MonthLayout.make(month, calendar: calendar)
            months[month] = layout(for: grid, positioned: positioned)
        }

        return CalendarSnapshot(version: version, months: months)
    }

    /// 한 달만 필요한 곳(위젯)을 위한 진입점. 앱은 ±8개월을 미리 펼쳐두지만,
    /// 위젯은 한 번 그리고 죽으므로 격자에 실제로 보이는 범위만 펼친다.
    static func monthLayout(
        todos: [TodoSnapshot],
        month: CalendarMonth,
        calendar: Calendar = .current
    ) -> MonthEventLayout {
        let grid = MonthLayout.make(month, calendar: calendar)
        guard let first = grid.weeks.first?.dates.first,
              let last = grid.weeks.last?.dates.last,
              let end = calendar.date(byAdding: .day, value: 1, to: last)
        else { return .empty }

        let events = CalendarEventExpander.expand(
            todos: todos,
            in: DateInterval(start: first, end: end),
            calendar: calendar
        )
        return layout(for: grid, positioned: EventRowAssigner.assign(events))
    }

    /// 한 주만 필요한 곳(주간 위젯)을 위한 진입점. 격자가 아니라 독립된 한 줄이라
    /// 일곱 칸 모두를 "이번 달"로 취급한다 — 흐리게 낮출 바깥 날짜라는 개념이 없다.
    static func weekBars(
        todos: [TodoSnapshot],
        weekStart: Date,
        calendar: Calendar = .current
    ) -> WeekBars {
        let start = calendar.startOfDay(for: weekStart)
        let dates = (0..<7).map { calendar.date(byAdding: .day, value: $0, to: start) ?? start }
        guard let last = dates.last, let end = calendar.date(byAdding: .day, value: 1, to: last) else {
            return .empty
        }

        let events = CalendarEventExpander.expand(
            todos: todos,
            in: DateInterval(start: start, end: end),
            calendar: calendar
        )
        return bars(
            in: MonthLayout.WeekRow(dates: dates, inMonth: Array(repeating: true, count: 7)),
            positioned: EventRowAssigner.assign(events)
        )
    }

    /// 한 달 격자에 대해 주별 막대 자리를 확정한다.
    private static func layout(
        for grid: MonthLayout,
        positioned: [(event: CalendarEvent, row: Int)]
    ) -> MonthEventLayout {
        MonthEventLayout(weeks: grid.weeks.map { week in bars(in: week, positioned: positioned) })
    }

    private static func bars(
        in week: MonthLayout.WeekRow,
        positioned: [(event: CalendarEvent, row: Int)]
    ) -> WeekBars {
        guard let weekStart = week.dates.first, let weekEnd = week.dates.last else { return .empty }

        var raw: [BarSpec] = []
        for (event, globalRow) in positioned {
            guard event.start <= weekEnd, event.end >= weekStart else { continue }
            let overlapStart = max(event.start, weekStart)
            let overlapEnd = min(event.end, weekEnd)
            // 주의 날짜들은 연속된 startOfDay이고 이벤트도 startOfDay라 값이 정확히
            // 일치한다 — isDate(inSameDayAs:)를 부를 필요가 없다.
            guard
                let startColumn = week.dates.firstIndex(of: overlapStart),
                let endColumn = week.dates.firstIndex(of: overlapEnd)
            else { continue }

            raw.append(
                BarSpec(
                    id: event.id,
                    title: event.title,
                    categoryColorHex: event.categoryColorHex,
                    calendarColorHex: event.calendarColorHex,
                    isCompleted: event.isCompleted,
                    isRepeating: event.isRepeating,
                    row: globalRow,
                    startColumn: startColumn,
                    endColumn: endColumn,
                    continuesBefore: event.start < weekStart,
                    continuesAfter: event.end > weekEnd,
                    // 이번 달 칸에 한 칸이라도 걸쳐 있으면 진하게 — 달 경계를 넘는
                    // 일정이 중간에 톤이 바뀌며 잘려 보이지 않게 한다.
                    isDimmed: !(startColumn...endColumn).contains { week.inMonth[$0] }
                )
            )
        }

        guard !raw.isEmpty else { return .empty }

        // 전역 행 번호는 순서 유지용으로만 쓰고, 이 주 안에서는 실제로 쓰는 행만
        // 0부터 촘촘하게 다시 매긴다 — 안 그러면 다른 주에서 깊은 행을 차지한 긴
        // 반복 일정 때문에, 이 주는 보이지도 않는 행들 자리까지 예약해서 세로로
        // 텅 빈 공간이 생긴다.
        let usedRows = Set(raw.map(\.row)).sorted()
        let rowMap = Dictionary(uniqueKeysWithValues: usedRows.enumerated().map { ($0.element, $0.offset) })

        let compacted = raw.map { spec in
            BarSpec(
                id: spec.id,
                title: spec.title,
                categoryColorHex: spec.categoryColorHex,
                calendarColorHex: spec.calendarColorHex,
                isCompleted: spec.isCompleted,
                isRepeating: spec.isRepeating,
                row: rowMap[spec.row] ?? spec.row,
                startColumn: spec.startColumn,
                endColumn: spec.endColumn,
                continuesBefore: spec.continuesBefore,
                continuesAfter: spec.continuesAfter,
                isDimmed: spec.isDimmed
            )
        }

        return WeekBars(bars: compacted, rowCount: usedRows.count)
    }
}
