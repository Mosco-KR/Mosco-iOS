import Foundation
import Testing

/// 탭 둘(달력·할 일)과, 구조를 재는 이벤트들.
///
/// 탭은 하나 → 둘 → 셋 → 둘로 움직였다. 그때마다 바뀌지 **않은** 것이 하나 있다 —
/// **첫 탭은 달력이다.** 열자마자 일정을 확인하는 게 이 앱을 여는 이유라서,
/// 그 판단만은 그대로 가져간다. 그 약속을 테스트로 묶어둔다.
@MainActor
struct AppTabTests {

    // MARK: 어느 탭으로 여나

    @Test("앱을_열면_달력_탭이다")
    func 첫_탭() {
        #expect(AppTab.initial == .calendar)
    }

    /// 순서가 뜻을 만든다 — **언제 · 무엇부터**로 읽혀야 한다.
    @Test("탭은_둘이고_달력_할_일_순이다")
    func 탭_개수() {
        #expect(AppTab.allCases == [.calendar, .todos])
    }

    // MARK: 위젯으로 들어온 길

    /// 오늘 탭이 없어진 뒤로 이 둘은 달력이 하루 페이지를 **밀어서** 연다
    /// (`CalendarScreen`). 달력 위젯은 그냥 달력에 선다.
    @Test("오늘_할_일_위젯과_라이브_액티비티만_하루_페이지를_연다")
    func 하루_페이지로() {
        #expect(WidgetDeepLink.opensTodayPage(kind: "today_todo"))
        #expect(WidgetDeepLink.opensTodayPage(kind: WidgetDeepLink.liveActivityKind))
        #expect(!WidgetDeepLink.opensTodayPage(kind: "month_calendar"))
        #expect(!WidgetDeepLink.opensTodayPage(kind: "week_calendar"))
    }

    // MARK: 탭이 로그에 남는 이름

    @Test("탭마다_다른_화면_이름으로_남는다")
    func 탭_이름() {
        #expect(AppTab.calendar.screen == .calendar)
        #expect(AppTab.todos.screen == .todos)
        #expect(Set(AppTab.allCases.map(\.screen)).count == AppTab.allCases.count)
    }

    /// 하루 페이지는 탭이 아니다 — 달력에서 밀려 들어온다. 탭 이름과 섞이면
    /// "탭을 쓰는가"와 "날짜를 눌러 들어오는가"를 못 가른다.
    @Test("하루_페이지는_탭과_다른_이름으로_남는다")
    func 하루_페이지_이름() {
        #expect(AnalyticsScreen.day.rawValue == "day")
        #expect(!AppTab.allCases.map(\.screen).contains(.day))
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
