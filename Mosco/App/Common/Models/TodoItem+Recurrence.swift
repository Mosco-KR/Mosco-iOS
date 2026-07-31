import Foundation

/// 반복 인스턴스 계산. 저장소에 복제본을 만들지 않고, "이 날짜가 반복 시작일인가"를
/// 규칙으로 판정해서 캘린더 블록과 하루치 리스트가 필요할 때 계산해 쓴다 —
/// 원본 하나만 수정/완료하면 모든 반복에 함께 반영된다.
/// 날짜 자체가 없는(백로그) 항목은 어떤 날짜에도 걸치지 않는다.
extension TodoItem {
    /// 원본 일정이 며칠짜리인지(하루짜리면 0, 날짜 없으면 0).
    var durationDays: Int {
        guard let date, let effectiveEndDate else { return 0 }
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: date)
        let end = calendar.startOfDay(for: effectiveEndDate)
        return calendar.dateComponents([.day], from: start, to: end).day ?? 0
    }

    /// 반복까지 고려해서, 주어진 날에 이 할 일(원본 또는 반복 인스턴스)이 걸치는지.
    func occurs(on day: Date) -> Bool {
        occurrenceStart(covering: day) != nil
    }

    /// 주어진 날을 덮는 인스턴스(원본 또는 반복)의 시작일. 안 걸치면 nil.
    func occurrenceStart(covering day: Date) -> Date? {
        guard let date, let effectiveEndDate else { return nil }
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: day)
        let baseStart = calendar.startOfDay(for: date)
        let baseEnd = calendar.startOfDay(for: effectiveEndDate)

        if dayStart >= baseStart && dayStart <= baseEnd { return baseStart }
        guard repeatRule != .none, dayStart > baseStart else { return nil }

        for offset in 0...durationDays {
            guard let candidate = calendar.date(byAdding: .day, value: -offset, to: dayStart) else { continue }
            if isRepeatStart(candidate) { return candidate }
        }
        return nil
    }

    /// 그날(이 걸친 인스턴스)이 완료됐는지 — 반복이면 날짜별 기록으로, 아니면 전체 완료로 판단.
    func isCompleted(on day: Date) -> Bool {
        guard repeatRule != .none else { return isCompleted }
        guard let start = occurrenceStart(covering: day) else { return false }
        return (completedDayKeys ?? []).contains(start.dayKey)
    }

    /// 그날의 인스턴스만 완료/해제한다 — 다른 날의 반복에는 영향이 없다.
    func setCompleted(_ done: Bool, on day: Date) {
        guard repeatRule != .none else {
            isCompleted = done
            return
        }
        guard let start = occurrenceStart(covering: day) else { return }
        var keys = completedDayKeys ?? []
        if done {
            if !keys.contains(start.dayKey) { keys.append(start.dayKey) }
        } else {
            keys.removeAll { $0 == start.dayKey }
        }
        completedDayKeys = keys
    }

    /// 주어진 날짜가 이 할 일의 반복 "시작일"인지(원본 시작일 이후만 해당).
    func isRepeatStart(_ day: Date) -> Bool {
        guard let date else { return false }
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: day)
        let baseStart = calendar.startOfDay(for: date)
        guard dayStart > baseStart else { return false }
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
                return weekday == calendar.component(.weekday, from: baseStart)
            }
            return repeatWeekdays.contains(weekday)
        case .monthly:
            return calendar.component(.day, from: dayStart) == calendar.component(.day, from: baseStart)
        case .yearly:
            let dayComponents = calendar.dateComponents([.month, .day], from: dayStart)
            let baseComponents = calendar.dateComponents([.month, .day], from: baseStart)
            return dayComponents.month == baseComponents.month && dayComponents.day == baseComponents.day
        case .everyNDays:
            let interval = max(repeatInterval ?? 2, 1)
            let days = calendar.dateComponents([.day], from: baseStart, to: dayStart).day ?? 0
            return days > 0 && days % interval == 0
        }
    }
}
