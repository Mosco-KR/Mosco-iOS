import Foundation

/// 오늘 페이지에만 붙는 것들 — 예전 오늘 탭이 하던 일이다.
///
/// 1.4.0에서 탭을 없애고 달력을 홈으로 두면서, 오늘 탭의 몫은 달력에서 오늘을 눌러
/// 여는 하루 페이지가 맡았다. 어느 할 일이 어디에 들어가는지는 화면이 아니라
/// 여기서 정하고 테스트로 묶는다(`TodayPageTests`).
///
/// **지금은 이 중 둘이 할 일 탭으로 옮겨 갔다.** `overdue`와 `backlog`는 여기 남아
/// 있지만 읽는 쪽은 할 일 탭(`TodoListPage`)과 하루 요약 알림(`DailySummaryPlan`)이다.
/// 디데이를 추리던 `dDays`는 지웠다 — 디데이 카드가 하던 "며칠 남았나"는 이제
/// 행에 붙는 `D-7` 조각이 답하고, 순서는 `TodoListPage.sort`가 정한다.
enum TodayPage {
    /// 남은 할 일이 이보다 많으면 '하루에 하기엔 많아 보여요'.
    static let overloadThreshold = 8

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

    /// 오늘 할 일 몇 개 중 몇 개가 남았나. 리뷰 부탁의 "오늘을 다 끝낸 순간"을 잡는 데
    /// 쓴다 — 화면이 아니라 앱 뿌리에서 지켜봐야 보기 모드·위젯·검색 어디서 끝내도 잡힌다.
    static func progress(in todos: [TodoItem], today: Date) -> (total: Int, remaining: Int) {
        let todays = todos.filter { $0.date != nil && $0.occurs(on: today) }
        return (todays.count, todays.filter { !$0.isCompleted(on: today) }.count)
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
