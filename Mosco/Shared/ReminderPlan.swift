import Foundation

/// 알림 하나를 걸기 위해 필요한 것 전부.
///
/// 문구를 만드는 일은 들어 있지 않다 — 번역 카탈로그와 사용자 언어는 화면의
/// 사정이고, 여기서 정하는 것은 "언제, 무엇을, 몇 개"뿐이다.
nonisolated struct PlannedReminder: Equatable, Sendable {
    /// 알림 요청 식별자. **같은 할 일의 다른 날 인스턴스가 서로 덮어쓰지 않도록
    /// 날짜까지 넣는다.** 반복 일정은 저장소에 복제본이 없어서 id가 하나뿐이다.
    let id: String
    let todoID: UUID
    let title: String
    /// 알림이 울릴 시각 = 그 인스턴스의 시작 시각 - 리드타임.
    let fireDate: Date
    /// 그 인스턴스가 실제로 시작하는 시각. 문구에 쓴다("오후 7시에 시작해요").
    let startDate: Date
    /// 시작 몇 분 전인지. 0이면 시작하는 순간이다.
    let leadMinutes: Int
}

/// 알림 예약의 입력 한 줄 — "이 할 일을, 시작 몇 분 전에".
///
/// **`TodoSnapshot`을 그대로 재사용한다.** 반복 전개와 완료 판정이 이미 거기 있고
/// 테스트로 덮여 있다. 알림용으로 한 벌 더 쓰면 달력과 알림이 서로 다른 날짜를
/// 반복일로 보는 날이 온다 — 그 어긋남은 사용자 쪽에서 "어떤 반복은 알림이 안 와요"로만
/// 보여서 찾기가 몹시 어렵다.
nonisolated struct ReminderSource: Equatable, Sendable {
    let todo: TodoSnapshot
    let leadMinutes: Int

    init(todo: TodoSnapshot, leadMinutes: Int) {
        self.todo = todo
        self.leadMinutes = leadMinutes
    }

    /// 저장소의 할 일에서 베껴온다. 알림을 받을 이유가 없는 것은 nil —
    /// 카테고리 알림이 꺼져 있거나, 시작 시각이 없거나, 날짜가 없는(백로그) 것.
    @MainActor
    init?(_ todo: TodoItem, calendar: Calendar = .current) {
        guard let category = todo.category, category.notifiesBeforeStart else { return nil }
        guard let snapshot = TodoSnapshot(todo, calendar: calendar) else { return nil }
        self.todo = snapshot
        self.leadMinutes = category.notificationLeadMinutes
    }
}

/// 지금 이후로 어떤 알림을 몇 개 걸어야 하는가. **순수 계산이다** — 시스템
/// 알림 센터를 모르고, 그래서 테스트로 덮을 수 있다.
///
/// 이 로직이 `App/`의 스케줄러 안에 있던 동안에는 테스트가 한 건도 없었다.
/// 알림은 눈으로 확인하기도 가장 비싼 기능이다(시각을 기다려야 한다) —
/// 그래서 눈으로 볼 것을 줄이는 쪽이 이 기능에서 특히 값어치가 크다.
nonisolated enum ReminderPlan {
    /// 반복 일정을 며칠치까지 펼칠지. 더 길게 잡아도 아래 개수 제한에 걸려 잘린다.
    static let horizonDays = 60
    /// iOS가 앱당 허용하는 대기 중 로컬 알림은 64개다. 그 안에서 **가까운 것부터**
    /// 채우고, 나머지는 다음 실행 때 다시 계산되며 자연히 채워진다.
    static let limit = 60

    static func make(
        from sources: [ReminderSource],
        now: Date,
        calendar: Calendar = .current,
        horizonDays: Int = horizonDays,
        limit: Int = limit
    ) -> [PlannedReminder] {
        guard limit > 0, let horizon = calendar.date(byAdding: .day, value: horizonDays, to: now) else { return [] }

        var planned: [PlannedReminder] = []
        for source in sources {
            // 시간을 안 정한 할 일에는 알릴 시점이 없다. `-1`은 "시각 없음"이다
            // (`TodoItem.sortableMinutes`와 같은 약속).
            guard source.todo.startMinutes >= 0 else { continue }

            for occurrence in occurrences(of: source.todo, from: now, to: horizon, calendar: calendar) {
                // **분을 더하지 않고 시·분을 박는다.** 하루에 분을 더하면 서머타임이
                // 있는 지역에서 한 시간 밀린다 — 사용자가 적은 것은 벽시계 시각이다.
                guard let start = calendar.date(
                    bySettingHour: source.todo.startMinutes / 60,
                    minute: source.todo.startMinutes % 60,
                    second: 0,
                    of: occurrence
                ) else { continue }
                guard let fire = calendar.date(byAdding: .minute, value: -source.leadMinutes, to: start) else { continue }
                // 이미 지난 시각은 예약할 수 없다(시스템이 조용히 버린다).
                guard fire > now else { continue }
                // 이미 끝낸 인스턴스는 알릴 이유가 없다.
                guard !source.todo.isCompleted(on: occurrence, calendar: calendar) else { continue }

                planned.append(
                    PlannedReminder(
                        id: "\(source.todo.id.uuidString)-\(occurrence.dayKey)",
                        todoID: source.todo.id,
                        title: source.todo.title,
                        fireDate: fire,
                        startDate: start,
                        leadMinutes: source.leadMinutes
                    )
                )
            }
        }

        // 가까운 것부터. 같은 시각이면 식별자로 가른다 — 순서가 실행마다 달라지면
        // 제한에 걸려 잘리는 쪽도 달라져서, 같은 데이터로 다른 결과가 나온다.
        return Array(
            planned
                .sorted { $0.fireDate == $1.fireDate ? $0.id < $1.id : $0.fireDate < $1.fireDate }
                .prefix(limit)
        )
    }

    /// 기간 안에서 이 할 일이 **시작하는** 날들 — 원본 시작일과 반복 인스턴스.
    ///
    /// 여러 날에 걸친 일정은 시작하는 날에만 알린다. 걸친 날마다 알리면 "3일간
    /// 여행" 같은 항목이 사흘 내내 같은 시각에 울린다.
    static func occurrences(
        of todo: TodoSnapshot,
        from start: Date,
        to end: Date,
        calendar: Calendar
    ) -> [Date] {
        let windowStart = calendar.startOfDay(for: start)
        let windowEnd = calendar.startOfDay(for: end)
        guard windowStart <= windowEnd else { return [] }

        var result: [Date] = []
        // **원본 시작일도 창 안에 있어야 넣는다.** 예전에는 위쪽 경계를 안 봐서,
        // 60일 창 밖에서 시작하는 반복 일정이 100일 뒤 알림으로 자리를 하나
        // 차지했다 — 그만큼 가까운 알림이 밀려났다.
        if todo.start >= windowStart, todo.start <= windowEnd { result.append(todo.start) }

        guard todo.repeatRule != .none else { return result }

        // `isRepeatStart`는 원본 시작일 자신에 대해 false다(`dayStart > start`).
        // 그래서 위에서 넣은 것과 겹치지 않는다.
        var cursor = max(windowStart, todo.start)
        while cursor <= windowEnd {
            if todo.isRepeatStart(cursor, calendar: calendar) { result.append(cursor) }
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }
        return result
    }
}
