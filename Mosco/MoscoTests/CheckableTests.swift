import Foundation
import SwiftData
import Testing

/// **완료라는 개념이 없는 일**(생일·월급날)이 어디에 서고 어디서 빠지는가.
///
/// 규칙 자체는 깃발 하나인데(`TodoItem.isCheckable`), **빠져야 하는 자리가 여러
/// 군데**라 한 곳만 고치면 "생일 때문에 오늘이 바빠 보인다" 같은 식으로 조용히
/// 어긋난다. 그 자리들을 한데 묶어둔다.
@Suite("완료 없는 일")
@MainActor
struct CheckableTests {

    private let container: ModelContainer
    private var context: ModelContext { container.mainContext }
    private let calendar = TestCalendar.korea
    private let today = day("2026-10-09")

    init() throws {
        container = try SharedModelContainer.inMemory()
    }

    @discardableResult
    private func make(
        _ title: String,
        date: Date?,
        checkable: Bool = true,
        repeats: RepeatRule = .none,
        isDDay: Bool = false
    ) -> TodoItem {
        let todo = TodoItem(title: title, date: date)
        todo.isCheckable = checkable
        todo.repeatRule = repeats
        todo.isDDay = isDDay
        context.insert(todo)
        return todo
    }

    // MARK: 어디서 빠지나

    /// 할 일 탭은 "무엇부터"에 답하는 화면이다. 할 게 없는 항목이 설 자리가 없고,
    /// 두면 완료할 수 없으니 '지난 할 일' 칸에 영영 쌓인다.
    @Test("할_일_탭에는_안_선다")
    func 할_일_탭() {
        let birthday = make("생일", date: today, checkable: false)
        #expect(TodoListPage.section(for: birthday, today: today, calendar: calendar) == nil)

        // 지난 날짜여도 마찬가지다 — 여기가 원래 쌓이던 자리다.
        let lastMonth = make("지난 월급날", date: day("2026-09-25"), checkable: false)
        #expect(TodoListPage.section(for: lastMonth, today: today, calendar: calendar) == nil)
    }

    @Test("오늘_남은_개수에_안_들어간다")
    func 남은_개수() {
        let work = make("보고서", date: today)
        let payday = make("월급날", date: today, checkable: false)
        #expect(work.countsAsRemaining(on: today))
        #expect(!payday.countsAsRemaining(on: today))

        let progress = TodayPage.progress(in: [work, payday], today: today)
        #expect(progress.total == 1, "생일·월급날은 분모에도 안 들어간다")
        #expect(progress.remaining == 1)
    }

    /// 다 끝낸 날에도 '남은 것'이 하나로 남으면 하루 마무리 알림이 매일 온다.
    @Test("하루_마무리_알림의_남은_것에서_빠진다")
    func 하루_마무리() {
        let payday = TodoSnapshot(
            title: "월급날", start: today, end: today, isCheckable: false
        )
        let remaining = DailySummaryPlan.remainingCount(
            in: [payday], backlogCount: 0, on: today, calendar: calendar
        )
        #expect(remaining == 0)
    }

    /// 스트립의 점은 "할 일이 남았나"를 말한다. 생일만 있는 날은 **옅은 점**이다 —
    /// 뭔가 있긴 하지만 할 일은 아니다.
    @Test("스트립_점은_남은_일로_치지_않는다")
    func 스트립_점() {
        make("생일", date: today, checkable: false)
        let todos = (try? context.fetch(FetchDescriptor<TodoItem>())) ?? []
        #expect(DayTodoMark.mark(for: today, in: todos) == .done)

        make("보고서", date: today)
        let withWork = (try? context.fetch(FetchDescriptor<TodoItem>())) ?? []
        #expect(DayTodoMark.mark(for: today, in: withWork) == .open)
    }

    // MARK: 어디에 남나

    /// 달력은 "언제"에 답하는 화면이라 생일이야말로 거기 있어야 한다. 완료 개념이
    /// 없으니 흐려지거나 취소선이 붙지도 않는다.
    @Test("달력에는_그대로_남고_완료로_안_보인다")
    func 달력() {
        let birthday = make("생일", date: today, checkable: false)
        #expect(birthday.occurs(on: today))
        #expect(!birthday.isCompleted(on: today))
    }

    /// 디데이 카드는 "며칠 남았나"를 센다 — 생일이 가장 잘 맞는 자리다.
    @Test("디데이_카드에는_선다")
    func 디데이() {
        let birthday = make("생일", date: day("2026-10-20"), checkable: false, isDDay: true)
        let cards = TodoListPage.dDays(in: [birthday], today: today, calendar: calendar)
        #expect(cards.map(\.title) == ["생일"])
    }

    // MARK: 기록을 남기지 않는다

    /// 위젯 버튼·라이브 액티비티처럼 화면 밖에서 들어오는 길이 여럿이라,
    /// 막는 자리는 화면이 아니라 모델이어야 한다.
    @Test("완료를_기록하지_않는다")
    func 기록_없음() {
        let birthday = make("생일", date: today, checkable: false, repeats: .yearly)
        birthday.setCompleted(true, on: today)
        #expect(!birthday.isCompleted(on: today))
        #expect(birthday.completedDayKeys == nil)
    }

    /// 체크를 켜고 끄는 사이에 상태가 꼬이지 않아야 한다.
    @Test("다시_켜면_원래대로_돌아온다")
    func 되돌리기() {
        let todo = make("보고서", date: today)
        todo.setCompleted(true, on: today)
        #expect(todo.isCompleted(on: today))

        todo.isCheckable = false
        #expect(TodoListPage.section(for: todo, today: today, calendar: calendar) == nil)

        todo.isCheckable = true
        #expect(todo.isCompleted(on: today), "완료 기록은 지우지 않고 무시만 한다")
    }

    // MARK: 카테고리가 정한다

    /// **적는 순간에 아무것도 더 안 해도 되는 것**이 이 설정을 카테고리에 둔
    /// 값어치다 — 제목을 보고 분류기가 '기념일'을 고르면 체크도 같이 빠진다.
    @Test("카테고리에_넣으면_그_설정을_따라간다")
    func 카테고리_기본값() {
        let 기념일 = TodoCategory(name: "기념일", colorHex: "EF4444", sortOrder: 1)
        기념일.givesCompletionCheck = false
        context.insert(기념일)

        let todo = TodoItem(title: "어머니 생신", date: today)
        todo.category = 기념일
        todo.isCheckable = 기념일.givesCompletionCheck
        context.insert(todo)

        #expect(!todo.isCheckable)
        #expect(TodoListPage.section(for: todo, today: today, calendar: calendar) == nil)
    }

    /// 카테고리 설정을 바꾸면 **이미 들어 있는 할 일에도 지금 적용된다.** 안 하면
    /// 같은 카테고리인데 줄마다 체크가 있고 없고 해서 규칙이 안 읽힌다.
    @Test("카테고리_설정을_바꾸면_이미_든_할_일도_따라온다")
    func 카테고리_소급() {
        let 기념일 = TodoCategory(name: "기념일", colorHex: "EF4444", sortOrder: 1)
        context.insert(기념일)
        let 생일 = TodoItem(title: "생일", date: today)
        생일.category = 기념일
        context.insert(생일)
        #expect(생일.isCheckable)

        기념일.givesCompletionCheck = false
        TodoCategory.applyCompletionCheck(of: 기념일, in: context)
        #expect(!생일.isCheckable)

        // 다시 켜면 돌아온다 — 완료 기록도 지우지 않았다.
        기념일.givesCompletionCheck = true
        TodoCategory.applyCompletionCheck(of: 기념일, in: context)
        #expect(생일.isCheckable)
    }

    /// 다른 카테고리의 할 일까지 바꾸면 안 된다.
    @Test("다른_카테고리는_건드리지_않는다")
    func 카테고리_범위() {
        let 기념일 = TodoCategory(name: "기념일", colorHex: "EF4444", sortOrder: 1)
        let 일 = TodoCategory(name: "일", colorHex: "3B82F6", sortOrder: 2)
        context.insert(기념일)
        context.insert(일)
        let 생일 = TodoItem(title: "생일", date: today)
        생일.category = 기념일
        let 회의 = TodoItem(title: "회의", date: today)
        회의.category = 일
        context.insert(생일)
        context.insert(회의)

        기념일.givesCompletionCheck = false
        TodoCategory.applyCompletionCheck(of: 기념일, in: context)
        #expect(!생일.isCheckable)
        #expect(회의.isCheckable, "다른 카테고리의 할 일은 그대로다")
    }
}
