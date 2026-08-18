import Foundation
import Testing

/// 반복 일정 전개 — R7 표의 두 번째 줄.
/// "3일짜리가 생성일에만 보임", "하루 완료가 전체 완료로" 두 증상이 반복해서 나왔다.
@Suite("반복 일정 전개")
struct RecurrenceTests {

    private let calendar = TestCalendar.korea

    private func expand(_ todos: [TodoSnapshot], _ from: String, _ to: String) -> [CalendarEvent] {
        CalendarEventExpander.expand(todos: todos, in: window(from, to), calendar: calendar)
    }

    // MARK: 걸친 날짜

    @Test("사흘짜리가_생성일에만_보이지_않는다")
    func 사흘짜리가_걸친_날_전부에_있다() {
        let todo = TodoSnapshot.spanning("워크숍", from: "2026-08-10", to: "2026-08-12")
        let events = expand([todo], "2026-08-01", "2026-08-31")

        #expect(events.count == 1, "한 번짜리인데 여러 개로 펼쳐졌다")
        let event = events[0]
        #expect(label(event.start) == "2026-08-10")
        #expect(label(event.end) == "2026-08-12", "종료일이 시작일로 접혔다")
    }

    @Test("하루짜리는_시작과_종료가_같다")
    func 하루짜리() {
        let events = expand([.oneDay("치과", on: "2026-08-18")], "2026-08-01", "2026-08-31")
        #expect(events.count == 1)
        #expect(label(events[0].start) == label(events[0].end))
    }

    // MARK: 반복 전개

    @Test("매일_반복이_기간_안의_모든_날에_나온다")
    func 매일_반복() {
        let todo = TodoSnapshot.oneDay(
            "약", on: "2026-08-01", repeatRule: .daily, repeatEndDate: "2026-08-05"
        )
        let starts = Set(expand([todo], "2026-08-01", "2026-08-31").map { label($0.start) })
        #expect(starts == ["2026-08-01", "2026-08-02", "2026-08-03", "2026-08-04", "2026-08-05"])
    }

    @Test("반복_종료일_다음날에는_나오지_않는다")
    func 반복_종료() {
        let todo = TodoSnapshot.oneDay(
            "약", on: "2026-08-01", repeatRule: .daily, repeatEndDate: "2026-08-03"
        )
        let starts = expand([todo], "2026-08-01", "2026-08-31").map { label($0.start) }
        #expect(!starts.contains("2026-08-04"), "종료일을 넘겨서 반복이 이어졌다")
    }

    @Test("며칠마다_반복이_간격을_지킨다")
    func 며칠마다() {
        let todo = TodoSnapshot.oneDay(
            "청소", on: "2026-08-01", repeatRule: .everyNDays,
            repeatEndDate: "2026-08-14", repeatInterval: 3
        )
        let starts = Set(expand([todo], "2026-08-01", "2026-08-31").map { label($0.start) })
        #expect(starts == ["2026-08-01", "2026-08-04", "2026-08-07", "2026-08-10", "2026-08-13"])
    }

    @Test("반복이_아니면_인스턴스가_하나뿐이다")
    func 반복_없음() {
        let events = expand([.oneDay("면접", on: "2026-08-10")], "2026-08-01", "2026-08-31")
        #expect(events.count == 1)
    }

    @Test("이벤트_id는_반복끼리_겹치지_않는다")
    func id_충돌() {
        let todo = TodoSnapshot.oneDay(
            "약", on: "2026-08-01", repeatRule: .daily, repeatEndDate: "2026-08-10"
        )
        let events = expand([todo], "2026-08-01", "2026-08-31")
        #expect(Set(events.map(\.id)).count == events.count, "id가 겹치면 렌더링이 깨진다")
    }

    // MARK: 날짜별 완료

    @Test("하루_완료가_다른_날_완료로_번지지_않는다")
    func 완료가_번지지_않는다() {
        let 완료한날 = day("2026-08-03")
        let todo = TodoSnapshot.oneDay(
            "약", on: "2026-08-01", repeatRule: .daily,
            repeatEndDate: "2026-08-05", completedDayKeys: [완료한날.dayKey]
        )

        #expect(todo.isCompleted(on: day("2026-08-03"), calendar: calendar) == true)
        for 다른날 in ["2026-08-01", "2026-08-02", "2026-08-04", "2026-08-05"] {
            #expect(
                todo.isCompleted(on: day(다른날), calendar: calendar) == false,
                "\(다른날)까지 완료로 번졌다"
            )
        }
    }

    @Test("반복이_아닌_할_일은_전체_완료를_따른다")
    func 단발_완료() {
        let done = TodoSnapshot(
            title: "제출", start: day("2026-08-10"), end: day("2026-08-10"),
            isCompleted: true, createdAt: day("2026-08-10")
        )
        #expect(done.isCompleted(on: day("2026-08-10"), calendar: calendar) == true)
    }

    // MARK: 걸치는 날 판정

    @Test("사흘짜리는_가운데_날도_자기_인스턴스로_친다")
    func 가운데_날() {
        let todo = TodoSnapshot.spanning("워크숍", from: "2026-08-10", to: "2026-08-12")
        for 날 in ["2026-08-10", "2026-08-11", "2026-08-12"] {
            #expect(
                todo.occurrenceStart(covering: day(날), calendar: calendar) != nil,
                "\(날)이 걸친 날로 안 잡힌다"
            )
        }
        #expect(todo.occurrenceStart(covering: day("2026-08-13"), calendar: calendar) == nil)
    }
}
