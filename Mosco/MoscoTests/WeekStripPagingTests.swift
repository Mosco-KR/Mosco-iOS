import Foundation
import Testing

/// 하루치 페이지 머리 스트립이 어느 주를 보여주고, 주를 넘길 때 어느 날로 가는가.
///
/// **한 번 되돌린 자리다.** 고른 날을 가운데 두는 7일 창으로 바꿨다가 일~토로
/// 돌아왔다 — 칸의 요일이 고정되지 않으면 줄을 읽을 수 없고 요일 머리글도 붙일
/// 수 없다. 되돌린 판단을 테스트로 묶어둔다.
@Suite("주간 스트립")
struct WeekStripPagingTests {

    private let calendar = TestCalendar.korea

    private func weekStart(_ date: String) -> Date {
        WeekStripPaging.weekStart(containing: day(date, calendar: calendar), calendar: calendar)
    }

    // MARK: - 어느 주인가

    /// 2026-10-15는 목요일. 그 주의 일요일은 10-11이다.
    @Test("그_날이_속한_주의_일요일을_찾는다")
    func 주의_시작() {
        #expect(label(weekStart("2026-10-15"), calendar: calendar) == "2026-10-11")
    }

    /// **일요일이 왼쪽 끝에 서는 것은 어색한 게 아니라 맞는 것이다.**
    /// 머리글에 '일'이라고 쓰여 있으면 그렇게 읽힌다.
    @Test("일요일을_고르면_그_날이_주의_첫째_칸이다")
    func 일요일() {
        #expect(label(weekStart("2026-10-11"), calendar: calendar) == "2026-10-11")
    }

    @Test("토요일을_고르면_그_주의_일요일로_거슬러_올라간다")
    func 토요일() {
        #expect(label(weekStart("2026-10-17"), calendar: calendar) == "2026-10-11")
    }

    @Test("하루_중간_시각이어도_그날_0시_기준으로_맞춘다")
    func 시각은_버린다() {
        let 오후 = calendar.date(bySettingHour: 23, minute: 30, second: 0, of: day("2026-10-15", calendar: calendar))!
        let start = WeekStripPaging.weekStart(containing: 오후, calendar: calendar)
        #expect(label(start, calendar: calendar) == "2026-10-11")
    }

    // MARK: - 한 주의 날들

    @Test("한_주는_일요일부터_이레다")
    func 이레() {
        let days = WeekStripPaging.days(of: weekStart("2026-10-15"), calendar: calendar)

        #expect(days.count == 7)
        #expect(label(days.first!, calendar: calendar) == "2026-10-11")
        #expect(label(days.last!, calendar: calendar) == "2026-10-17")
    }

    // MARK: - 주를 넘길 때

    /// 목요일을 보다가 다음 주로 밀면 **다음 주 목요일**이다. 주의 첫날로 데려가면
    /// 밀 때마다 요일이 일요일로 되돌아가서, 두 번 넘기면 보던 요일을 잃는다.
    @Test("주를_넘겨도_보던_요일을_지킨다")
    func 요일_유지() {
        let 다음_주 = weekStart("2026-10-18")
        let 결과 = WeekStripPaging.day(
            inWeek: 다음_주,
            keepingWeekdayOf: day("2026-10-15", calendar: calendar),
            calendar: calendar
        )

        #expect(label(결과, calendar: calendar) == "2026-10-22", "목요일에서 다음 주 목요일로")
    }

    @Test("이전_주로_밀어도_같은_요일이다")
    func 이전_주() {
        let 지난_주 = weekStart("2026-10-04")
        let 결과 = WeekStripPaging.day(
            inWeek: 지난_주,
            keepingWeekdayOf: day("2026-10-15", calendar: calendar),
            calendar: calendar
        )

        #expect(label(결과, calendar: calendar) == "2026-10-08")
    }

    @Test("일요일을_보고_있었으면_넘긴_주의_일요일이다")
    func 일요일_유지() {
        let 결과 = WeekStripPaging.day(
            inWeek: weekStart("2026-10-18"),
            keepingWeekdayOf: day("2026-10-11", calendar: calendar),
            calendar: calendar
        )

        #expect(label(결과, calendar: calendar) == "2026-10-18")
    }

    // MARK: - 올려두는 창

    /// **창을 고정 배열로 들던 것은 걷어냈다 (1.5.3).** 앞뒤 십 년치 1,041개 주를
    /// 지연 로딩하면서 스크롤 자리를 값으로 잡았는데, 그게 페이지 경계에 못 서서
    /// 요일 머리글과 숫자가 어긋나 보였다. 지금은 **세 페이지만** 든다
    /// (`WeekPagerView`) — 그 셋은 아래 `days(of:)`와 `weekStart(containing:)`로
    /// 그때그때 만든다. 그래서 창을 재는 테스트도 함께 없앴다.
    @Test("세_페이지는_한_주씩_떨어져_있다")
    func 창() {
        let calendar = TestCalendar.korea
        let center = WeekStripPaging.weekStart(containing: day("2026-10-27", calendar: calendar), calendar: calendar)
        let 지난주 = calendar.date(byAdding: .day, value: -7, to: center)!
        let 다음주 = calendar.date(byAdding: .day, value: 7, to: center)!

        #expect(label(지난주, calendar: calendar) == "2026-10-18")
        #expect(label(center, calendar: calendar) == "2026-10-25")
        #expect(label(다음주, calendar: calendar) == "2026-11-01")
    }
}
