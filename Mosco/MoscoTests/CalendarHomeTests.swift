import Foundation
import Testing

/// 1.4.0에서 탭이 사라지며 생긴 길 두 가지 — 위젯으로 들어오면 오늘 페이지,
/// 예전 사용자에게만 한 번 뜨는 "오늘 할 일은 여기로 옮겼어요".
@MainActor
struct CalendarHomeTests {

    // MARK: 위젯으로 들어온 길

    @Test("오늘_할_일_위젯과_라이브_액티비티는_오늘_페이지로_연다")
    func 오늘_페이지로() {
        #expect(WidgetDeepLink.opensTodayPage(kind: "today_todo"))
        #expect(WidgetDeepLink.opensTodayPage(kind: WidgetDeepLink.liveActivityKind))
    }

    @Test("달력_위젯은_달력_홈으로_들어온다")
    func 달력_홈으로() {
        #expect(!WidgetDeepLink.opensTodayPage(kind: "month_calendar"))
        #expect(!WidgetDeepLink.opensTodayPage(kind: "week_calendar"))
    }

    // MARK: 업데이트 안내

    @Test("예전_버전에서_안내에_답한_사람에게는_한_번_띄운다")
    func 예전_사용자() {
        #expect(CalendarHomeNotice.decide(current: "", answeredTutorialBefore: true) == CalendarHomeNotice.pending)
    }

    @Test("처음_깐_사람에게는_띄우지_않는다_튜토리얼이_같은_걸_가르친다")
    func 처음_온_사람() {
        #expect(CalendarHomeNotice.decide(current: "", answeredTutorialBefore: false) == CalendarHomeNotice.done)
    }

    @Test("한_번_정하면_다음_실행에서_다시_정하지_않는다")
    func 다시_안_정한다() {
        // 처음 깐 사람이 튜토리얼에 답한 뒤 다시 켜도 예전 사용자로 바뀌지 않는다.
        #expect(CalendarHomeNotice.decide(current: CalendarHomeNotice.done, answeredTutorialBefore: true) == CalendarHomeNotice.done)
        #expect(CalendarHomeNotice.decide(current: CalendarHomeNotice.pending, answeredTutorialBefore: true) == CalendarHomeNotice.pending)
    }
}
