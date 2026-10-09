import Foundation
import SwiftData
import Testing

/// 알림 예약. **이 로직은 2026-10-06까지 테스트가 한 건도 없었다** — 계산이
/// `App/`의 스케줄러 안에 있어서 테스트 타깃에서 닿지 않았다. `ReminderPlan`으로
/// 꺼내면서 같이 덮는다.
///
/// 알림은 눈으로 확인하기 가장 비싼 기능이다. 시각을 기다려야 하고, 틀렸을 때
/// 보이는 것은 "안 울렸다"는 것뿐이어서 어디가 틀렸는지는 보이지 않는다.
@Suite("알림 예약 계획")
struct ReminderPlanTests {

    private let calendar = TestCalendar.korea
    /// 모든 테스트의 "지금" — 2026년 10월 6일 아침 8시.
    private var now: Date { at("2026-10-06", 8) }

    private func at(_ date: String, _ hour: Int, _ minute: Int = 0) -> Date {
        calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day(date, calendar: calendar))!
    }

    /// 알림을 받을 자격이 있는 할 일 한 줄. `minutes`는 하루 안의 시작 시각(분)이고
    /// nil이면 시간을 안 정한 할 일이다.
    private func source(
        _ title: String = "러닝",
        on date: String,
        through end: String? = nil,
        minutes: Int?,
        lead: Int = 10,
        rule: RepeatRule = .none,
        repeatEnd: String? = nil,
        completedDays: [String] = [],
        isCompleted: Bool = false,
        id: UUID = UUID()
    ) -> ReminderSource {
        var snapshot = TodoSnapshot(
            id: id,
            title: title,
            start: day(date, calendar: calendar),
            end: day(end ?? date, calendar: calendar),
            repeatRule: rule,
            repeatEndDate: repeatEnd.map { day($0, calendar: calendar) },
            completedDayKeys: completedDays.map { day($0, calendar: calendar).dayKey },
            isCompleted: isCompleted,
            createdAt: day(date, calendar: calendar)
        )
        snapshot.startMinutes = minutes ?? -1
        return ReminderSource(todo: snapshot, leadMinutes: lead)
    }

    private func plan(_ sources: [ReminderSource], horizonDays: Int = 60, limit: Int = 60) -> [PlannedReminder] {
        ReminderPlan.make(from: sources, now: now, calendar: calendar, horizonDays: horizonDays, limit: limit)
    }

    // MARK: - 언제 울리나

    @Test("리드타임만큼_앞서_울린다")
    func 리드타임() throws {
        let planned = plan([source(on: "2026-10-06", minutes: 19 * 60, lead: 10)])
        let one = try #require(planned.first)
        #expect(planned.count == 1)
        #expect(one.fireDate == at("2026-10-06", 18, 50))
        #expect(one.startDate == at("2026-10-06", 19))
    }

    /// 카테고리 설정에 '시작 시간에'(0분)가 있다. 그때는 시작 시각에 울린다.
    @Test("리드타임_0분이면_시작_시각에_울린다")
    func 리드타임_0() throws {
        let one = try #require(plan([source(on: "2026-10-06", minutes: 19 * 60, lead: 0)]).first)
        #expect(one.fireDate == at("2026-10-06", 19))
        #expect(one.leadMinutes == 0)
    }

    @Test("시간을_안_정한_할_일에는_알림이_없다")
    func 시간_없음() {
        #expect(plan([source(on: "2026-10-06", minutes: nil)]).isEmpty)
    }

    @Test("이미_지난_시각은_예약하지_않는다")
    func 지난_시각() {
        // 지금이 아침 8시 — 7시 일정의 알림 시각(6시 50분)은 이미 지났다.
        #expect(plan([source(on: "2026-10-06", minutes: 7 * 60)]).isEmpty)
    }

    /// 리드타임이 길면 알림 시각이 지금보다 앞일 수 있다 — 시작은 아직 안 했어도.
    @Test("시작은_안_했지만_알림_시각이_지났으면_예약하지_않는다")
    func 알림_시각만_지남() {
        #expect(plan([source(on: "2026-10-06", minutes: 9 * 60, lead: 120)]).isEmpty)
        #expect(plan([source(on: "2026-10-06", minutes: 9 * 60, lead: 30)]).count == 1)
    }

    @Test("여러_날에_걸친_일정은_시작하는_날에만_울린다")
    func 여러_날짜리() throws {
        let planned = plan([source(on: "2026-10-06", through: "2026-10-09", minutes: 19 * 60)])
        #expect(planned.count == 1)
        #expect(try #require(planned.first).startDate == at("2026-10-06", 19))
    }

    // MARK: - 반복 일정

    @Test("매일_반복은_날마다_하나씩_예약된다")
    func 매일_반복() {
        let planned = plan([source(on: "2026-10-06", minutes: 19 * 60, rule: .daily)], horizonDays: 3)
        // 10/06 · 07 · 08 · 09 — 창은 오늘부터 사흘 뒤까지다.
        #expect(planned.count == 4)
        #expect(planned.map(\.startDate) == [
            at("2026-10-06", 19), at("2026-10-07", 19), at("2026-10-08", 19), at("2026-10-09", 19)
        ])
    }

    /// 원본 시작일을 두 번 세면 그만큼 가까운 알림이 64개 한도에서 밀려난다.
    @Test("반복_일정의_원본_시작일이_두_번_들어가지_않는다")
    func 중복_없음() {
        let planned = plan([source(on: "2026-10-06", minutes: 19 * 60, rule: .daily)], horizonDays: 3)
        #expect(Set(planned.map(\.id)).count == planned.count)
        #expect(planned.filter { $0.startDate == at("2026-10-06", 19) }.count == 1)
    }

    @Test("반복_종료일_뒤로는_예약하지_않는다")
    func 반복_종료() {
        let planned = plan(
            [source(on: "2026-10-06", minutes: 19 * 60, rule: .daily, repeatEnd: "2026-10-07")],
            horizonDays: 10
        )
        #expect(planned.map(\.startDate) == [at("2026-10-06", 19), at("2026-10-07", 19)])
    }

    /// 창 밖에서 시작하는 반복 일정이 들어오면, 100일 뒤 알림 하나가 한도에서
    /// 자리를 차지하고 그만큼 가까운 알림이 밀려난다.
    @Test("창_밖에서_시작하는_일정은_들어오지_않는다")
    func 창_밖() {
        #expect(plan([source(on: "2026-12-01", minutes: 19 * 60, rule: .daily)], horizonDays: 3).isEmpty)
        #expect(plan([source(on: "2026-12-01", minutes: 19 * 60)], horizonDays: 3).isEmpty)
    }

    // MARK: - 끝낸 것은 알리지 않는다

    @Test("이미_끝낸_할_일은_알리지_않는다")
    func 완료() {
        #expect(plan([source(on: "2026-10-06", minutes: 19 * 60, isCompleted: true)]).isEmpty)
    }

    @Test("반복_일정은_끝낸_그날만_빠진다")
    func 반복_완료() {
        let planned = plan(
            [source(on: "2026-10-06", minutes: 19 * 60, rule: .daily, completedDays: ["2026-10-07"])],
            horizonDays: 3
        )
        #expect(planned.map(\.startDate) == [
            at("2026-10-06", 19), at("2026-10-08", 19), at("2026-10-09", 19)
        ])
    }

    // MARK: - 한도와 순서

    @Test("가까운_것부터_한도만큼만_예약한다")
    func 한도() {
        let sources = [
            source("저녁", on: "2026-10-06", minutes: 19 * 60),
            source("점심", on: "2026-10-06", minutes: 12 * 60),
            source("회의", on: "2026-10-06", minutes: 15 * 60)
        ]
        #expect(plan(sources, limit: 2).map(\.title) == ["점심", "회의"])
        #expect(plan(sources, limit: 0).isEmpty)
    }

    /// 순서가 실행마다 달라지면 한도에 걸려 잘리는 쪽도 달라진다 — 같은 데이터로
    /// 다른 알림이 걸린다.
    @Test("같은_시각이면_순서가_실행마다_달라지지_않는다")
    func 결정적_순서() {
        let sources = [
            source("가", on: "2026-10-06", minutes: 19 * 60, id: UUID(uuidString: "00000000-0000-0000-0000-0000000000BB")!),
            source("나", on: "2026-10-06", minutes: 19 * 60, id: UUID(uuidString: "00000000-0000-0000-0000-0000000000AA")!)
        ]
        #expect(plan(sources).map(\.title) == ["나", "가"])
        #expect(plan(sources.reversed()).map(\.title) == ["나", "가"])
    }

    /// 반복 일정은 저장소에 복제본이 없어서 id가 하나뿐이다. 식별자에 날짜를 안
    /// 넣으면 매일 같은 요청을 덮어써서 **하루치만 남는다.**
    @Test("같은_할_일의_다른_날은_서로_다른_식별자를_받는다")
    func 식별자() {
        let id = UUID()
        let planned = plan([source(on: "2026-10-06", minutes: 19 * 60, rule: .daily, id: id)], horizonDays: 3)
        #expect(Set(planned.map(\.id)).count == 4)
        #expect(planned.allSatisfy { $0.id.hasPrefix(id.uuidString) })
        #expect(planned.allSatisfy { $0.todoID == id })
    }
}

/// 저장소의 할 일에서 알림 입력을 베껴오는 자리. 여기서 거르는 것을 빠뜨리면
/// 알림을 원하지 않은 사람에게 알림이 간다.
@Suite("알림 입력 베껴오기")
@MainActor
struct ReminderSourceTests {

    private let container: ModelContainer
    private var context: ModelContext { container.mainContext }

    init() throws {
        container = try SharedModelContainer.inMemory()
    }

    private func make(
        notifies: Bool = true,
        lead: Int = 10,
        hasTime: Bool = true,
        hasDate: Bool = true
    ) -> TodoItem {
        let category = TodoCategory(name: "업무", colorHex: "8B5CF6", sortOrder: 0)
        category.notifiesBeforeStart = notifies
        category.notificationLeadMinutes = lead
        context.insert(category)
        let today = Calendar.current.startOfDay(for: .now)
        let todo = TodoItem(
            title: "회의",
            date: hasDate ? today : nil,
            startTime: hasTime ? Calendar.current.date(bySettingHour: 19, minute: 0, second: 0, of: today) : nil,
            category: category
        )
        context.insert(todo)
        return todo
    }

    @Test("카테고리_알림이_켜진_할_일은_리드타임을_함께_가져온다")
    func 가져온다() throws {
        let source = try #require(ReminderSource(make(lead: 30)))
        #expect(source.leadMinutes == 30)
        #expect(source.todo.startMinutes == 19 * 60)
    }

    @Test("카테고리_알림이_꺼져_있으면_가져오지_않는다")
    func 카테고리가_꺼짐() {
        #expect(ReminderSource(make(notifies: false)) == nil)
    }

    /// 카테고리가 없다는 건 "알림을 원하지 않는다"는 뜻이 아니다 — 분류가 아직
    /// 안 붙었다는 뜻일 뿐이다. 예전엔 여기서 돌려보내서, 시각을 적어둔 할 일이
    /// 조용히 알림을 못 받았다.
    @Test("카테고리가_없어도_기본_리드타임으로_알린다")
    func 카테고리_없음() throws {
        let today = Calendar.current.startOfDay(for: .now)
        let todo = TodoItem(
            title: "분류 없음",
            date: today,
            startTime: Calendar.current.date(bySettingHour: 19, minute: 0, second: 0, of: today)
        )
        context.insert(todo)

        let source = try #require(ReminderSource(todo))
        #expect(source.leadMinutes == TodoCategory.defaultLeadMinutes)
        #expect(source.todo.startMinutes == 19 * 60)
    }

    /// 날짜를 안 정한 할 일(백로그)은 울릴 날이 없다.
    @Test("날짜를_안_정한_할_일은_가져오지_않는다")
    func 날짜_없음() {
        #expect(ReminderSource(make(hasDate: false)) == nil)
    }

    /// 시간이 없는 것은 여기서 거르지 않고 계획 단계에서 거른다 — 시간만 나중에
    /// 붙이는 경우가 있어서, 베껴오는 쪽이 판단을 적게 들고 있는 편이 낫다.
    @Test("시간을_안_정한_할_일은_가져오되_알림은_안_걸린다")
    func 시간_없음() throws {
        let source = try #require(ReminderSource(make(hasTime: false)))
        #expect(source.todo.startMinutes == -1)
        #expect(ReminderPlan.make(from: [source], now: .now).isEmpty)
    }
}
