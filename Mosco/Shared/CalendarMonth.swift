import Foundation

/// 달력의 한 달을 가리키는 값. 페이지 identity와 스냅샷 키로 `Date` 대신 이걸 쓴다.
///
/// `Date`를 키로 쓰면 "같은 달"인지 볼 때마다 `dateInterval(of: .month)`로 정규화해야
/// 하는데, 그게 Calendar API 중 느린 축이라 렌더 경로에 그대로 얹혔다. 여기서는
/// 비교·해시가 정수 하나(`ordinal`) 연산이라 사실상 공짜고, 달 간 거리 계산도
/// 뺄셈 한 번이다.
nonisolated struct CalendarMonth: Hashable, Comparable, Identifiable, Sendable {
    /// 서기 0년 1월을 0으로 두는 통월 번호. 모든 연산의 기준이자 identity다.
    let ordinal: Int

    var year: Int { Self.floorDiv(ordinal, 12) }
    /// 1...12
    var month: Int { ordinal - year * 12 + 1 }

    var id: Int { ordinal }

    init(ordinal: Int) {
        self.ordinal = ordinal
    }

    init(year: Int, month: Int) {
        self.ordinal = year * 12 + (month - 1)
    }

    static func containing(_ date: Date, calendar: Calendar = .current) -> CalendarMonth {
        let components = calendar.dateComponents([.year, .month], from: date)
        return CalendarMonth(year: components.year ?? 1970, month: components.month ?? 1)
    }

    func advanced(by months: Int) -> CalendarMonth {
        CalendarMonth(ordinal: ordinal + months)
    }

    /// 이 달의 1일 00:00.
    func startDate(calendar: Calendar = .current) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = 1
        return calendar.date(from: components) ?? Date()
    }

    /// 다음 달의 1일 00:00 — 이 달의 (열린) 끝.
    func endDate(calendar: Calendar = .current) -> Date {
        advanced(by: 1).startDate(calendar: calendar)
    }

    /// 두 달 사이의 거리(개월). 부호가 있다.
    func distance(to other: CalendarMonth) -> Int {
        other.ordinal - ordinal
    }

    static func < (lhs: CalendarMonth, rhs: CalendarMonth) -> Bool {
        lhs.ordinal < rhs.ordinal
    }

    /// 음수에서도 내림으로 나눈다 — 기원전 연도를 다룰 일은 없지만, 나눗셈이
    /// 0 쪽으로 잘리면 month가 1...12를 벗어나 조용히 어긋나므로 막아둔다.
    private static func floorDiv(_ dividend: Int, _ divisor: Int) -> Int {
        let quotient = dividend / divisor
        let hasRemainder = dividend % divisor != 0
        return hasRemainder && ((dividend < 0) != (divisor < 0)) ? quotient - 1 : quotient
    }
}
