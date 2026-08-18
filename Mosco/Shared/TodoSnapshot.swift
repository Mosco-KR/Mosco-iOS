import Foundation

/// `TodoItem`(@Model)에서 캘린더 계산에 필요한 필드만 뽑아낸 값 타입.
///
/// 존재 이유는 스레드다. 반복 전개는 무거워서 메인 스레드 밖으로 보내야 하는데,
/// SwiftData의 `@Model` 객체는 자기 ModelContext의 스레드 밖에서 만지면 안 된다.
/// 그래서 "메인에서 값으로 베껴오기"만 하고, 그 뒤 계산은 전부 이 값 타입 위에서
/// 돈다.
///
/// 반복 판정 로직(`isRepeatStart`, `occurrenceStart`)은 `TodoItem+Recurrence`의
/// 것과 동작이 같아야 한다 — 한쪽만 고치면 캘린더와 하루치 리스트가 서로 다른
/// 날짜에 같은 일정을 보여주게 된다.
nonisolated struct TodoSnapshot: Equatable, Sendable {
    let id: UUID
    let title: String
    /// nil인 항목(날짜 없는 백로그)은 애초에 스냅샷을 만들지 않는다.
    let start: Date
    let end: Date
    let categoryColorHex: String?
    /// 소속 캘린더의 색. 여러 캘린더를 함께 보고 있을 때 막대에 점으로 찍어
    /// 어느 묶음의 일정인지 구분한다(하나만 보고 있으면 자명하니 안 그린다).
    let calendarColorHex: String?
    let repeatRule: RepeatRule
    let repeatEndDate: Date?
    let repeatWeekdays: [Int]
    let repeatInterval: Int?
    let completedDayKeys: [String]
    let isCompleted: Bool
    let createdAt: Date

    /// 값으로 직접 만든다. `@MainActor init?`을 선언한 순간 컴파일러가 만들어주던
    /// 멤버와이즈 초기화자가 사라져서, 테스트에서 스냅샷 하나를 못 만들었다.
    /// SwiftData 없이 반복 전개를 검증하려면 이 입구가 필요하다.
    init(
        id: UUID = UUID(),
        title: String,
        start: Date,
        end: Date,
        categoryColorHex: String? = nil,
        calendarColorHex: String? = nil,
        repeatRule: RepeatRule = .none,
        repeatEndDate: Date? = nil,
        repeatWeekdays: [Int] = [],
        repeatInterval: Int? = nil,
        completedDayKeys: [String] = [],
        isCompleted: Bool = false,
        createdAt: Date = .now
    ) {
        self.id = id
        self.title = title
        self.start = start
        self.end = end
        self.categoryColorHex = categoryColorHex
        self.calendarColorHex = calendarColorHex
        self.repeatRule = repeatRule
        self.repeatEndDate = repeatEndDate
        self.repeatWeekdays = repeatWeekdays
        self.repeatInterval = repeatInterval
        self.completedDayKeys = completedDayKeys
        self.isCompleted = isCompleted
        self.createdAt = createdAt
    }

    /// 날짜 없는(백로그) 항목은 캘린더에 아예 나오지 않으므로 nil을 낸다.
    @MainActor
    init?(_ todo: TodoItem, calendar: Calendar = .current) {
        guard let date = todo.date, let endDate = todo.effectiveEndDate else { return nil }
        self.id = todo.id
        self.title = todo.title
        self.start = calendar.startOfDay(for: date)
        self.end = calendar.startOfDay(for: endDate)
        self.categoryColorHex = todo.category?.colorHex
        self.calendarColorHex = todo.calendar?.colorHex
        self.repeatRule = todo.repeatRule
        self.repeatEndDate = todo.repeatEndDate
        self.repeatWeekdays = todo.repeatWeekdays
        self.repeatInterval = todo.repeatInterval
        self.completedDayKeys = todo.completedDayKeys ?? []
        self.isCompleted = todo.isCompleted
        self.createdAt = todo.createdAt
    }

    /// 원본 일정이 며칠짜리인지(하루짜리면 0).
    func durationDays(calendar: Calendar) -> Int {
        calendar.dateComponents([.day], from: start, to: end).day ?? 0
    }

    /// 주어진 날짜가 이 할 일의 반복 "시작일"인지(원본 시작일 이후만 해당).
    func isRepeatStart(_ day: Date, calendar: Calendar) -> Bool {
        let dayStart = calendar.startOfDay(for: day)
        guard dayStart > start else { return false }
        if let repeatEndDate, dayStart > calendar.startOfDay(for: repeatEndDate) { return false }

        switch repeatRule {
        case .none:
            return false
        case .daily:
            return true
        case .weekly:
            let weekday = calendar.component(.weekday, from: dayStart)
            // 요일을 따로 안 골랐으면 원본과 같은 요일에 반복.
            if repeatWeekdays.isEmpty {
                return weekday == calendar.component(.weekday, from: start)
            }
            return repeatWeekdays.contains(weekday)
        case .monthly:
            return calendar.component(.day, from: dayStart) == calendar.component(.day, from: start)
        case .yearly:
            let dayComponents = calendar.dateComponents([.month, .day], from: dayStart)
            let baseComponents = calendar.dateComponents([.month, .day], from: start)
            return dayComponents.month == baseComponents.month && dayComponents.day == baseComponents.day
        case .everyNDays:
            let interval = max(repeatInterval ?? 2, 1)
            let days = calendar.dateComponents([.day], from: start, to: dayStart).day ?? 0
            return days > 0 && days % interval == 0
        }
    }

    /// 주어진 날을 덮는 인스턴스(원본 또는 반복)의 시작일. 안 걸치면 nil.
    func occurrenceStart(covering day: Date, calendar: Calendar) -> Date? {
        let dayStart = calendar.startOfDay(for: day)
        if dayStart >= start && dayStart <= end { return start }
        guard repeatRule != .none, dayStart > start else { return nil }

        for offset in 0...durationDays(calendar: calendar) {
            guard let candidate = calendar.date(byAdding: .day, value: -offset, to: dayStart) else { continue }
            if isRepeatStart(candidate, calendar: calendar) { return candidate }
        }
        return nil
    }

    /// 그날(이 걸친 인스턴스)이 완료됐는지 — 반복이면 날짜별 기록으로, 아니면 전체 완료로.
    func isCompleted(on day: Date, calendar: Calendar) -> Bool {
        guard repeatRule != .none else { return isCompleted }
        guard let occurrence = occurrenceStart(covering: day, calendar: calendar) else { return false }
        return completedDayKeys.contains(occurrence.dayKey)
    }
}
