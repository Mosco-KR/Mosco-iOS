import SwiftUI

/// 달력에서 날짜 숫자를 무슨 색으로 쓸지. 한국 캘린더 관례대로 일요일과 공휴일은
/// 빨강, 토요일은 파랑이다.
///
/// 이 규칙이 `Shared`에 있는 이유는 앱과 위젯이 갈라지지 않게 하려는 것이다.
/// 예전엔 `DayCell` 안에만 있어서 위젯 달력에는 주말·공휴일 구분이 통째로
/// 빠져 있었다 — 앱에서는 빨간 15일(광복절)이 위젯에서는 그냥 검은 숫자였다.
///
/// 색은 `MoscoPalette.must`/`could`와 같은 값이지만 일부러 따로 둔다. 그쪽은
/// 할 일의 **우선순위** 색이라, 우연히 같은 빨강일 뿐 같은 뜻이 아니다 —
/// 한쪽을 바꿀 때 다른 쪽이 딸려 가면 안 된다.
enum CalendarDayTone {
    case weekday
    case saturday
    case sundayOrHoliday

    static let holidayRed = Color(hex: 0xEF4444)
    static let saturdayBlue = Color(hex: 0x3B82F6)

    /// 날짜만 보고 판단한다(공휴일 조회 포함).
    static func of(_ date: Date, calendar: Calendar = .current) -> CalendarDayTone {
        if KoreanHoliday.name(for: date) != nil { return .sundayOrHoliday }
        switch calendar.component(.weekday, from: date) {
        case 1: return .sundayOrHoliday
        case 7: return .saturday
        default: return .weekday
        }
    }

    /// 주말/공휴일 판정을 이미 갖고 있는 쪽(앱 격자)에서 쓰는 생성자 —
    /// 같은 조회를 두 번 하지 않으려는 것이다.
    init(isSaturday: Bool, isSundayOrHoliday: Bool) {
        if isSundayOrHoliday {
            self = .sundayOrHoliday
        } else if isSaturday {
            self = .saturday
        } else {
            self = .weekday
        }
    }

    var color: Color {
        switch self {
        case .sundayOrHoliday: Self.holidayRed
        case .saturday: Self.saturdayBlue
        case .weekday: .primary
        }
    }
}
