import Foundation

/// 오늘 탭의 '지난 할 일'과 '오늘로 가져오기'.
///
/// 화면 구조체 안에 있던 것을 꺼냈다. 여러 날짜리 할 일에서 두 군데가 깨져 있었다
/// (`TodoItemOverdueTests`).
extension TodoItem {

    /// 날짜가 지났는데 아직 안 끝낸 한 번짜리 할 일인가.
    ///
    /// **여러 날짜리는 끝나는 날로 본다.** 예전엔 시작일로 봐서, 어제 시작해 오늘
    /// 끝나는 할 일이 '지난 할 일'과 '오늘 할 일'에 두 번 나왔다. 아직 기간 안에
    /// 있는 일은 지난 일이 아니다.
    ///
    /// 반복 일정은 "지난 것"이라는 개념이 없다 — 다음 회차가 또 온다.
    func isOverdue(today: Date) -> Bool {
        guard let end = effectiveEndDate else { return false }
        guard repeatRule == .none, !isCompleted else { return false }
        let calendar = Calendar.current
        return calendar.startOfDay(for: end) < calendar.startOfDay(for: today)
    }

    /// 오늘 할 일로 가져온다. 지난 할 일과 날짜 없는 할 일이 같이 쓴다.
    ///
    /// **여러 날짜리는 시작일을 그대로 두고 끝나는 날만 오늘로 늘린다.** 예전엔
    /// 시작일을 오늘로 바꿔서 언제 시작한 일인지가 사라졌고, 끝나는 날은 그대로라
    /// 시작이 끝보다 뒤인 할 일이 생길 수도 있었다.
    func pullIntoToday(_ today: Date) {
        let day = Calendar.current.startOfDay(for: today)
        if isMultiDay {
            endDate = day
        } else {
            date = day
            // 하루짜리인데 끝나는 날이 따로 적혀 있으면 옛 날짜에 남는다.
            endDate = nil
        }
    }
}
