import Foundation
import Testing

/// 영어·일본어를 붙이면서 생긴 규칙. 화면 문구는 카탈로그가 맡지만, 시각 읽기와
/// 날짜 조립은 코드가 하므로 여기서 세 언어를 다 확인한다.
@Suite("다국어 — 시각 읽기와 날짜 표기")
struct LocalizationTests {

    private func suggestion(_ text: String) -> TimeSuggestion? {
        TimeExpressionParser.suggestion(in: text)
    }

    // MARK: - 영어 입력

    @Test("영어_시각은_분까지_읽는다")
    func 영어_시각() throws {
        #expect(try #require(suggestion("Dinner 7pm")).startHour24 == 19)
        let half = try #require(suggestion("Dinner 7:30 PM"))
        #expect(half.startHour24 == 19 && half.startMinute == 30)
        #expect(half.matched == "7:30 PM")
        #expect(try #require(suggestion("Call 9 a.m.")).startHour24 == 9)
        #expect(try #require(suggestion("Lunch at noon")).startHour24 == 12)
    }

    @Test("am으로_시작하는_낱말은_시각이_아니다")
    func 영어_낱말을_시각으로_읽지_않는다() {
        #expect(suggestion("5 amazing things") == nil)
        #expect(suggestion("3 pmo reviews") == nil)
    }

    @Test("영어_범위는_to로도_잇는다")
    func 영어_범위() throws {
        let range = try #require(suggestion("Meeting 2pm to 5pm"))
        #expect(range.startHour24 == 14 && range.endHour24 == 17)
    }

    // MARK: - 일본어 입력

    @Test("일본어_시각은_午前午後와_24시간제를_다_읽는다")
    func 일본어_시각() throws {
        #expect(try #require(suggestion("ランニング 午後7時")).startHour24 == 19)
        let half = try #require(suggestion("会議 午前9時半"))
        #expect(half.startHour24 == 9 && half.startMinute == 30)
        let evening = try #require(suggestion("夕食 19時30分"))
        #expect(evening.startHour24 == 19 && evening.startMinute == 30)
        // 오전/오후가 없는 12 이하는 한국어의 `7시`처럼 물어봐야 한다.
        let ambiguous = try #require(suggestion("7時 散歩"))
        #expect(ambiguous.startHour24 == nil && ambiguous.startHour12 == 7)
    }

    @Test("전각_숫자도_읽는다")
    func 전각_숫자() throws {
        #expect(try #require(suggestion("午後７時 ランニング")).startHour24 == 19)
    }

    @Test("일본어_범위는_물결표로_잇는다")
    func 일본어_범위() throws {
        let range = try #require(suggestion("会議 14時〜17時"))
        #expect(range.startHour24 == 14 && range.endHour24 == 17)
    }

    // MARK: - 표기

    @Test("시각_표기는_정각이면_분을_뺀다")
    func 시각_표기() {
        #expect(DateText.time(hour24: 19, minute: 0, .ko) == "오후 7시")
        #expect(DateText.time(hour24: 19, minute: 0, .en) == "7 PM")
        #expect(DateText.time(hour24: 19, minute: 5, .en) == "7:05 PM")
        #expect(DateText.time(hour24: 0, minute: 0, .en) == "12 AM")
        #expect(DateText.time(hour24: 19, minute: 0, .ja) == "午後7時")
        #expect(DateText.time(hour24: 9, minute: 30, .ja) == "午前9時30分")
    }

    @Test("날짜_표기")
    func 날짜_표기() {
        #expect(DateText.monthDayWeekday(month: 7, day: 30, weekday: 5, .ko) == "7월 30일 목요일")
        #expect(DateText.monthDayWeekday(month: 7, day: 30, weekday: 5, .en) == "Thu, Jul 30")
        #expect(DateText.monthDayWeekday(month: 7, day: 30, weekday: 5, .ja) == "7月30日(木)")
        #expect(DateText.dayRange(fromMonth: 8, fromDay: 3, toMonth: 8, toDay: 9, .en) == "Aug 3–9")
        #expect(DateText.dayRange(fromMonth: 8, fromDay: 30, toMonth: 9, toDay: 5, .ko) == "8월 30일 – 9월 5일")
        #expect(DateText.yearMonth(year: 2026, month: 8, .ja) == "2026年8月")
    }

    @Test("요일_기호는_언어마다_서로_다르다", arguments: AppLanguage.allCases)
    func 요일_기호가_겹치지_않는다(language: AppLanguage) {
        // 달력 머리가 `id: \.self`로 돌린다 — 겹치면 칸이 사라진다.
        #expect(Set(DateText.weekdaySymbols(language)).count == 7)
    }

    // MARK: - 언어 고르기

    @Test("지원하지_않는_언어는_영어로_보인다")
    func 언어_고르기() {
        let bundle = ["ko", "en", "ja", "Base"]
        #expect(AppLanguage.resolve(bundleLocalizations: bundle, preferred: "ja") == .ja)
        #expect(AppLanguage.resolve(bundleLocalizations: bundle, preferred: "en-GB") == .en)
        #expect(AppLanguage.resolve(bundleLocalizations: bundle, preferred: "fr") == .en)
        // 번들에 한국어가 없으면 테스트 러너다 — 원문 언어로 둔다.
        #expect(AppLanguage.resolve(bundleLocalizations: ["en"], preferred: "en") == .ko)
    }
}

@Suite("다국어 — 주의 시작")
struct WeekStartTests {
    /// 월요일부터 세는 지역(프랑스)의 달력을 넣어도 달력 줄은 일요일에서 시작해야 한다.
    /// 요일 머리가 일~토로 고정이라, 어긋나면 한 칸씩 밀린 달력이 된다.
    @Test("월요일_시작_지역에서도_달력_줄은_일요일부터다")
    func 달력_줄은_일요일부터() throws {
        var french = Calendar(identifier: .gregorian)
        french.locale = Locale(identifier: "fr_FR")
        french.timeZone = TimeZone(identifier: "Europe/Paris")!
        french.firstWeekday = 2

        let layout = MonthLayout.make(CalendarMonth(year: 2026, month: 10), calendar: french)
        for week in layout.weeks {
            let first = try #require(week.dates.first)
            #expect(french.component(.weekday, from: first) == 1)
            #expect(week.dates.count == 7)
        }
    }
}
