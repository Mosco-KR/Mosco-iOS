import Foundation
import SwiftData
import Testing

/// 오늘 탭을 없애면서 오늘 페이지가 대신 맡는 것들. 하나라도 빠지면 기존 사용자가
/// 잃는 게 생긴다 — 디데이 카드, 지난 할 일, 날짜 없는 할 일, 검색.
///
/// 모델이 `Calendar.current`를 쓰므로 날짜도 같은 달력으로 만든다.
@MainActor
struct TodayPageTests {

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

    @discardableResult
    private func make(
        _ title: String, date: Date? = nil, endDate: Date? = nil,
        dDay: Bool = false, done: Bool = false, memo: String? = nil, sortIndex: Int = 0
    ) -> TodoItem {
        let todo = TodoItem(title: title, date: date, endDate: endDate)
        todo.isDDay = dDay
        todo.isCompleted = done
        todo.memo = memo
        todo.sortIndex = sortIndex
        context.insert(todo)
        return todo
    }

    private var today: Date { d("2026-10-01") }

    // MARK: 디데이

    @Test("디데이는_오늘과_앞으로_올_것만_가까운_순으로_나온다")
    func 디데이() {
        let all = [
            make("지난 기념일", date: d("2026-09-20"), dDay: true),
            make("엄마 생신", date: d("2026-10-06"), dDay: true),
            make("오늘 마감", date: d("2026-10-01"), dDay: true),
            make("그냥 할 일", date: d("2026-10-03"))
        ]
        #expect(TodayPage.dDays(in: all, today: today).map(\.title) == ["오늘 마감", "엄마 생신"])
    }

    // MARK: 지난 할 일

    @Test("지난_할_일은_오래된_순이고_기간_안의_일은_빠진다")
    func 지난_할_일() {
        let all = [
            make("어제 것", date: d("2026-09-30")),
            make("지난주 것", date: d("2026-09-24")),
            make("어제 시작해 오늘 끝나는 출장", date: d("2026-09-30"), endDate: d("2026-10-01")),
            make("끝낸 것", date: d("2026-09-29"), done: true)
        ]
        #expect(TodayPage.overdue(in: all, today: today).map(\.title) == ["지난주 것", "어제 것"])
    }

    // MARK: 날짜 없는 할 일

    @Test("날짜_없는_할_일은_끝낸_것을_빼고_정한_순서대로_나온다")
    func 날짜_없는_할_일() {
        let all = [
            make("둘째", sortIndex: 2),
            make("첫째", sortIndex: 1),
            make("끝낸 것", done: true),
            make("날짜 있는 것", date: today)
        ]
        #expect(TodayPage.backlog(in: all).map(\.title) == ["첫째", "둘째"])
    }

    // MARK: 오늘을 다 끝냈나 — 리뷰 부탁의 가장 좋은 자리

    @Test("오늘_할_일_중_남은_개수를_센다_날짜_없는_것과_다른_날은_빼고")
    func 남은_개수() {
        let all = [
            make("끝낸 것", date: today, done: true),
            make("남은 것", date: today),
            make("내일 것", date: d("2026-10-02")),
            make("날짜 없는 것")
        ]
        let progress = TodayPage.progress(in: all, today: today)
        #expect(progress.total == 2)
        #expect(progress.remaining == 1)
    }

    @Test("어제_시작해_오늘까지인_일도_오늘_할_일로_센다")
    func 기간_일정() {
        let all = [make("출장", date: d("2026-09-30"), endDate: d("2026-10-01"))]
        #expect(TodayPage.progress(in: all, today: today).total == 1)
    }

    // MARK: 검색

    @Test("검색은_제목과_메모를_함께_본다")
    func 제목과_메모() {
        let all = [
            make("치과 예약", date: today),
            make("장보기", date: today, memo: "치약 사기"),
            make("러닝", date: today)
        ]
        #expect(Set(TodayPage.search("치", in: all).map(\.title)) == ["치과 예약", "장보기"])
    }

    @Test("검색_결과는_날짜순이고_날짜_없는_것은_맨_뒤다")
    func 검색_순서() {
        let all = [
            make("책 반납"),
            make("책 고르기", date: d("2026-10-05")),
            make("책 사기", date: d("2026-10-02"))
        ]
        #expect(TodayPage.search("책", in: all).map(\.title) == ["책 사기", "책 고르기", "책 반납"])
    }

    @Test("빈_검색어는_아무것도_찾지_않는다")
    func 빈_검색어() {
        make("아무거나", date: today)
        #expect(TodayPage.search("   ", in: [make("하나", date: today)]).isEmpty)
    }
}
