import Foundation

enum KoreanCalendar {
    static let weekdaySymbols = ["일", "월", "화", "수", "목", "금", "토"]
}

extension Date {
    /// "7월 30일 목요일" 형태. 시스템 로케일에 의존하지 않고 항상 한글로 표기한다.
    var koreanMonthDayWeekday: String {
        let calendar = Calendar.current
        let month = calendar.component(.month, from: self)
        let day = calendar.component(.day, from: self)
        let weekday = KoreanCalendar.weekdaySymbols[calendar.component(.weekday, from: self) - 1]
        return "\(month)월 \(day)일 \(weekday)요일"
    }

    /// "7월 30일" 형태. 칩처럼 짧게 보여줄 때 사용.
    var koreanMonthDay: String {
        let calendar = Calendar.current
        let month = calendar.component(.month, from: self)
        let day = calendar.component(.day, from: self)
        return "\(month)월 \(day)일"
    }

    /// "오후 7시" / 분이 있으면 "오후 7시 30분" 형태.
    var koreanTime: String {
        let calendar = Calendar.current
        let hour24 = calendar.component(.hour, from: self)
        let minute = calendar.component(.minute, from: self)
        let period = hour24 >= 12 ? "오후" : "오전"
        var hour12 = hour24 % 12
        if hour12 == 0 { hour12 = 12 }
        return minute == 0 ? "\(period) \(hour12)시" : "\(period) \(hour12)시 \(minute)분"
    }

    /// 오늘/내일은 상대 표현, 그 이후는 "7월 30일" 형태.
    var koreanRelativeDay: String {
        let calendar = Calendar.current
        if calendar.isDateInToday(self) { return "오늘" }
        if calendar.isDateInTomorrow(self) { return "내일" }
        return koreanMonthDay
    }

    /// 하루 단위로 안정적인 딕셔너리 키(같은 날이면 항상 같은 문자열) — 그리드 셀
    /// 프레임을 좌표 공간에서 조회할 때, 고스트 이동 애니메이션의 출발/도착 지점을
    /// 찾는 용도로 쓴다.
    /// 캘린더 스냅샷 계산이 메인 스레드 밖에서 이 값을 쓴다 — 순수 계산이라
    /// 액터에 묶일 이유가 없다(프로젝트 기본 격리가 MainActor라 명시해야 한다).
    nonisolated var dayKey: String {
        String(Int(Calendar.current.startOfDay(for: self).timeIntervalSince1970))
    }
}

/// 오늘 기준 D-day 표기: 당일은 "D-DAY", 미래는 "D-n", 지난 날은 "D+n".
func dDayLabel(for day: Date, from reference: Date = .now, calendar: Calendar = .current) -> String {
    let days = calendar.dateComponents(
        [.day],
        from: calendar.startOfDay(for: reference),
        to: calendar.startOfDay(for: day)
    ).day ?? 0
    if days == 0 { return "D-DAY" }
    return days > 0 ? "D-\(days)" : "D+\(-days)"
}

/// "오늘 오후 7시" / "내일 오후 7시" / "7월 30일 오후 7시" 형태로 조합.
/// time이 nil이면 날짜(상대 표현)만 반환.
func koreanScheduleLabel(date: Date, time: Date?) -> String {
    let dayPart = date.koreanRelativeDay
    guard let time else { return dayPart }
    return "\(dayPart) \(time.koreanTime)"
}
