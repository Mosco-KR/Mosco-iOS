import Foundation

/// '할 일' 탭이 무엇을 어느 묶음에 넣는가.
///
/// ## 왜 날짜가 아니라 급한 순서인가
///
/// 달력은 이미 "언제"에 답한다. 탭을 하나 더 두는 이유는 **"무엇부터"**에 답하기
/// 위해서다. 그래서 월·화·수로 줄 세우지 않고 지난 것 → 오늘 → 이번 주 → 나중 →
/// 날짜 없음으로 묶는다. 위에서부터 읽으면 그게 곧 할 순서다.
///
/// ## 디데이는 맨 위 카드다
///
/// 디데이가 답하는 것은 "며칠 남았나" 하나다. 그걸 목록 안에서 말하려고 두 번
/// 시도했고 둘 다 되돌렸다 — 행에 `D-7` 조각을 붙이면 태그 줄이 길어지고,
/// '나중' 칸에서 디데이를 맨 위로 끌어올리면 날짜순이 깨져 목록을 읽는 리듬이
/// 끊긴다. 남은 날을 세는 일은 **목록 바깥**, 맨 위 카드에 맡긴다(`dDays`).
///
/// ## 왜 화면이 아니라 여기 있나
///
/// 어느 할 일이 어디에 들어가는지는 눈으로 확인하기 가장 비싼 종류의 규칙이다 —
/// 반복·여러 날짜리·완료가 다 얽힌다. 화면 구조체 안에 두면 테스트를 한 줄도
/// 쓸 수 없다(`TodayPage`와 같은 이유).
nonisolated enum TodoListPage {

    /// 묶음. 순서가 곧 화면에 쌓이는 순서다.
    ///
    /// **먼저 '손이 가야 하는 것' 둘, 그다음 시간순.** 지난 할 일과 날짜를 안 정한
    /// 할 일은 둘 다 "언제 할지 아직 안 정해진 것"이라 사람이 손을 대야 움직인다.
    /// 그 둘을 위에 두고, 이미 날짜가 정해진 것들은 시간순으로 뒤따른다.
    enum Section: String, CaseIterable, Sendable {
        /// 날짜가 지났는데 안 끝낸 것.
        case overdue
        /// 날짜를 안 정한 것.
        case noDate
        /// 오늘 걸치는 것(반복 포함).
        case today
        /// 내일부터 이레 안.
        case thisWeek
        /// 그 뒤.
        case later
    }

    /// '이번 주'가 며칠까지인가. 내일부터 이레 — "이번 주"라는 말이 달력의 주(週)가
    /// 아니라 **앞으로 한 주**를 뜻한다. 수요일에 열었는데 이틀치만 보이면
    /// 그 묶음은 쓸모가 없다.
    static let weekHorizonDays = 7

    /// 반복 일정의 다음 회차를 며칠까지 찾아보나. 알림 예약과 같은 지평이다
    /// (`ReminderPlan.horizonDays`). 그보다 먼 것은 '나중'으로 충분하다.
    static let occurrenceHorizonDays = 60

    /// 묶음별 할 일. **빈 묶음은 돌려주지 않는다** — 화면이 매번 비어 있는지
    /// 따져보지 않아도 되게.
    static func sections(
        in todos: [TodoItem],
        today: Date,
        calendar: Calendar = .current
    ) -> [(section: Section, todos: [TodoItem])] {
        let start = calendar.startOfDay(for: today)
        var grouped: [Section: [TodoItem]] = [:]

        for todo in todos {
            guard let section = section(for: todo, today: start, calendar: calendar) else { continue }
            grouped[section, default: []].append(todo)
        }

        return Section.allCases.compactMap { section in
            guard let items = grouped[section], !items.isEmpty else { return nil }
            return (section, sort(items, in: section, today: start, calendar: calendar))
        }
    }

    /// 이 할 일이 설 자리. 어디에도 안 서면 nil — 끝낸 앞날 일정이 그렇다.
    static func section(
        for todo: TodoItem,
        today: Date,
        calendar: Calendar = .current
    ) -> Section? {
        guard todo.date != nil else {
            // 날짜 없는 것은 끝내면 목록에서 내려간다. 되살릴 길은 검색이다 —
            // 끝낸 백로그가 계속 쌓이면 이 묶음이 무덤이 된다.
            return todo.isCompleted ? nil : .noDate
        }

        // 오늘 걸치면 끝냈든 아니든 오늘이다. **끝낸 것을 지우지 않는 이유**는
        // 잘못 누른 것을 되돌릴 자리가 있어야 하고, 오늘 한 일이 눈에 보이는
        // 편이 기분이 좋아서다. 정렬에서 아래로 내려간다.
        if todo.occurs(on: today) { return .today }

        if todo.isOverdue(today: today) { return .overdue }

        // 여기부터는 앞날이다. 끝낸 앞날 일정은 보여줄 이유가 없다.
        guard let next = nextOccurrence(of: todo, onOrAfter: today, calendar: calendar) else {
            // 60일 안에 회차가 없다. 반복이 아닌 먼 일정이거나, 반복이 끝난 것.
            guard let date = todo.date, calendar.startOfDay(for: date) > today else { return nil }
            return todo.isCompleted ? nil : .later
        }
        guard !isCompleted(todo, on: next, calendar: calendar) else { return nil }

        let days = calendar.dateComponents([.day], from: today, to: next).day ?? 0
        return days <= weekHorizonDays ? .thisWeek : .later
    }

    /// 오늘 **다음으로** 이 할 일이 걸치는 날. 반복이면 다음 회차다.
    ///
    /// 하루씩 짚어본다. 반복 규칙마다 주기를 계산해 건너뛰는 방법도 있지만
    /// (`CalendarEventExpander`가 그렇게 한다), 여기서 찾는 것은 **첫 번째 하나**라
    /// 대개 며칠 안에 끝난다. 끝까지 가는 경우는 반복이 이미 끝났거나 아주 먼
    /// 일정뿐이고, 그건 60일로 잘린다.
    static func nextOccurrence(
        of todo: TodoItem,
        onOrAfter today: Date,
        calendar: Calendar = .current,
        horizonDays: Int = occurrenceHorizonDays
    ) -> Date? {
        guard todo.date != nil else { return nil }
        var cursor = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: today)) ?? today
        for _ in 0..<horizonDays {
            if todo.occurs(on: cursor) { return cursor }
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { return nil }
            cursor = next
        }
        return nil
    }

    /// 묶음 안의 순서. **끝낸 것은 아래로, 그다음 날짜순**이다.
    ///
    /// 한때 '나중' 칸에서 디데이를 맨 위로 끌어올렸다. 날짜순을 깨는 예외라
    /// 목록을 읽는 리듬이 끊겼다 — 디데이가 답하는 "며칠 남았나"는 맨 위
    /// 카드가 맡는다(`dDays`).
    static func sort(
        _ todos: [TodoItem],
        in section: Section,
        today: Date,
        calendar: Calendar = .current
    ) -> [TodoItem] {
        todos.sorted { lhs, rhs in
            let lhsDone = isCompleted(lhs, on: today, calendar: calendar)
            let rhsDone = isCompleted(rhs, on: today, calendar: calendar)
            if lhsDone != rhsDone { return !lhsDone }

            switch section {
            case .noDate:
                // 끌어서 정한 순서를 먼저 본다 — 할 일 목록과 같은 `sortIndex`다.
                if lhs.sortIndex != rhs.sortIndex { return lhs.sortIndex < rhs.sortIndex }
                return lhs.createdAt < rhs.createdAt
            case .today:
                // 하루 안에서는 시각순. 시간 없는 것은 -1이라 위로 온다.
                if lhs.sortableMinutes != rhs.sortableMinutes {
                    return lhs.sortableMinutes < rhs.sortableMinutes
                }
                return lhs.createdAt < rhs.createdAt
            case .overdue, .thisWeek, .later:
                let lhsDate = keyDate(for: lhs, section: section, today: today, calendar: calendar)
                let rhsDate = keyDate(for: rhs, section: section, today: today, calendar: calendar)
                if lhsDate != rhsDate { return lhsDate < rhsDate }
                return lhs.createdAt < rhs.createdAt
            }
        }
    }

    /// 정렬에 쓸 날짜. 지난 것은 오래된 순이라 원본 날짜를, 앞날은 **다음 회차**를
    /// 본다 — 반복 일정을 원본 시작일로 세우면 2년 전에 만든 매주 회의가
    /// 영영 맨 위에 붙는다.
    private static func keyDate(
        for todo: TodoItem,
        section: Section,
        today: Date,
        calendar: Calendar
    ) -> Date {
        switch section {
        case .overdue:
            return todo.effectiveEndDate ?? todo.date ?? .distantPast
        default:
            return nextOccurrence(of: todo, onOrAfter: today, calendar: calendar)
                ?? todo.date
                ?? .distantFuture
        }
    }

    /// 맨 위 카드에 설 것 — 디데이로 표시한 것 중 오늘이거나 앞으로 올 것, 가까운 순.
    ///
    /// **지난 디데이는 빼지 않는다.** 날짜가 지났어도 안 끝냈으면 '지난 할 일' 칸에
    /// 그대로 있고, 카드에서까지 사라지면 왜 없어졌는지 알 수 없다 — 다만 카드는
    /// "며칠 남았나"를 세는 자리라, 지난 것은 `D+3`으로 센다.
    static func dDays(in todos: [TodoItem], today: Date, calendar: Calendar = .current) -> [TodoItem] {
        todos
            .filter { $0.isDDay && $0.date != nil && !$0.isCompleted }
            .sorted { ($0.date ?? .distantFuture) < ($1.date ?? .distantFuture) }
    }

    private static func isCompleted(_ todo: TodoItem, on day: Date, calendar: Calendar) -> Bool {
        todo.date == nil ? todo.isCompleted : todo.isCompleted(on: day)
    }

}
