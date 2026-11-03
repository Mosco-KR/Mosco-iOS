import Foundation
import Testing

/// 한 줄에서 날짜를 읽어내는 규칙.
///
/// 시각 파싱(`TimeExpressionParserTests`)과 같은 자리의 일인데, 이쪽이 더 위험하다 —
/// 시각을 잘못 읽으면 그날 안에서 틀리지만, 날짜를 잘못 읽으면 **할 일이 다른 날로
/// 사라진다.** 그래서 "읽는 것"보다 **"안 읽는 것"을 더 많이 묶어둔다.**
@Suite("날짜 파싱")
struct DateExpressionParserTests {

    /// 2026-10-25는 일요일이다.
    private let today: Date = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = .current
        return Calendar.current.startOfDay(for: formatter.date(from: "2026-10-25")!)
    }()

    private func day(_ string: String) -> Date {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = .current
        return Calendar.current.startOfDay(for: formatter.date(from: string)!)
    }

    private func parse(_ text: String) -> DateSuggestion? {
        DateExpressionParser.suggestion(in: text, today: today)
    }

    // MARK: 오늘·내일·모레

    @Test func 내일을_읽는다() {
        let found = parse("내일 장보기")
        #expect(found?.date == day("2026-10-26"))
        #expect(found?.matched == "내일")
    }

    @Test func 오늘과_모레와_글피() {
        #expect(parse("오늘 마감")?.date == day("2026-10-25"))
        #expect(parse("모레 치과")?.date == day("2026-10-27"))
        #expect(parse("글피 발표")?.date == day("2026-10-28"))
    }

    // MARK: 요일

    /// 일요일에 적은 "금요일"은 다가오는 금요일(10/30)이다.
    @Test func 요일만_적으면_다가오는_그_요일이다() {
        #expect(parse("금요일 회의")?.date == day("2026-10-30"))
    }

    /// 오늘과 같은 요일이면 오늘로 본다 — 일요일에 "일요일에 하기"라고 적었다면
    /// 그건 오늘 이야기다.
    @Test func 오늘과_같은_요일이면_오늘이다() {
        #expect(parse("일요일 대청소")?.date == day("2026-10-25"))
    }

    @Test func 다음_주_요일은_한_주_뒤다() {
        #expect(parse("다음 주 금요일 회식")?.date == day("2026-11-06"))
        #expect(parse("담주 월요일 보고")?.date == day("2026-11-02"))
    }

    /// 긴 말을 먼저 읽어야 한다 — "금요일"만 떼어 읽으면 이번 주로 잘못 간다.
    @Test func 다음_주_금요일에서_금요일만_떼지_않는다() {
        let found = parse("다음 주 금요일 회식")
        #expect(found?.matched == "다음 주 금요일")
    }

    // MARK: 숫자로 적은 날짜

    @Test func 월과_일을_읽는다() {
        #expect(parse("10월 28일 발표")?.date == day("2026-10-28"))
    }

    /// 이미 지난 날짜는 내년으로 읽는다 — 10월에 적은 "3월 2일"은 내년 3월이다.
    @Test func 지난_날짜는_내년이다() {
        #expect(parse("3월 2일 등록")?.date == day("2027-03-02"))
    }

    @Test func 일만_적으면_이번_달_그_날이다() {
        #expect(parse("28일 관리비")?.date == day("2026-10-28"))
    }

    /// 이번 달에서 이미 지났으면 다음 달로 읽는다.
    @Test func 지난_날이면_다음_달이다() {
        #expect(parse("3일 모임")?.date == day("2026-11-03"))
    }

    @Test func 빗금으로_적은_날짜() {
        #expect(parse("10/28 발표")?.date == day("2026-10-28"))
    }

    // MARK: 안 읽는 것

    @Test func 날짜가_없으면_아무것도_안_읽는다() {
        #expect(parse("장보기") == nil)
        #expect(parse("팀 회의 자료 만들기") == nil)
    }

    /// 흐릿한 말은 일부러 안 다룬다 — 틀리게 읽느니 사람이 칩을 눌러 고르는 편이 낫다.
    @Test func 흐릿한_말은_안_읽는다() {
        #expect(parse("언젠가 책 정리") == nil)
        #expect(parse("주말에 등산") == nil)
        #expect(parse("다음 달쯤 예약") == nil)
    }

    /// 달이 될 수 없는 숫자는 날짜가 아니다.
    @Test func 말이_안_되는_숫자는_안_읽는다() {
        #expect(parse("13월 1일 회의") == nil)
        #expect(parse("99/99 어쩌고") == nil)
    }

    /// 시각은 시각 쪽이 맡는다 — "7시"를 날짜로 읽으면 안 된다.
    @Test func 시각을_날짜로_읽지_않는다() {
        #expect(parse("저녁 약속 오후 7시") == nil)
    }
}
