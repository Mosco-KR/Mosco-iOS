import Foundation

/// 오늘 페이지에만 붙는 것들 — 예전 오늘 탭이 하던 일이다.
///
/// 1.4.0에서 탭을 없애고 달력을 홈으로 두면서, 오늘 탭의 몫은 달력에서 오늘을 눌러
/// 여는 하루 페이지가 맡는다. **오늘 탭에서 쓰던 것 중 하나라도 빠지면 기존 사용자가
/// 잃는 게 생긴다** — 디데이 카드, 지난 할 일, 날짜 없는 할 일, 많을 때 안내, 검색.
/// 어느 할 일이 어디에 들어가는지는 화면이 아니라 여기서 정하고 테스트로 묶는다
/// (`TodayPageTests`).
enum TodayPage {
    /// 남은 할 일이 이보다 많으면 '하루에 하기엔 많아 보여요'. 오늘 탭과 같은 기준.
    static let overloadThreshold = 8

    /// 디데이로 표시한 할 일 중 오늘이거나 앞으로 올 것, 가까운 순.
    /// 할 일 칸의 깃발만으로는 "며칠 남았나"를 못 본다 — 그래서 카드로 따로 센다.
    static func dDays(in todos: [TodoItem], today: Date) -> [TodoItem] {
        let start = Calendar.current.startOfDay(for: today)
        return todos
            .filter { todo in
                guard todo.isDDay, let date = todo.date else { return false }
                return Calendar.current.startOfDay(for: date) >= start
            }
            .sorted { ($0.date ?? .distantFuture) < ($1.date ?? .distantFuture) }
    }

    /// 날짜가 지났는데 안 끝낸 일, 오래된 순. 판정은 `TodoItem.isOverdue` —
    /// 여러 날짜리는 끝나는 날로 본다.
    static func overdue(in todos: [TodoItem], today: Date) -> [TodoItem] {
        todos
            .filter { $0.isOverdue(today: today) }
            .sorted { ($0.date ?? .distantPast) < ($1.date ?? .distantPast) }
    }

    /// 날짜를 안 정한, 아직 안 끝낸 일. 사용자가 끌어서 정한 순서를 먼저 본다.
    static func backlog(in todos: [TodoItem]) -> [TodoItem] {
        todos
            .filter { $0.date == nil && !$0.isCompleted }
            .sorted { lhs, rhs in
                if lhs.sortIndex != rhs.sortIndex { return lhs.sortIndex < rhs.sortIndex }
                return lhs.createdAt < rhs.createdAt
            }
    }

    /// 제목과 메모를 함께 본다 — 어느 쪽에 적었는지 기억나지 않아도 찾을 수 있게.
    /// 날짜와 무관하게 **전체**를 훑는다. 날짜 있는 것은 날짜순, 날짜 없는 것은 맨 뒤.
    static func search(_ query: String, in todos: [TodoItem]) -> [TodoItem] {
        let keyword = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !keyword.isEmpty else { return [] }
        return todos
            .filter {
                $0.title.localizedStandardContains(keyword)
                    || ($0.memo ?? "").localizedStandardContains(keyword)
            }
            .sorted { lhs, rhs in
                switch (lhs.date, rhs.date) {
                case let (l?, r?): return l < r
                case (nil, _?): return false
                case (_?, nil): return true
                default: return lhs.createdAt < rhs.createdAt
                }
            }
    }
}
