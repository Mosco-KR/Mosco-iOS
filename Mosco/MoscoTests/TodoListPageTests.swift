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

    /// 석 달 뒤 시험은 날짜순으로는 저 아래인데, 디데이로 표시했다는 건
    /// "자주 보고 싶다"는 뜻이다.
    @Test("나중_칸에서는_디데이가_맨_위로_온다")
    func 나중_디데이() {
        let 가까운_것 = make("다음 달 약속", date: day("2026-11-01"))
        let 시험 = make("시험", date: day("2027-01-20"), isDDay: true)

        let sorted = TodoListPage.sort([가까운_것, 시험], in: .later, today: today, calendar: calendar)

        #expect(sorted.map(\.title) == ["시험", "다음 달 약속"])
    }

    @Test("이번_주_칸에서는_디데이라고_올라오지_않는다")
    func 이번_주_디데이() {
        let 모레 = make("모레 일", date: day("2026-10-11"))
        let 디데이 = make("닷새 뒤 디데이", date: day("2026-10-14"), isDDay: true)

        let sorted = TodoListPage.sort([디데이, 모레], in: .thisWeek, today: today, calendar: calendar)

        #expect(sorted.map(\.title) == ["모레 일", "닷새 뒤 디데이"], "가까운 주에서는 날짜순이 곧 할 순서다")
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

    @Test("묶음은_급한_순서로_나온다")
    func 묶음_순서() {
        make("어제", date: day("2026-10-08"))
        make("오늘", date: today)
        make("모레", date: day("2026-10-11"))
        make("다음 달", date: day("2026-11-20"))
        make("언젠가", date: nil)
        let todos = (try? context.fetch(FetchDescriptor<TodoItem>())) ?? []

        let sections = TodoListPage.sections(in: todos, today: today, calendar: calendar)

        #expect(sections.map(\.section) == [.overdue, .today, .thisWeek, .later, .noDate])
    }

    // MARK: - 오늘 탭 머리의 한 줄

    /// 오늘 탭에서 지난 할 일과 백로그 묶음을 들어냈으므로, 거기 뭐가 있다는 것을
    /// 알려줄 길이 필요하다. 그냥 들어내면 적어둔 게 어디 갔는지 모르게 된다.
    @Test("넘어온_것의_수는_지난_것과_날짜_없는_것을_함께_센다")
    func 넘어온_수() {
        make("어제", date: day("2026-10-08"))
        make("지난주", date: day("2026-10-01"))
        make("언젠가", date: nil)
        make("오늘", date: today)
        make("어제 끝냄", date: day("2026-10-08"), completed: true)
        let todos = (try? context.fetch(FetchDescriptor<TodoItem>())) ?? []

        #expect(TodoListPage.carryOverCount(in: todos, today: today) == 3)
    }

    // MARK: - 디데이 세기

    @Test("디데이는_남은_날을_센다")
    func 디데이_세기() {
        let 이레_뒤 = make("시험", date: day("2026-10-16"), isDDay: true)
        #expect(이레_뒤.dDayCount(from: today, calendar: calendar) == 7)

        let 오늘_것 = make("오늘이 그날", date: today, isDDay: true)
        #expect(오늘_것.dDayCount(from: today, calendar: calendar) == 0)
    }

    @Test("디데이로_표시하지_않았으면_세지_않는다")
    func 디데이_아님() {
        #expect(make("보통 일", date: day("2026-10-16")).dDayCount(from: today, calendar: calendar) == nil)
        #expect(make("날짜 없음", date: nil, isDDay: true).dDayCount(from: today, calendar: calendar) == nil)
    }
}
