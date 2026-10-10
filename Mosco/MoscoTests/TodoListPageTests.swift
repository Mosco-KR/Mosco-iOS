import Foundation
import SwiftData
import Testing

/// '할 일' 탭이 무엇을 어느 묶음에 넣는가.
///
/// 이 규칙은 눈으로 확인하기 가장 비싼 종류다 — 반복·여러 날짜리·완료가 다
/// 얽히고, 틀렸을 때 "그 할 일이 안 보인다"로만 나타난다. 안 보이는 것은
/// 화면을 아무리 들여다봐도 못 찾는다.
@Suite("할 일 탭 묶음")
@MainActor
struct TodoListPageTests {

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
        end: Date? = nil,
        repeats: RepeatRule = .none,
        completed: Bool = false,
        isDDay: Bool = false
    ) -> TodoItem {
        let todo = TodoItem(title: title, date: date)
        todo.endDate = end
        todo.repeatRule = repeats
        todo.isCompleted = completed
        todo.isDDay = isDDay
        context.insert(todo)
        return todo
    }

    private func section(_ todo: TodoItem) -> TodoListPage.Section? {
        TodoListPage.section(for: todo, today: today, calendar: calendar)
    }

    // MARK: - 어느 묶음에 서나

    @Test("오늘_걸치는_것은_오늘이다")
    func 오늘() {
        #expect(section(make("오늘 일", date: today)) == .today)
    }

    @Test("지난_날의_안_끝낸_일은_지난_것이다")
    func 지난() {
        #expect(section(make("어제 일", date: day("2026-10-08"))) == .overdue)
    }

    @Test("내일부터_이레까지는_이번_주다")
    func 이번_주() {
        #expect(section(make("내일", date: day("2026-10-10"))) == .thisWeek)
        #expect(section(make("이레 뒤", date: day("2026-10-16"))) == .thisWeek)
    }

    @Test("이레를_넘기면_나중이다")
    func 나중() {
        #expect(section(make("여드레 뒤", date: day("2026-10-17"))) == .later)
    }

    @Test("날짜를_안_정한_것은_따로_선다")
    func 날짜_없음() {
        #expect(section(make("언젠가", date: nil)) == .noDate)
    }

    // MARK: - 끝낸 것

    /// 오늘 끝낸 것은 오늘 칸에 남는다. 잘못 누른 것을 되돌릴 자리가 있어야 하고,
    /// 오늘 한 일이 눈에 보이는 편이 낫다.
    @Test("오늘_끝낸_것은_오늘_칸에_남는다")
    func 오늘_완료() {
        #expect(section(make("끝냄", date: today, completed: true)) == .today)
    }

    @Test("끝낸_앞날_일정과_끝낸_백로그는_어디에도_안_선다")
    func 완료는_사라진다() {
        #expect(section(make("다음 주에 끝냄", date: day("2026-10-14"), completed: true)) == nil)
        #expect(section(make("언젠가 끝냄", date: nil, completed: true)) == nil)
    }

    /// `isOverdue`가 끝낸 것을 이미 걸러낸다 — 두 곳에서 같은 판단을 하지 않는지 본다.
    @Test("지난_날의_끝낸_일은_안_선다")
    func 지난_완료() {
        #expect(section(make("어제 끝냄", date: day("2026-10-08"), completed: true)) == nil)
    }

    // MARK: - 반복

    /// **이게 제일 깨지기 쉬운 자리다.** 반복은 "지난 것"이라는 개념이 없어서
    /// `isOverdue`가 false를 내고, 원본 날짜만 보면 과거라 앞날 묶음에도 못 선다.
    /// 다음 회차를 찾지 않으면 목록에서 통째로 사라진다.
    @Test("원본이_과거인_반복은_다음_회차로_묶인다")
    func 반복_다음_회차() {
        // 09-03은 오늘(10-09)과 36일 차이라 요일이 하루 어긋난다 — 회차는
        // 10-08(지남)과 10-15(엿새 뒤)에 선다.
        let weekly = make("매주 회의", date: day("2026-09-03"), repeats: .weekly)
        #expect(section(weekly) == .thisWeek)
    }

    @Test("오늘_걸치는_반복은_오늘이다")
    func 반복_오늘() {
        #expect(section(make("매일 운동", date: day("2026-09-01"), repeats: .daily)) == .today)
    }

    @Test("반복은_지난_것으로_가지_않는다")
    func 반복은_안_지난다() {
        let monthly = make("매월 15일", date: day("2026-08-15"), repeats: .monthly)
        #expect(section(monthly) == .thisWeek, "10-15는 오늘로부터 엿새 뒤다")
    }

    // MARK: - 여러 날짜리

    @Test("오늘을_덮는_여러_날짜리는_오늘이다")
    func 여러_날짜리() {
        let trip = make("여행", date: day("2026-10-07"), end: day("2026-10-11"))
        #expect(section(trip) == .today, "아직 기간 안인 일을 지난 일로 세면 안 된다")
    }

    // MARK: - 순서

    @Test("오늘_칸은_시각순이고_끝낸_것이_아래로_간다")
    func 오늘_정렬() {
        let 저녁 = make("저녁 약속", date: today)
        저녁.startTime = calendar.date(bySettingHour: 19, minute: 0, second: 0, of: today)
        let 아침 = make("아침 회의", date: today)
        아침.startTime = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: today)
        let 끝냄 = make("끝낸 일", date: today, completed: true)
        끝냄.startTime = calendar.date(bySettingHour: 7, minute: 0, second: 0, of: today)

        let sorted = TodoListPage.sort([저녁, 끝냄, 아침], in: .today, today: today, calendar: calendar)

        #expect(sorted.map(\.title) == ["아침 회의", "저녁 약속", "끝낸 일"])
    }

    /// 한때 '나중' 칸에서 디데이를 맨 위로 끌어올렸다. 날짜순을 깨는 예외라
    /// 목록을 읽는 리듬이 끊겼다 — 되돌렸고, 그 약속을 여기서 지킨다.
    @Test("디데이라고_순서를_앞당기지_않는다")
    func 디데이는_순서를_안_바꾼다() {
        let 가까운_것 = make("다음 달 약속", date: day("2026-11-01"))
        let 시험 = make("시험", date: day("2027-01-20"), isDDay: true)

        let sorted = TodoListPage.sort([시험, 가까운_것], in: .later, today: today, calendar: calendar)

        #expect(sorted.map(\.title) == ["다음 달 약속", "시험"], "날짜순이 곧 할 순서다")
    }

    @Test("지난_칸은_오래된_것부터다")
    func 지난_정렬() {
        let 어제 = make("어제", date: day("2026-10-08"))
        let 지난주 = make("지난주", date: day("2026-10-01"))

        let sorted = TodoListPage.sort([어제, 지난주], in: .overdue, today: today, calendar: calendar)

        #expect(sorted.map(\.title) == ["지난주", "어제"])
    }

    // MARK: - 묶음 전체

    @Test("빈_묶음은_돌려주지_않는다")
    func 빈_묶음() {
        make("오늘 일", date: today)
        let todos = (try? context.fetch(FetchDescriptor<TodoItem>())) ?? []

        let sections = TodoListPage.sections(in: todos, today: today, calendar: calendar)

        #expect(sections.map(\.section) == [.today], "화면이 매번 비었는지 따져보지 않아도 되게")
    }

    /// 지난 할 일과 날짜를 안 정한 할 일이 먼저다 — 둘 다 "언제 할지 아직 안
    /// 정해진 것"이라 사람이 손을 대야 움직인다. 그다음이 시간순이다.
    @Test("손이_가야_하는_것이_먼저_오고_그_뒤가_시간순이다")
    func 묶음_순서() {
        make("어제", date: day("2026-10-08"))
        make("오늘", date: today)
        make("모레", date: day("2026-10-11"))
        make("다음 달", date: day("2026-11-20"))
        make("언젠가", date: nil)
        let todos = (try? context.fetch(FetchDescriptor<TodoItem>())) ?? []

        let sections = TodoListPage.sections(in: todos, today: today, calendar: calendar)

        #expect(sections.map(\.section) == [.overdue, .noDate, .today, .thisWeek, .later])
    }

    // MARK: - 디데이 카드

    /// 디데이가 답하는 것은 "며칠 남았나" 하나다. 그걸 목록 안에서 말하려고 두 번
    /// 시도했고 둘 다 되돌렸다 — 행에 `D-7` 조각을 붙이는 것, '나중' 칸에서 맨
    /// 위로 끌어올리는 것. 이제 목록 바깥 카드가 맡는다.
    @Test("디데이로_표시한_것만_카드에_선다")
    func 디데이_카드() {
        make("시험", date: day("2026-10-20"), isDDay: true)
        make("보통 일", date: day("2026-10-20"))
        let todos = (try? context.fetch(FetchDescriptor<TodoItem>())) ?? []

        #expect(TodoListPage.dDays(in: todos, today: today, calendar: calendar).map(\.title) == ["시험"])
    }

    @Test("카드는_가까운_순이다")
    func 디데이_순서() {
        make("먼 것", date: day("2027-01-20"), isDDay: true)
        make("가까운 것", date: day("2026-10-20"), isDDay: true)
        let todos = (try? context.fetch(FetchDescriptor<TodoItem>())) ?? []

        let titles = TodoListPage.dDays(in: todos, today: today, calendar: calendar).map(\.title)
        #expect(titles == ["가까운 것", "먼 것"])
    }

    /// 날짜가 지났어도 안 끝냈으면 '지난 할 일' 칸에 그대로 있다. 카드에서까지
    /// 사라지면 왜 없어졌는지 알 수 없다.
    @Test("지난_디데이도_카드에_남는다")
    func 지난_디데이() {
        make("놓친 마감", date: day("2026-10-05"), isDDay: true)
        let todos = (try? context.fetch(FetchDescriptor<TodoItem>())) ?? []

        #expect(TodoListPage.dDays(in: todos, today: today, calendar: calendar).count == 1)
    }

    @Test("끝낸_디데이와_날짜_없는_디데이는_카드에_안_선다")
    func 카드에서_빠지는_것() {
        make("끝냄", date: day("2026-10-20"), completed: true, isDDay: true)
        make("날짜 없음", date: nil, isDDay: true)
        let todos = (try? context.fetch(FetchDescriptor<TodoItem>())) ?? []

        #expect(TodoListPage.dDays(in: todos, today: today, calendar: calendar).isEmpty)
    }
}
