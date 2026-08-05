import Foundation

/// 할 일들을 주어진 기간 안의 캘린더 이벤트로 펼친다(원본 + 반복 인스턴스).
///
/// 예전엔 `CalendarScreen`의 computed property였다 — 즉 화면 body가 돌 때마다
/// 다시 펼쳤다. 이제는 순수 함수라서 데이터가 바뀔 때 백그라운드에서 한 번만
/// 돌고, 덤으로 단위 테스트가 가능해졌다.
nonisolated enum CalendarEventExpander {
    static func expand(
        todos: [TodoSnapshot],
        in window: DateInterval,
        calendar: Calendar
    ) -> [CalendarEvent] {
        todos.flatMap { events(for: $0, in: window, calendar: calendar) }
    }

    private static func events(
        for todo: TodoSnapshot,
        in window: DateInterval,
        calendar: Calendar
    ) -> [CalendarEvent] {
        var result = [
            CalendarEvent(
                id: "\(todo.id.uuidString)-base",
                title: todo.title,
                categoryColorHex: todo.categoryColorHex,
                calendarColorHex: todo.calendarColorHex,
                isRepeating: todo.repeatRule != .none,
                start: todo.start,
                end: todo.end,
                isCompleted: todo.isCompleted(on: todo.start, calendar: calendar),
                createdAt: todo.createdAt
            )
        ]

        guard todo.repeatRule != .none else { return result }

        let durationDays = todo.durationDays(calendar: calendar)

        // 계산 범위 앞쪽에서 시작해 범위 안으로 이어지는 반복도 잡히도록,
        // 일정 길이만큼 앞당긴 지점부터 훑는다.
        let scanStart = max(
            calendar.date(byAdding: .day, value: 1, to: todo.start) ?? todo.start,
            calendar.date(byAdding: .day, value: -durationDays, to: window.start) ?? window.start
        )

        for cursor in candidates(for: todo, from: scanStart, until: window.end, calendar: calendar) {
            guard todo.isRepeatStart(cursor, calendar: calendar) else { continue }
            let end = calendar.date(byAdding: .day, value: durationDays, to: cursor) ?? cursor
            result.append(
                CalendarEvent(
                    id: "\(todo.id.uuidString)-\(cursor.dayKey)",
                    title: todo.title,
                    categoryColorHex: todo.categoryColorHex,
                    calendarColorHex: todo.calendarColorHex,
                    isRepeating: true,
                    start: cursor,
                    end: end,
                    // 반복은 날짜별로 완료 상태가 다르다 — 그 인스턴스의 기록만 본다.
                    isCompleted: todo.completedDayKeys.contains(cursor.dayKey),
                    createdAt: todo.createdAt
                )
            )
        }
        return result
    }

    /// 반복 규칙별로 "확인해볼 만한 날짜"만 추린다. 최종 판정은 여전히
    /// `isRepeatStart`가 하므로(반복 종료일·요일 조건 등) 여기서는 실제 반복일을
    /// 빠짐없이 포함하는 후보만 내면 되고, 하루씩 전부 훑지만 않으면 된다.
    ///
    /// 예전엔 하루씩 커서를 옮기며 매번 `isRepeatStart`를 물었다 — 반복 일정 하나당
    /// 기간 일수만큼 캘린더 날짜 연산이 돌았다. 규칙이 이미 주기를 알고 있으므로
    /// 그만큼 건너뛰면 후보 자체가 크게 준다.
    ///
    /// 주기의 기준점은 반드시 **원본 시작일**이다. 스캔 시작점부터 주기만큼
    /// 건너뛰면 위상이 어긋나서(예: 매월 15일 반복인데 1일부터 한 달씩 더하면
    /// 영영 15일에 안 닿는다) 반복이 통째로 사라진다.
    private static func candidates(
        for todo: TodoSnapshot,
        from start: Date,
        until end: Date,
        calendar: Calendar
    ) -> [Date] {
        let base = todo.start

        switch todo.repeatRule {
        case .none:
            return []

        case .daily:
            return stride(from: max(base, start), to: end, by: 1, calendar: calendar)

        case .everyNDays:
            let interval = max(todo.repeatInterval ?? 2, 1)
            // base + k*interval 중 start 이후 첫 지점을 구해 위상을 맞춘다.
            let elapsed = calendar.dateComponents([.day], from: base, to: start).day ?? 0
            let steps = max(Int(ceil(Double(elapsed) / Double(interval))), 0)
            let first = calendar.date(byAdding: .day, value: steps * interval, to: base) ?? start
            return stride(from: first, to: end, by: interval, calendar: calendar)

        case .weekly:
            // 요일을 여러 개 고를 수 있으면 주 안의 날짜를 다 봐야 한다.
            // 안 골랐으면 원본과 같은 요일만.
            guard todo.repeatWeekdays.isEmpty else {
                return stride(from: max(base, start), to: end, by: 1, calendar: calendar)
            }
            let weekdayOffset = ((calendar.dateComponents([.day], from: base, to: start).day ?? 0) % 7 + 7) % 7
            let aligned = calendar.date(
                byAdding: .day,
                value: weekdayOffset == 0 ? 0 : 7 - weekdayOffset,
                to: start
            ) ?? start
            return stride(from: max(base, aligned), to: end, by: 7, calendar: calendar)

        case .monthly, .yearly:
            // 달마다 날짜 수가 달라(31일 반복 등) 단순 덧셈으로는 어긋난다.
            // 시스템의 날짜 매칭에 맡기고, 없는 날짜(2월 31일)는 건너뛴다.
            let units: Set<Calendar.Component> = todo.repeatRule == .monthly ? [.day] : [.month, .day]
            var result: [Date] = []
            calendar.enumerateDates(
                startingAfter: max(base, calendar.date(byAdding: .day, value: -1, to: start) ?? start),
                matching: calendar.dateComponents(units, from: base),
                matchingPolicy: .strict
            ) { date, _, stop in
                guard let date, date < end else {
                    stop = true
                    return
                }
                result.append(calendar.startOfDay(for: date))
            }
            return result
        }
    }

    /// startOfDay 정렬을 유지하면서 일 단위로 건너뛴 날짜 목록.
    private static func stride(from start: Date, to end: Date, by days: Int, calendar: Calendar) -> [Date] {
        var result: [Date] = []
        var cursor = calendar.startOfDay(for: start)
        while cursor < end {
            result.append(cursor)
            guard let next = calendar.date(byAdding: .day, value: days, to: cursor) else { break }
            cursor = next
        }
        return result
    }
}
