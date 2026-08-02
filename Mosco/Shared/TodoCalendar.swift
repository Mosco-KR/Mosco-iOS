import Foundation
import SwiftData

/// 일정을 크게 나누는 묶음 — "개인", "업무"처럼. 카테고리 **위의** 층이다.
///
/// 카테고리와 역할이 다르다: 카테고리는 한 일정의 성격(색·알림)을 정하고,
/// 캘린더는 "지금 어느 묶음을 보고 있는가"를 정한다. 그래서 캘린더의 색은
/// 선택기에서 구분용으로만 쓰고, 격자의 막대 색은 계속 카테고리 색이 이긴다 —
/// 두 색이 같은 자리를 다투면 어느 쪽이 무슨 뜻인지 알 수 없게 된다.
///
/// "통합"은 여기에 없다. 그건 엔티티가 아니라 **아무것도 안 고른 상태**다
/// (`CalendarSelection` 참고) — 엔티티로 만들면 "통합에 소속된 일정"이라는
/// 있어선 안 되는 상태가 생긴다.
///
/// 이름을 `Calendar`가 아니라 `TodoCalendar`로 둔 건 `Foundation.Calendar`와
/// 겹치기 때문이다(`TodoCategory`가 같은 이유로 그렇게 지어졌다).
///
/// 모든 속성에 인라인 기본값이 있는 건 CloudKit 미러링 요구사항이다 —
/// 옵셔널이거나 기본값이 있어야 한다.
@Model
final class TodoCalendar {
    var id: UUID = UUID()
    var name: String = ""
    var colorHex: String = "8B5CF6"
    /// 사용자가 만든 순서 — 선택기와 설정 목록에서 이 순서 그대로 보여준다.
    var sortOrder: Int = 0
    /// 앱이 처음 켜질 때 seed되는 단 하나. 이름·색은 바꿀 수 있지만 지울 수 없다 —
    /// 다른 캘린더가 삭제될 때 그 안의 일정이 여기로 옮겨오므로, 옮겨 담을 곳이
    /// 항상 있다는 걸 보장해야 한다(TodoCategory와 같은 규칙).
    var isDefault: Bool = false
    var createdAt: Date = Date.now
    /// CloudKit 미러링이 요구하는 역관계 — `TodoCategory.todos`와 같은 이유다.
    @Relationship(deleteRule: .nullify, inverse: \TodoItem.calendar)
    var todos: [TodoItem]? = nil

    init(name: String, colorHex: String, sortOrder: Int, isDefault: Bool = false) {
        self.id = UUID()
        self.name = name
        self.colorHex = colorHex
        self.sortOrder = sortOrder
        self.isDefault = isDefault
        self.createdAt = .now
    }
}

extension TodoCalendar {
    /// 캘린더를 지우기 전에 그 안의 일정들을 먼저 기본 캘린더로 옮긴다.
    /// 기본 캘린더 자신은 이 함수로 지울 수 없다(항상 no-op).
    static func delete(
        _ calendar: TodoCalendar,
        reassigningTodosTo defaultCalendar: TodoCalendar,
        in context: ModelContext
    ) {
        guard !calendar.isDefault else { return }
        let removedID = calendar.id
        if let items = try? context.fetch(FetchDescriptor<TodoItem>()) {
            for item in items where item.calendar?.id == removedID {
                item.calendar = defaultCalendar
            }
        }
        context.delete(calendar)
    }
}

/// 지금 화면에 보여줄 캘린더들. 화면 여러 곳(캘린더 격자·하루치 리스트·오늘 탭·빠른
/// 추가)이 같은 값을 봐야 해서 `UserDefaults`에 둔다 — 뷰 계층을 타고 내려보내면
/// 중간 뷰들이 관계없이 다시 그려진다.
///
/// **보이는 쪽이 아니라 "숨긴" 쪽을 저장한다.** 그래야 두 가지가 저절로 맞는다:
/// 아무것도 고른 적 없는 처음 상태(빈 값)가 "전부 보임"이 되고, 나중에 만든 캘린더가
/// 기본으로 보인다. 보이는 목록을 저장하면 새 캘린더가 그 목록에 없어서 만들자마자
/// 안 보이는 이상한 상태가 된다.
enum CalendarSelection {
    static let storageKey = "hiddenCalendarIDs"

    static func hidden(from raw: String) -> Set<String> {
        Set(raw.split(separator: ",").map(String.init))
    }

    static func raw(from hidden: Set<String>) -> String {
        hidden.sorted().joined(separator: ",")
    }

    static func isVisible(_ calendar: TodoCalendar, hidden: Set<String>) -> Bool {
        !hidden.contains(calendar.id.uuidString)
    }

    static func visible(_ calendars: [TodoCalendar], hidden: Set<String>) -> [TodoCalendar] {
        calendars.filter { isVisible($0, hidden: hidden) }
    }

    /// 어느 캘린더에도 안 들어간 할 일은 항상 보인다 — 필터 때문에 데이터가
    /// 통째로 사라지는 상태를 만들지 않으려는 것이다.
    static func matches(_ todo: TodoItem, hidden: Set<String>) -> Bool {
        guard let calendar = todo.calendar else { return true }
        return isVisible(calendar, hidden: hidden)
    }
}
