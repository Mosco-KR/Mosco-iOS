import Foundation
import SwiftData
import Testing

/// **모델 쪽 반복 판정.** `RecurrenceTests`는 `TodoSnapshot`(값 사본)을 덮고 있는데,
/// 앱 화면·알림 스케줄러·위젯이 실제로 부르는 것은 이쪽 `TodoItem` 확장이다.
/// 두 구현이 같아야 한다고 `TodoSnapshot`의 주석이 말하는데 이쪽은 한 줄도 안
/// 덮여 있었다 (2026-08-22).
///
/// 모델 인스턴스가 필요해서 그동안 테스트를 쓸 수 없었다.
/// `SharedModelContainer.inMemory()`가 그 자리를 열었다.
///
/// **날짜는 `Calendar.current`로 만든다.** 모델 쪽 구현이 `Calendar.current`를
/// 직접 쓰기 때문이다(주입할 자리가 없다). 다른 달력으로 날짜를 만들면 시간대에
/// 따라 하루가 밀린다 — 그 자체가 나중에 뽑아낼 이유이기도 하다.
@MainActor
struct TodoItemRecurrenceTests {

    /// **컨테이너를 붙들고 있어야 한다.** `inMemory().mainContext`만 받아두면
    /// 컨테이너가 곧바로 해제되면서 그 컨텍스트를 쓰는 순간 프로세스가 죽는다.
    private let container: ModelContainer
    private var context: ModelContext { container.mainContext }

    init() throws {
        container = try SharedModelContainer.inMemory()
    }

    /// `2026-08-18` 같은 문자열 하나로. 모델과 같은 달력을 쓴다.
    private func d(_ text: String) -> Date {
        let parts = text.split(separator: "-").compactMap { Int($0) }
        var components = DateComponents()
        components.year = parts[0]; components.month = parts[1]; components.day = parts[2]
        return Calendar.current.date(from: components)!
    }

    private func make(
        _ context: ModelContext,
        date: Date? = nil,
        endDate: Date? = nil,
        rule: RepeatRule = .none,
        repeatEnd: Date? = nil,
        weekdays: [Int] = [],
        interval: Int? = nil
    ) -> TodoItem {
        let todo = TodoItem(
            title: "테스트",
            date: date,
            endDate: endDate,
            repeatRule: rule,
            repeatEndDate: repeatEnd,
            repeatWeekdays: weekdays,
            repeatInterval: interval
        )
        context.insert(todo)
        return todo
    }

    @Test("날짜가_없으면_어떤_날에도_안_걸친다")
    func 백로그() {
        let todo = make(context)
        #expect(!todo.occurs(on: d("2026-08-18")))
        #expect(todo.occurrenceStart(covering: d("2026-08-18")) == nil)
    }

    @Test("하루짜리는_그날만_걸친다")
    func 하루() {
        let todo = make(context, date: d("2026-08-18"))
        #expect(todo.occurs(on: d("2026-08-18")))
        #expect(!todo.occurs(on: d("2026-08-17")))
        #expect(!todo.occurs(on: d("2026-08-19")))
    }

    @Test("걸친_일정은_사이_날에도_걸친다")
    func 멀티데이() {
        let todo = make(context, date: d("2026-08-18"), endDate: d("2026-08-20"))
        #expect(todo.durationDays == 2)
        for day in ["2026-08-18", "2026-08-19", "2026-08-20"] {
            #expect(todo.occurs(on: d(day)), "\(day)에 걸쳐야 한다")
        }
        #expect(!todo.occurs(on: d("2026-08-21")))
    }

    @Test("매일_반복은_다음_날에도_걸친다")
    func 매일() {
        let todo = make(context, date: d("2026-08-18"), rule: .daily)
        #expect(todo.occurs(on: d("2026-08-19")))
        #expect(todo.occurs(on: d("2026-08-25")))
        #expect(!todo.occurs(on: d("2026-08-17")), "시작일 이전은 안 걸친다")
    }

    @Test("반복_종료일_뒤로는_안_걸친다")
    func 반복_종료() {
        let todo = make(
            context, date: d("2026-08-18"), rule: .daily, repeatEnd: d("2026-08-20")
        )
        #expect(todo.occurs(on: d("2026-08-20")))
        #expect(!todo.occurs(on: d("2026-08-21")))
    }

    /// 이 프로젝트에서 실제로 났던 버그다 — 하루를 완료했더니 전체가 완료로 보였다.
    @Test("하루_완료가_다른_날로_번지지_않는다")
    func 하루만_완료() {
        let todo = make(context, date: d("2026-08-18"), rule: .daily)

        todo.setCompleted(true, on: d("2026-08-19"))

        #expect(todo.isCompleted(on: d("2026-08-19")))
        #expect(!todo.isCompleted(on: d("2026-08-20")), "다른 날까지 완료되면 안 된다")
        #expect(!todo.isCompleted(on: d("2026-08-18")), "원본 날짜도 그대로여야 한다")
    }

    @Test("완료를_풀면_그날만_풀린다")
    func 완료_해제() {
        let todo = make(context, date: d("2026-08-18"), rule: .daily)
        todo.setCompleted(true, on: d("2026-08-19"))
        todo.setCompleted(true, on: d("2026-08-20"))

        todo.setCompleted(false, on: d("2026-08-19"))

        #expect(!todo.isCompleted(on: d("2026-08-19")))
        #expect(todo.isCompleted(on: d("2026-08-20")), "다른 날은 그대로")
    }

    @Test("반복이_아니면_완료는_전체_완료다")
    func 단발_완료() {
        let todo = make(context, date: d("2026-08-18"))
        todo.setCompleted(true, on: d("2026-08-18"))
        #expect(todo.isCompleted)
        #expect(todo.isCompleted(on: d("2026-08-18")))
    }

    @Test("같은_날을_두_번_완료해도_기록이_하나다")
    func 중복_기록() {
        let todo = make(context, date: d("2026-08-18"), rule: .daily)
        todo.setCompleted(true, on: d("2026-08-19"))
        todo.setCompleted(true, on: d("2026-08-19"))
        #expect((todo.completedDayKeys ?? []).count == 1)
    }

    @Test("걸친_반복은_인스턴스_시작일을_돌려준다")
    func 걸친_반복의_시작일() {
        // 3일짜리가 매주 반복 — 다음 주 둘째 날을 물어보면 그 주의 시작일이 나와야 한다.
        let todo = make(
            context, date: d("2026-08-18"), endDate: d("2026-08-20"), rule: .weekly
        )
        let start = todo.occurrenceStart(covering: d("2026-08-26"))
        #expect(start == Calendar.current.startOfDay(for: d("2026-08-25")))
    }
}
