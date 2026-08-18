import Foundation
import Testing
@testable import App

/// 블록 배치 — R7 표의 세 번째 줄.
/// "날짜 아래부터 안 쌓임 · 빈 줄 · 옆으로 밀림"이 반복해서 나온 곳이다.
@Suite("블록 행 배정")
struct EventRowAssignerTests {

    private func event(
        _ id: String, _ start: String, _ end: String? = nil, created: String? = nil
    ) -> CalendarEvent {
        CalendarEvent(
            id: id,
            title: id,
            categoryColorHex: nil,
            calendarColorHex: nil,
            isRepeating: false,
            start: day(start),
            end: day(end ?? start),
            isCompleted: false,
            createdAt: day(created ?? start)
        )
    }

    private func rows(_ events: [CalendarEvent]) -> [String: Int] {
        Dictionary(uniqueKeysWithValues: EventRowAssigner.assign(events).map { ($0.event.id, $0.row) })
    }

    @Test("첫_블록은_0행부터_쌓인다")
    func 첫_행() {
        #expect(rows([event("a", "2026-08-10")])["a"] == 0)
    }

    @Test("겹치지_않는_블록은_같은_행을_다시_쓴다")
    func 행_재사용() {
        let assigned = rows([event("a", "2026-08-10"), event("b", "2026-08-12")])
        #expect(assigned["a"] == 0)
        #expect(assigned["b"] == 0, "겹치지도 않는데 아래 행으로 밀렸다")
    }

    @Test("겹치는_블록은_다른_행으로_간다")
    func 겹침() {
        let assigned = rows([event("a", "2026-08-10", "2026-08-12"), event("b", "2026-08-11")])
        #expect(assigned["a"] != assigned["b"], "겹치는데 같은 행에 놓였다")
    }

    @Test("행_번호에_빈_줄이_생기지_않는다")
    func 빈_줄_없음() {
        let assigned = rows([
            event("a", "2026-08-10", "2026-08-14"),
            event("b", "2026-08-11", "2026-08-13"),
            event("c", "2026-08-12"),
        ])
        let used = Set(assigned.values).sorted()
        #expect(used == Array(0...used.count - 1), "행 번호가 건너뛴다: \(used)")
    }

    @Test("먼저_끝난_하루짜리가_다일_일정_때문에_밀리지_않는다")
    func 하루짜리가_안_밀린다() {
        // 7/30에 끝나는 하루짜리는 7/31 시작 다일 일정과 겹치지 않는다.
        let assigned = rows([
            event("다일", "2026-07-31", "2026-08-03"),
            event("하루", "2026-07-30"),
        ])
        #expect(assigned["하루"] == 0, "겹치지 않는 하루짜리가 아래로 밀렸다")
    }

    @Test("같은_날_같은_기간이면_먼저_만든_쪽이_윗행을_지킨다")
    func 생성_순서가_타이브레이커() {
        let assigned = rows([
            event("나중", "2026-08-10", created: "2026-08-09"),
            event("먼저", "2026-08-10", created: "2026-08-01"),
        ])
        #expect(assigned["먼저"]! < assigned["나중"]!, "나중에 만든 할 일이 원래 자리를 뺏었다")
    }

    @Test("같은_날_시작이면_다일_일정이_윗행을_먼저_쓴다")
    func 다일_우선() {
        let assigned = rows([
            event("하루", "2026-08-10"),
            event("다일", "2026-08-10", "2026-08-14"),
        ])
        #expect(assigned["다일"]! < assigned["하루"]!)
    }

    @Test("배정_결과는_입력_순서를_바꿔도_같다")
    func 순서에_흔들리지_않는다() {
        let events = [
            event("a", "2026-08-10", "2026-08-14"),
            event("b", "2026-08-11", "2026-08-13"),
            event("c", "2026-08-16"),
        ]
        #expect(rows(events) == rows(events.reversed()), "입력 순서에 따라 행이 달라진다")
    }

    @Test("빈_입력은_빈_결과다")
    func 빈_입력() {
        #expect(EventRowAssigner.assign([]).isEmpty)
    }
}
