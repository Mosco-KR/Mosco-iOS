import Foundation
import SwiftData
import Testing

/// 오늘 탭의 '지난 할 일'과 '오늘로 가져오기'. 여러 날짜리 할 일에서 두 군데가
/// 깨져 있었다 — 어제 시작해 오늘 끝나는 할 일이 두 번 나왔고, 가져오면 시작일이
/// 오늘로 바뀌었다.
///
/// 모델이 `Calendar.current`를 직접 쓰므로 날짜도 같은 달력으로 만든다
/// (`TodoItemRecurrenceTests`와 같은 이유).
@MainActor
struct TodoItemOverdueTests {

    private let container: ModelContainer
    private var context: ModelContext { container.mainContext }

    init() throws {
        container = try SharedModelContainer.inMemory()
    }

    private func d(_ text: String) -> Date {
        let parts = text.split(separator: "-").compactMap { Int($0) }
        var components = DateComponents()
        components.year = parts[0]; components.month = parts[1]; components.day = parts[2]
        return Calendar.current.date(from: components)!
    }

    private func make(date: Date?, endDate: Date? = nil, rule: RepeatRule = .none) -> TodoItem {
        let todo = TodoItem(title: "테스트", date: date, endDate: endDate, repeatRule: rule)
        context.insert(todo)
        return todo
    }

    private var today: Date { d("2026-10-01") }

    // MARK: 지난 할 일

    @Test("어제_시작해_오늘_끝나는_할_일은_지난_할_일이_아니다")
    func 기간_안이면_지난_게_아니다() {
        let todo = make(date: d("2026-09-30"), endDate: d("2026-10-01"))
        #expect(!todo.isOverdue(today: today), "오늘 할 일과 지난 할 일에 두 번 나온다")
        #expect(todo.occurs(on: today), "오늘 할 일에는 나와야 한다")
    }

    @Test("내일까지_이어지는_할_일도_지난_할_일이_아니다")
    func 내일까지_이어지면_지난_게_아니다() {
        let todo = make(date: d("2026-09-29"), endDate: d("2026-10-02"))
        #expect(!todo.isOverdue(today: today))
    }

    @Test("어제_끝난_여러_날짜리는_지난_할_일이다")
    func 끝난_기간은_지난_것이다() {
        let todo = make(date: d("2026-09-27"), endDate: d("2026-09-30"))
        #expect(todo.isOverdue(today: today))
    }

    @Test("어제_하루짜리는_지난_할_일이다")
    func 하루짜리() {
        #expect(make(date: d("2026-09-30")).isOverdue(today: today))
        #expect(!make(date: d("2026-10-01")).isOverdue(today: today))
    }

    @Test("끝냈거나_반복이거나_날짜가_없으면_지난_할_일이_아니다")
    func 제외되는_것들() {
        let done = make(date: d("2026-09-30"))
        done.isCompleted = true
        #expect(!done.isOverdue(today: today))
        #expect(!make(date: d("2026-09-30"), rule: .daily).isOverdue(today: today))
        #expect(!make(date: nil).isOverdue(today: today))
    }

    // MARK: 오늘로 가져오기

    @Test("여러_날짜리를_가져와도_시작일은_그대로다")
    func 시작일이_안_바뀐다() {
        let todo = make(date: d("2026-09-27"), endDate: d("2026-09-30"))
        todo.pullIntoToday(today)
        #expect(todo.date == d("2026-09-27"), "언제 시작한 일인지가 사라진다")
        #expect(todo.endDate == today)
        #expect(todo.occurs(on: today))
        #expect(!todo.isOverdue(today: today), "가져왔는데 아직 지난 할 일에 남아 있다")
    }

    @Test("하루짜리를_가져오면_오늘_하루짜리가_된다")
    func 하루짜리를_가져온다() {
        let todo = make(date: d("2026-09-28"))
        todo.pullIntoToday(today)
        #expect(todo.date == today)
        #expect(todo.endDate == nil)
        #expect(!todo.isMultiDay)
    }

    @Test("날짜_없는_할_일을_가져오면_오늘_하루짜리가_된다")
    func 백로그를_가져온다() {
        let todo = make(date: nil)
        todo.pullIntoToday(today)
        #expect(todo.date == today)
        #expect(todo.occurs(on: today))
    }
}
