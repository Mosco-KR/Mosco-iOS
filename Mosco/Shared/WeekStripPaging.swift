import Foundation

/// 하루치 페이지 머리 스트립이 어느 주를 보여주고, 주를 넘길 때 어느 날로 가는가.
///
/// ## 한 번 되돌렸다
///
/// 처음에는 일요일로 시작하는 주로 끊었고, 그다음엔 **고른 날이 가운데 오는 7일
/// 창**으로 바꿨다. 들어온 날이 일요일이면 맨 왼쪽에 붙는 게 어색해 보여서였다.
/// 그런데 그 바꿈이 더 큰 것을 깨뜨렸다 — **칸의 요일이 고정되지 않는다.** 넷째 칸이
/// 어떤 날은 목요일, 어떤 날은 화요일이 되니 줄을 읽으려면 매번 숫자를 세야 했고,
/// 요일 머리글을 붙일 수도 없었다(붙일 머리글이 정해지지 않으니까). 달 격자는
/// 일~토로 서 있는데 그 아래 줄만 다른 규칙이라 두 화면이 어긋나 보이기도 했다.
///
/// 그래서 **일~토로 되돌린다.** 일요일이 왼쪽 끝에 서는 것은 어색한 게 아니라
/// 맞는 것이다 — 머리글에 '일'이라고 쓰여 있으면 그렇게 읽힌다.
///
/// ## 넘기면 날짜도 따라간다
///
/// 예전에는 줄을 밀어도 보고 있는 날이 그대로였다. 줄만 움직이고 아래 목록은
/// 안 바뀌니 **민 것이 아무 일도 안 한 것처럼** 느껴졌고, 고른 날 표시는 화면
/// 밖으로 밀려나기도 했다. 이제 주를 넘기면 **같은 요일의 그 주 날짜**로 간다 —
/// 목요일을 보다가 다음 주로 넘기면 다음 주 목요일이다.
enum WeekStripPaging {
    static let daysPerPage = 7

    /// 이 날이 속한 주의 일요일.
    static func weekStart(containing date: Date, calendar: Calendar = .current) -> Date {
        let sunday = calendar.startingSunday
        let day = sunday.startOfDay(for: date)
        let weekday = sunday.component(.weekday, from: day)   // 일요일이 1
        return sunday.date(byAdding: .day, value: -(weekday - 1), to: day) ?? day
    }

    /// 그 주의 일~토.
    static func days(of weekStart: Date, calendar: Calendar = .current) -> [Date] {
        let start = calendar.startOfDay(for: weekStart)
        return (0..<daysPerPage).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
    }

    /// 주를 넘겼을 때 설 날 — **보던 요일을 지킨다.**
    ///
    /// 목요일을 보다가 다음 주로 밀면 다음 주 목요일이다. 주의 첫날로 데려가면
    /// 밀 때마다 요일이 일요일로 되돌아가서, 주를 두 번 넘기면 처음에 보던
    /// 요일을 잃는다.
    static func day(inWeek weekStart: Date, keepingWeekdayOf current: Date, calendar: Calendar = .current) -> Date {
        let sunday = calendar.startingSunday
        let offset = sunday.component(.weekday, from: sunday.startOfDay(for: current)) - 1
        let start = calendar.startOfDay(for: weekStart)
        return calendar.date(byAdding: .day, value: offset, to: start) ?? start
    }
}

/// 스트립이 올려둘 주들. 고정 배열인 이유는 `MonthWindow`와 같다 — 창을 옮기며
/// 오프셋을 되돌리는 방식은 그 순간이 튀기 쉽다.
///
/// 주 단위라 날 단위로 들고 있던 때(7,301개)보다 항목이 1/7로 준다.
enum WeekStripWindow {
    /// 앞뒤 10년.
    static let radius = 520

    static let weeks: [Date] = {
        let calendar = Calendar.current
        let anchor = WeekStripPaging.weekStart(containing: Date(), calendar: calendar)
        return (-radius...radius).compactMap {
            calendar.date(byAdding: .day, value: $0 * WeekStripPaging.daysPerPage, to: anchor)
        }
    }()
}
