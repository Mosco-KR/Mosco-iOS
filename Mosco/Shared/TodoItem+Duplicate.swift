import Foundation

/// 할 일을 다른 날로 복제한다.
///
/// **왜 필요한가**: 매주 반복은 아니지만 이따금 되풀이되는 일이 있다 — "다음 주에도
/// 병원", "이번 달에 한 번 더 정리". 반복 규칙을 걸면 원본 하나가 모든 날짜를
/// 대표하게 되어 한 날짜만 고치거나 지울 수 없는데, 그런 일은 각각 따로 서 있어야
/// 한다. 지금까지는 같은 내용을 손으로 다시 적는 수밖에 없었다.
extension TodoItem {
    /// 이 할 일과 같은 내용으로 새 할 일을 만든다. 저장소에는 넣지 않으므로
    /// 호출한 쪽이 `modelContext.insert(_:)`를 해야 한다.
    ///
    /// **완료 상태와 디데이는 따라오지 않는다.** 복제본은 아직 하지 않은 일이고,
    /// 디데이는 손꼽아 기다리는 일 하나에만 의미가 있어서 둘이 되면 그 하나가
    /// 어느 쪽인지 알 수 없게 된다.
    ///
    /// 여러 날에 걸친 일정은 **기간 길이를 유지한 채** 통째로 옮긴다
    /// (`UpcomingScreen.postpone`이 미루기에서 쓰는 것과 같은 규칙).
    func duplicated(to newDate: Date?) -> TodoItem {
        // 이름을 `calendar`로 두면 이 타입의 `calendar` 프로퍼티(TodoCalendar)를
        // 가린다 — QuickAddView.commitSave가 같은 이유로 인자 이름을 피한다.
        let gregorian = Calendar.current
        let resolvedStart = newDate.map { gregorian.startOfDay(for: $0) }
        // 날짜가 없어지면(백로그로 복제) 기간도 시간도 의미를 잃는다.
        let resolvedEnd: Date? = resolvedStart.flatMap { start in
            guard durationDays > 0 else { return nil }
            return gregorian.date(byAdding: .day, value: durationDays, to: start)
        }

        let copy = TodoItem(
            title: title,
            date: resolvedStart,
            endDate: resolvedEnd,
            startTime: resolvedStart == nil ? nil : startTime,
            endTime: resolvedStart == nil ? nil : endTime,
            category: category,
            // 반복 규칙도 함께 온다 — "매주 회의"를 다른 요일로 하나 더 두는 게
            // 실제로 있는 쓰임이다. 날짜가 없으면 반복은 걸 곳이 없다.
            repeatRule: resolvedStart == nil ? .none : repeatRule,
            repeatEndDate: resolvedStart == nil ? nil : repeatEndDate,
            repeatWeekdays: resolvedStart == nil ? [] : repeatWeekdays,
            repeatInterval: resolvedStart == nil ? nil : repeatInterval
        )
        copy.calendar = calendar
        copy.memo = memo
        return copy
    }
}
