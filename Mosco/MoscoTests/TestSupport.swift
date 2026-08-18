import Foundation
@testable import App

/// 테스트가 쓰는 고정 달력. 시간대와 첫 요일이 기기 설정에 따라 흔들리면
/// 같은 테스트가 어떤 날은 통과하고 어떤 날은 깨진다 — 실패가 코드 때문인지
/// 환경 때문인지 구분이 안 되는 순간 그 테스트는 신뢰를 잃는다.
enum TestCalendar {
    static let korea: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Seoul")!
        calendar.locale = Locale(identifier: "ko_KR")
        calendar.firstWeekday = 1          // 일요일 시작 — 앱 캘린더와 같다
        return calendar
    }()
}

/// `2026-08-18` 같은 문자열 하나로 날짜를 만든다.
/// 테스트 본문에 `DateComponents`가 늘어서면 무엇을 검증하는지가 안 보인다.
func day(_ text: String, calendar: Calendar = TestCalendar.korea) -> Date {
    let parts = text.split(separator: "-").compactMap { Int($0) }
    precondition(parts.count == 3, "날짜는 YYYY-MM-DD 형식이어야 한다: \(text)")
    var components = DateComponents()
    components.year = parts[0]
    components.month = parts[1]
    components.day = parts[2]
    return calendar.date(from: components)!
}

/// 날짜를 다시 `YYYY-MM-DD`로. 실패 메시지를 읽을 수 있게 하려는 것이다.
func label(_ date: Date, calendar: Calendar = TestCalendar.korea) -> String {
    let c = calendar.dateComponents([.year, .month, .day], from: date)
    return String(format: "%04d-%02d-%02d", c.year!, c.month!, c.day!)
}

extension TodoSnapshot {
    /// 하루짜리 일정 하나.
    static func oneDay(
        _ title: String,
        on date: String,
        repeatRule: RepeatRule = .none,
        repeatEndDate: String? = nil,
        repeatWeekdays: [Int] = [],
        repeatInterval: Int? = nil,
        completedDayKeys: [String] = []
    ) -> TodoSnapshot {
        TodoSnapshot(
            title: title,
            start: day(date),
            end: day(date),
            repeatRule: repeatRule,
            repeatEndDate: repeatEndDate.map { day($0) },
            repeatWeekdays: repeatWeekdays,
            repeatInterval: repeatInterval,
            completedDayKeys: completedDayKeys,
            createdAt: day(date)
        )
    }

    /// 여러 날에 걸친 일정 하나.
    static func spanning(
        _ title: String,
        from start: String,
        to end: String,
        repeatRule: RepeatRule = .none
    ) -> TodoSnapshot {
        TodoSnapshot(
            title: title,
            start: day(start),
            end: day(end),
            repeatRule: repeatRule,
            createdAt: day(start)
        )
    }
}

/// 기간 하나. `expand`가 받는 창을 읽기 쉽게 만든다.
func window(_ from: String, _ to: String) -> DateInterval {
    DateInterval(start: day(from), end: day(to))
}
