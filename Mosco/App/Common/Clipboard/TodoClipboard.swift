import Foundation
import Observation
import SwiftData

/// 앱 안에서만 쓰는 복사/붙여넣기 통.
///
/// **복제 시트와 나눠 맡는다.** "이 날로"가 이미 정해졌으면 메뉴 > 복제로 한 번에
/// 끝내고, 날짜를 둘러보며 정하는 중이면 복사해두고 달력을 넘겨 다니다가 붙여넣는다.
/// 두 번째 동선을 시트로 흉내 내려면 시트 안에 달력을 또 그려야 하는데, 그 달력은
/// 이 앱의 진짜 달력이 아니라서 날씨도 다른 일정도 안 보인다 — 어디에 넣을지
/// 정하려면 원래 달력을 봐야 한다.
///
/// **SwiftData 객체가 아니라 값을 담는다.** 원본을 복사해두고 지워도 붙여넣기가
/// 깨지지 않아야 하고, 삭제된 모델을 들고 있으면 접근하는 순간 크래시가 난다.
@Observable
@MainActor
final class TodoClipboard {
    /// 복사해둔 할 일. 비어 있으면 붙여넣기 자리 자체가 안 보인다.
    private(set) var item: Snapshot?

    /// 복사 시점의 내용. 관계(카테고리·캘린더)는 id로만 들고 있다가 붙여넣을 때
    /// 다시 찾는다 — 그 사이에 카테고리가 지워졌으면 그냥 못 찾은 것으로 두면 된다.
    struct Snapshot {
        let title: String
        let categoryID: UUID?
        let calendarID: UUID?
        let startTime: Date?
        let endTime: Date?
        let durationDays: Int
        let memo: String?
    }

    func copy(_ todo: TodoItem) {
        item = Snapshot(
            title: todo.title,
            categoryID: todo.category?.id,
            calendarID: todo.calendar?.id,
            startTime: todo.startTime,
            endTime: todo.endTime,
            durationDays: todo.durationDays,
            memo: todo.memo
        )
    }

    func clear() {
        item = nil
    }

    /// 복사해둔 내용으로 주어진 날짜에 새 할 일을 만들어 저장소에 넣는다.
    ///
    /// 붙여넣기는 통을 비우지 않는다 — 같은 일을 여러 날에 흩뿌리는 게 이 동선의
    /// 쓸모라서, 한 번 붙일 때마다 다시 복사해야 하면 쓸 이유가 없어진다.
    @discardableResult
    func paste(on date: Date, in context: ModelContext) -> TodoItem? {
        guard let item else { return nil }
        let gregorian = Calendar.current
        let start = gregorian.startOfDay(for: date)
        // 관계는 id로만 들고 있었으니 지금 다시 찾는다 — 그 사이 지워졌으면
        // 못 찾은 것으로 두면 된다. 둘 다 많아야 수십 개라 전부 가져와 찾는다.
        let categories = (try? context.fetch(FetchDescriptor<TodoCategory>())) ?? []
        let calendars = (try? context.fetch(FetchDescriptor<TodoCalendar>())) ?? []

        let todo = TodoItem(
            title: item.title,
            date: start,
            endDate: item.durationDays > 0
                ? gregorian.date(byAdding: .day, value: item.durationDays, to: start)
                : nil,
            startTime: item.startTime,
            endTime: item.endTime,
            category: categories.first { $0.id == item.categoryID }
        )
        // 원본의 캘린더가 지워졌으면 기본 캘린더로 — 어디에도 안 들어간 할 일은
        // 캘린더를 하나 끄는 순간 사라진 것처럼 보인다(RootTabView.seedIfNeeded 참고).
        todo.calendar = calendars.first { $0.id == item.calendarID }
            ?? calendars.first(where: \.isDefault)
        todo.memo = item.memo
        context.insert(todo)
        return todo
    }
}
