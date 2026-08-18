import Foundation
import Testing

/// 자연어 시각 파싱 — R7 표의 네 번째 줄.
/// "`4시~7시`의 종료 시각 · 오전/오후 해석"이 반복해서 깨진 자리다.
/// 이 로직은 2026-08-18까지 `QuickAddView`의 `private static`이라 테스트가
/// 한 줄도 닿지 못했다. 꺼낸 뒤 처음 덮는다.
@Suite("시각 파싱")
struct TimeExpressionParserTests {

    private func suggestion(_ text: String) -> TimeSuggestion? {
        TimeExpressionParser.suggestion(in: text)
    }

    // MARK: 단일 시각

    @Test("N시는_오전오후가_모호한_채로_남는다")
    func 모호한_단일() throws {
        let s = try #require(suggestion("7시 러닝"))
        #expect(s.startHour12 == 7)
        #expect(s.startHour24 == nil, "물어보지도 않고 오전/오후를 정해버렸다")
        #expect(s.startMinute == 0)
        #expect(s.endHour12 == nil)
    }

    @Test("오후_N시는_24시간제로_확정된다")
    func 오후_확정() throws {
        let s = try #require(suggestion("오후 7시 미팅"))
        #expect(s.startHour24 == 19)
        #expect(s.startHour12 == nil)
    }

    @Test("오전_N시는_그대로_확정된다")
    func 오전_확정() throws {
        #expect(try #require(suggestion("오전 9시 회의")).startHour24 == 9)
    }

    @Test("시_반은_30분이다")
    func 반() throws {
        let s = try #require(suggestion("7시 반 약속"))
        #expect(s.startMinute == 30)
    }

    @Test("N분이_분으로_잡힌다")
    func 분() throws {
        #expect(try #require(suggestion("오후 3시 45분 진료")).startMinute == 45)
    }

    // MARK: 12시 — 가장 틀리기 쉬운 자리

    @Test("오후_12시는_자정이_아니라_정오다")
    func 오후_12시() throws {
        #expect(try #require(suggestion("오후 12시 점심")).startHour24 == 12)
    }

    @Test("오전_12시는_자정이다")
    func 오전_12시() throws {
        #expect(try #require(suggestion("오전 12시 마감")).startHour24 == 0)
    }

    @Test("hour12를_오전오후로_확정할_때_12시가_뒤집히지_않는다")
    func 확정_함수의_12시() {
        #expect(TimeExpressionParser.resolvedHour24(hour12: 12, isPM: true) == 12)
        #expect(TimeExpressionParser.resolvedHour24(hour12: 12, isPM: false) == 0)
        #expect(TimeExpressionParser.resolvedHour24(hour12: 7, isPM: true) == 19)
        #expect(TimeExpressionParser.resolvedHour24(hour12: 7, isPM: false) == 7)
    }

    // MARK: 범위 — 종료 시각이 잡히는가

    @Test("4시_물결_7시에서_종료_시각이_잡힌다")
    func 물결_범위() throws {
        let s = try #require(suggestion("4시~7시 스터디"))
        #expect(s.startHour12 == 4)
        #expect(s.endHour12 == 7, "종료 시각이 통째로 사라졌다")
        #expect(s.endMinute == 0)
    }

    @Test("붙임표_범위도_잡힌다")
    func 붙임표_범위() throws {
        let s = try #require(suggestion("4시-7시 스터디"))
        #expect(s.startHour12 == 4)
        #expect(s.endHour12 == 7)
    }

    @Test("콜론_표기_범위의_종료가_잡힌다")
    func 콜론_범위() throws {
        let s = try #require(suggestion("14:00-19:30 워크숍"))
        #expect(s.startHour24 == 14)
        #expect(s.endHour24 == 19)
        #expect(s.endMinute == 30)
    }

    @Test("영문_오전오후_범위가_잡힌다")
    func 영문_범위() throws {
        let s = try #require(suggestion("2pm~5pm 회의"))
        #expect(s.startHour24 == 14)
        #expect(s.endHour24 == 17)
    }

    @Test("사이에_다른_말이_끼면_범위가_아니다")
    func 범위_아님() throws {
        let s = try #require(suggestion("7시 기상 9시 출근"))
        #expect(s.endHour12 == nil, "떨어져 있는 두 시각을 범위로 붙였다")
    }

    // MARK: 중복 매칭

    @Test("오후_7시가_N시_패턴에_중복으로_안_잡힌다")
    func 중복_매칭() {
        let tokens = TimeExpressionParser.tokens(in: "오후 7시 미팅")
        #expect(tokens.count == 1, "같은 자리를 두 패턴이 각각 잡았다: \(tokens.count)개")
        #expect(tokens[0].hour24 == 19)
    }

    @Test("범위_표현은_토큰_두_개다")
    func 범위_토큰수() {
        #expect(TimeExpressionParser.tokens(in: "4시~7시").count == 2)
    }

    // MARK: 시각이 없을 때

    @Test("시각이_없으면_아무것도_제안하지_않는다", arguments: [
        "장보기", "우유 사기", "운동", "",
    ])
    func 시각_없음(text: String) {
        #expect(suggestion(text) == nil, "\"\(text)\"에서 없는 시각을 만들어냈다")
    }

    @Test("범위를_벗어난_숫자는_시각이_아니다", arguments: ["25시 회의", "99시"])
    func 범위_밖(text: String) {
        #expect(suggestion(text) == nil)
    }

    @Test("잘못된_분은_시각이_아니다")
    func 잘못된_분() {
        #expect(suggestion("12:70 회의") == nil)
    }

    // MARK: 제목에서 빼낼 구간

    @Test("matched가_제목에서_실제로_빼낼_구간이다")
    func matched_구간() throws {
        #expect(try #require(suggestion("오후 7시 미팅")).matched == "오후 7시")
        #expect(try #require(suggestion("4시~7시 스터디")).matched == "4시~7시")
    }

    // MARK: 분 파싱

    @Test("분_표기가_숫자로_바뀐다")
    func 분_파싱() {
        #expect(TimeExpressionParser.parseMinute(nil) == 0)
        #expect(TimeExpressionParser.parseMinute("반") == 30)
        #expect(TimeExpressionParser.parseMinute("45분") == 45)
        #expect(TimeExpressionParser.parseMinute("5 분") == 5)
    }

    // MARK: 표기

    @Test("한국어_시각_표기가_12시간제로_나온다")
    func 표기() {
        #expect(TimeExpressionParser.koreanTimeLabel(hour24: 19, minute: 0) == "오후 7시")
        #expect(TimeExpressionParser.koreanTimeLabel(hour24: 19, minute: 30) == "오후 7시 30분")
        #expect(TimeExpressionParser.koreanTimeLabel(hour24: 0, minute: 0) == "오전 12시")
        #expect(TimeExpressionParser.koreanTimeLabel(hour24: 12, minute: 0) == "오후 12시")
        #expect(TimeExpressionParser.koreanTimeLabel(hour24: 9, minute: 5) == "오전 9시 5분")
    }
}
