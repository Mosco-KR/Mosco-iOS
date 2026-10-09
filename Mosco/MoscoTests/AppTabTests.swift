import Foundation
import Testing

/// 탭 셋(달력·오늘·할 일)과, 앱 밖에서 들어오는 길이 어느 탭에 서는지.
///
/// 1.4.0에서 두 탭을 하나로 합쳤다가 다시 나눴다. 되돌리면서도 **첫 탭은 달력으로
/// 둔다** — 열자마자 일정을 확인하는 게 이 앱을 여는 이유라서, 그 판단만은 그대로
/// 가져간다. 그 약속을 테스트로 묶어둔다.
@MainActor
struct AppTabTests {

    // MARK: 어느 탭으로 여나

    @Test("앱을_열면_달력_탭이다")
    func 첫_탭() {
        #expect(AppTab.initial == .calendar)
    }

    /// 순서가 뜻을 만든다 — **언제 · 지금 · 전부**로 읽혀야 한다.
    @Test("탭은_셋이고_달력_오늘_할_일_순이다")
    func 탭_개수() {
        #expect(AppTab.allCases == [.calendar, .today, .todos])
    }

    // MARK: 위젯으로 들어온 길

    @Test("오늘_할_일_위젯과_라이브_액티비티는_오늘_탭에_선다")
    func 오늘_탭으로() {
        #expect(AppTab.destination(forWidgetKind: "today_todo") == .today)
        #expect(AppTab.destination(forWidgetKind: WidgetDeepLink.liveActivityKind) == .today)
        #expect(WidgetDeepLink.opensTodayPage(kind: "today_todo"))
    }

    @Test("달력_위젯은_달력_탭에_선다")
    func 달력_탭으로() {
        #expect(AppTab.destination(forWidgetKind: "month_calendar") == .calendar)
        #expect(AppTab.destination(forWidgetKind: "week_calendar") == .calendar)
    }

    // MARK: 탭이 로그에 남는 이름

    /// 두 탭이 같은 이름으로 남으면 "되살린 탭이 쓰이는가"에 답할 수 없다.
    @Test("탭마다_다른_화면_이름으로_남는다")
    func 탭_이름() {
        #expect(AppTab.calendar.screen == .calendar)
        #expect(AppTab.today.screen == .today)
        #expect(AppTab.todos.screen == .todos)
        #expect(Set(AppTab.allCases.map(\.screen)).count == AppTab.allCases.count)
    }

    /// 오늘 탭과 달력에서 눌러 들어온 하루 페이지는 **같은 화면**인데 이름이 다르다.
    /// 그래야 탭을 둘로 나눈 판단을 채점할 수 있다.
    @Test("오늘_탭과_밀려_들어온_하루_페이지는_이름이_다르다")
    func 오늘과_하루() {
        #expect(AnalyticsScreen.today.rawValue == "today")
        #expect(AnalyticsScreen.day.rawValue == "day")
    }

    // MARK: 구조를 재는 이벤트

    @Test("하루_페이지_열기_이벤트는_어디서_왔는지와_오늘인지를_싣는다")
    func 하루_열기() {
        let event = AnalyticsEvent.dayOpened(from: "widget", isToday: true)
        #expect(event.name == "day_opened")
        #expect(event.parameters == ["from": "widget", "is_today": "true"])
    }

    @Test("검색_닫기_이벤트는_결과를_골랐는지만_싣는다")
    func 검색_닫기() {
        let event = AnalyticsEvent.searchClosed(openedResult: false)
        #expect(event.name == "search_closed")
        #expect(event.parameters == ["opened_result": "false"])
    }
}
