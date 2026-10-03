import CoreGraphics
import Foundation
import Testing

/// 하루치 페이지 머리 스트립 — 들어온 날이 맨 왼쪽 끝에 붙던 증상.
/// 일요일로 시작하는 주로 끊었더니 30일(일요일)에 들어가면 그 칸이 줄 끝에 붙었다.
@Suite("주간 스트립 위치")
struct WeekStripPagingTests {

    private let calendar = TestCalendar.korea

    @Test("고른_날이_일곱_칸의_가운데에_온다", arguments: [
        ("2026-08-30", "2026-08-27"),   // 일요일 — 예전엔 맨 왼쪽이었다
        ("2026-09-05", "2026-09-02"),   // 토요일 — 예전엔 맨 오른쪽이었다
        ("2026-10-01", "2026-09-28"),   // 월초 — 앞 달로 넘어간다
        ("2026-03-02", "2026-02-27"),   // 2월 끝을 건넌다
        ("2025-01-02", "2024-12-30"),   // 해를 건넌다
    ])
    func 가운데_정렬(selected: String, expectedLeading: String) {
        let leading = WeekStripPaging.leadingDay(centering: day(selected), calendar: calendar)
        #expect(label(leading) == expectedLeading)

        let center = calendar.date(byAdding: .day, value: WeekStripPaging.daysBeforeCenter, to: leading)!
        #expect(label(center) == selected, "넷째 칸이 \(label(center))다 — 고른 날이 아니다")
    }

    @Test("하루_중간_시각이어도_그날_0시_기준으로_맞춘다")
    func 시각은_버린다() {
        let afternoon = calendar.date(byAdding: .hour, value: 15, to: day("2026-08-30"))!
        let leading = WeekStripPaging.leadingDay(centering: afternoon, calendar: calendar)
        #expect(leading == day("2026-08-27"))
    }

    // MARK: - 미는 손짓

    private let dayWidth: CGFloat = 50
    private var page: CGFloat { dayWidth * 7 }

    @Test("반_주_넘게_밀면_정확히_한_주_넘어간다")
    func 다음_주() {
        let start = dayWidth * 100
        #expect(WeekStripPaging.restingOffset(start: start, proposed: start + page * 0.6, dayWidth: dayWidth) == start + page)
        #expect(WeekStripPaging.restingOffset(start: start, proposed: start - page * 0.6, dayWidth: dayWidth) == start - page)
    }

    @Test("세게_튕겨도_한_번에_한_주만_간다")
    func 한_주씩만() {
        let start = dayWidth * 100
        #expect(WeekStripPaging.restingOffset(start: start, proposed: start + page * 5, dayWidth: dayWidth) == start + page)
    }

    @Test("조금_밀다_놓으면_제자리로_돌아온다")
    func 제자리() {
        let start = dayWidth * 100
        #expect(WeekStripPaging.restingOffset(start: start, proposed: start + page * 0.3, dayWidth: dayWidth) == start)
        #expect(WeekStripPaging.restingOffset(start: start, proposed: start - page * 0.3, dayWidth: dayWidth) == start)
    }

    @Test("미끄러지는_도중에_잡아도_칸_경계에_멈춘다")
    func 칸_경계() {
        // 102.4칸에서 다시 잡았다 — 102칸에서 출발한 것으로 친다.
        let start = dayWidth * 102.4
        let resting = WeekStripPaging.restingOffset(start: start, proposed: start + page, dayWidth: dayWidth)
        #expect(resting == dayWidth * 109)
        #expect(resting.truncatingRemainder(dividingBy: dayWidth) == 0)
    }

    @Test("창의_맨_앞에서는_음수로_가지_않는다")
    func 맨_앞() {
        #expect(WeekStripPaging.restingOffset(start: 0, proposed: -page, dayWidth: dayWidth) == 0)
    }
}
