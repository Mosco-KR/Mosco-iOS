import Foundation
import SwiftData

@Model
final class TodoItem {
    var id: UUID
    var title: String
    /// 할 일이 시작하는 날짜(하루 단위). nil이면 날짜 없는 백로그 항목 — 캘린더엔
    /// 안 나오고 "할 일" 탭에만 있는다("할 일" 탭에서 바로 만들면 기본값이 없다).
    var date: Date?
    /// 여러 날에 걸치면 값, 하루짜리면 nil(= date와 동일하다고 취급).
    var endDate: Date?
    /// 특정 시작 시간이 있으면 값, 종일(시간 없음)이면 nil. hour/minute만 의미 있다.
    var startTime: Date?
    /// 종료 시간(선택). startTime 없이는 의미 없음.
    var endTime: Date?
    /// enum을 raw String으로 저장 (순서/정수 기반 저장 금지 원칙)
    private var priorityRawValue: String
    private var repeatRuleRawValue: String
    /// 반복이 끝나는 날짜. nil이면 무기한 반복(반복 안 함이면 의미 없음).
    var repeatEndDate: Date?
    /// 매주 반복 시 어느 요일들에 반복할지 (1=일요일...7=토요일, Calendar.component(.weekday) 규칙).
    var repeatWeekdays: [Int]
    /// everyNDays 반복의 간격(N). 기존 데이터 호환을 위해 옵셔널로 두고 읽을 때 보정한다.
    var repeatInterval: Int?
    /// 반복 일정에서 완료 처리된 인스턴스들의 시작일 키(dayKey) — 반복은 날마다
    /// 따로 완료할 수 있어야 해서, 전체 isCompleted와 별개로 날짜별로 기록한다.
    var completedDayKeys: [String]?
    var isCompleted: Bool
    var createdAt: Date

    init(
        title: String,
        date: Date? = nil,
        endDate: Date? = nil,
        startTime: Date? = nil,
        endTime: Date? = nil,
        priority: Priority = .should,
        repeatRule: RepeatRule = .none,
        repeatEndDate: Date? = nil,
        repeatWeekdays: [Int] = [],
        repeatInterval: Int? = nil
    ) {
        self.id = UUID()
        self.title = title
        self.date = date
        self.endDate = endDate
        self.startTime = startTime
        self.endTime = endTime
        self.priorityRawValue = priority.rawValue
        self.repeatRuleRawValue = repeatRule.rawValue
        self.repeatEndDate = repeatEndDate
        self.repeatWeekdays = repeatWeekdays
        self.repeatInterval = repeatInterval
        self.isCompleted = false
        self.createdAt = .now
    }

    var priority: Priority {
        get { Priority(rawValue: priorityRawValue) ?? .should }
        set { priorityRawValue = newValue.rawValue }
    }

    var repeatRule: RepeatRule {
        get { RepeatRule(rawValue: repeatRuleRawValue) ?? .none }
        set { repeatRuleRawValue = newValue.rawValue }
    }

    /// 실제 종료일. 하루짜리면 date와 동일, 날짜 자체가 없으면 nil.
    var effectiveEndDate: Date? {
        endDate ?? date
    }

    var isMultiDay: Bool {
        guard let date, let endDate else { return false }
        return !Calendar.current.isDate(endDate, inSameDayAs: date)
    }

    /// 정렬용 키: 시작 시간 없는(종일) 항목은 -1로 취급해 항상 먼저 오고,
    /// 있으면 자정 기준 분(0~1439) 오름차순.
    var sortableMinutes: Int {
        guard let startTime else { return -1 }
        let components = Calendar.current.dateComponents([.hour, .minute], from: startTime)
        return (components.hour ?? 0) * 60 + (components.minute ?? 0)
    }
}
