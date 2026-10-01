import Foundation

/// 날짜·시각을 화면에 쓸 글자로 조립한다.
///
/// `DateFormatter`에 맡기지 않고 손으로 조립하는 건 **표기를 앱이 정하기 위해서**다.
/// 시스템 형식은 "오후 7:00"처럼 분을 늘 붙이는데, 이 앱은 정각이면 "오후 7시"로
/// 줄여 쓴다. 칩과 위젯은 그 몇 글자가 아쉽다. 언어를 인자로 받는 것은 테스트가
/// 기기 언어와 무관하게 세 언어를 다 확인할 수 있게 하려는 것이다.
nonisolated enum DateText {
    private static let englishMonths = [
        "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec",
    ]

    /// 일요일부터. 달력 머리와 요일 고르기가 `id: \.self`로 돌리므로 **서로 달라야 한다** —
    /// 영어를 한 글자(S·M·T·W·T·F·S)로 줄이면 S와 T가 겹쳐 칸이 사라진다.
    static func weekdaySymbols(_ language: AppLanguage = .current) -> [String] {
        switch language {
        case .ko: ["일", "월", "화", "수", "목", "금", "토"]
        case .en: ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        case .ja: ["日", "月", "火", "水", "木", "金", "土"]
        }
    }

    /// "8월" / "Aug" / "8月"
    static func monthName(_ month: Int, _ language: AppLanguage = .current) -> String {
        switch language {
        case .ko: "\(month)월"
        case .en: englishMonths[(month - 1) % 12]
        case .ja: "\(month)月"
        }
    }

    /// "2026년" / "2026" / "2026年"
    static func yearLabel(_ year: Int, _ language: AppLanguage = .current) -> String {
        switch language {
        case .ko: "\(year)년"
        case .en: "\(year)"
        case .ja: "\(year)年"
        }
    }

    /// "2026년 8월" / "Aug 2026" / "2026年8月"
    static func yearMonth(year: Int, month: Int, _ language: AppLanguage = .current) -> String {
        switch language {
        case .ko: "\(year)년 \(month)월"
        case .en: "\(englishMonths[(month - 1) % 12]) \(year)"
        case .ja: "\(year)年\(month)月"
        }
    }

    /// "7월 30일" / "Jul 30" / "7月30日"
    static func monthDay(month: Int, day: Int, _ language: AppLanguage = .current) -> String {
        switch language {
        case .ko: "\(month)월 \(day)일"
        case .en: "\(englishMonths[(month - 1) % 12]) \(day)"
        case .ja: "\(month)月\(day)日"
        }
    }

    /// "7월 30일 목요일" / "Thu, Jul 30" / "7月30日(木)". `weekday`는 일요일이 1.
    static func monthDayWeekday(month: Int, day: Int, weekday: Int, _ language: AppLanguage = .current) -> String {
        let symbol = weekdaySymbols(language)[(weekday - 1) % 7]
        return switch language {
        case .ko: "\(month)월 \(day)일 \(symbol)요일"
        case .en: "\(symbol), \(englishMonths[(month - 1) % 12]) \(day)"
        case .ja: "\(month)月\(day)日(\(symbol))"
        }
    }

    /// 한 주의 범위. "8월 3–9일" / "Aug 3–9" / "8月3日–9日", 달을 넘으면 양쪽에 달을 붙인다.
    static func dayRange(
        fromMonth: Int, fromDay: Int, toMonth: Int, toDay: Int, _ language: AppLanguage = .current
    ) -> String {
        guard fromMonth == toMonth else {
            return "\(monthDay(month: fromMonth, day: fromDay, language)) – \(monthDay(month: toMonth, day: toDay, language))"
        }
        return switch language {
        case .ko: "\(fromMonth)월 \(fromDay)–\(toDay)일"
        case .en: "\(englishMonths[(fromMonth - 1) % 12]) \(fromDay)–\(toDay)"
        case .ja: "\(fromMonth)月\(fromDay)日–\(toDay)日"
        }
    }

    /// "오후 7시" · "오후 7시 30분" / "7 PM" · "7:30 PM" / "午後7時" · "午後7時30分"
    static func time(hour24: Int, minute: Int, _ language: AppLanguage = .current) -> String {
        let isAfternoon = hour24 % 24 >= 12
        var hour12 = hour24 % 12
        if hour12 == 0 { hour12 = 12 }
        switch language {
        case .ko:
            let period = isAfternoon ? "오후" : "오전"
            return minute == 0 ? "\(period) \(hour12)시" : "\(period) \(hour12)시 \(minute)분"
        case .en:
            let period = isAfternoon ? "PM" : "AM"
            return minute == 0 ? "\(hour12) \(period)" : "\(hour12):\(minute < 10 ? "0" : "")\(minute) \(period)"
        case .ja:
            let period = isAfternoon ? "午後" : "午前"
            return minute == 0 ? "\(period)\(hour12)時" : "\(period)\(hour12)時\(minute)分"
        }
    }

    /// 시간표 눈금. 오전/오후가 바뀌는 칸에만 붙이고 나머지는 숫자만 둔다.
    static func hourTick(hour24: Int, showsPeriod: Bool, _ language: AppLanguage = .current) -> String {
        guard !showsPeriod else { return time(hour24: hour24, minute: 0, language) }
        var hour12 = hour24 % 12
        if hour12 == 0 { hour12 = 12 }
        return switch language {
        case .ko: "\(hour12)시"
        case .en: "\(hour12)"
        case .ja: "\(hour12)時"
        }
    }

    static func today(_ language: AppLanguage = .current) -> String {
        switch language {
        case .ko: "오늘"
        case .en: "Today"
        case .ja: "今日"
        }
    }

    static func tomorrow(_ language: AppLanguage = .current) -> String {
        switch language {
        case .ko: "내일"
        case .en: "Tomorrow"
        case .ja: "明日"
        }
    }
}

extension Date {
    /// "7월 30일 목요일" 형태. 기기 로케일이 아니라 앱이 뜬 언어를 따른다.
    var localizedMonthDayWeekday: String {
        let calendar = Calendar.current
        return DateText.monthDayWeekday(
            month: calendar.component(.month, from: self),
            day: calendar.component(.day, from: self),
            weekday: calendar.component(.weekday, from: self)
        )
    }

    /// "7월 30일" 형태. 칩처럼 짧게 보여줄 때 사용.
    var localizedMonthDay: String {
        let calendar = Calendar.current
        return DateText.monthDay(
            month: calendar.component(.month, from: self),
            day: calendar.component(.day, from: self)
        )
    }

    /// "오후 7시" / 분이 있으면 "오후 7시 30분" 형태.
    var localizedTime: String {
        let calendar = Calendar.current
        return DateText.time(
            hour24: calendar.component(.hour, from: self),
            minute: calendar.component(.minute, from: self)
        )
    }

    /// 오늘/내일은 상대 표현, 그 이후는 "7월 30일" 형태.
    var localizedRelativeDay: String {
        let calendar = Calendar.current
        if calendar.isDateInToday(self) { return DateText.today() }
        if calendar.isDateInTomorrow(self) { return DateText.tomorrow() }
        return localizedMonthDay
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
func localizedScheduleLabel(date: Date, time: Date?) -> String {
    let dayPart = date.localizedRelativeDay
    guard let time else { return dayPart }
    return "\(dayPart) \(time.localizedTime)"
}
