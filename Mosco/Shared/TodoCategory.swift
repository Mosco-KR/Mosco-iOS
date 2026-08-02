import Foundation
import SwiftData

/// 예전엔 Must/Should/Could/Won't 4단계로 고정돼 있었지만, 실제로는 사람마다
/// 할 일을 나누는 기준이 다르다 — 그래서 사용자가 이름과 색을 직접 정해서
/// 얼마든지 만들 수 있는 카테고리로 바꿨다.
/// (이름을 Category가 아니라 TodoCategory로 한 이유: Apple SDK 어딘가의
/// 불투명 포인터 타입과 이름이 겹치는 낌새가 있었다 — 헷갈릴 바에 더
/// 구체적인 이름을 쓴다.)
@Model
final class TodoCategory {
    var id: UUID = UUID()
    var name: String = ""
    var colorHex: String = "8B5CF6"
    /// 사용자가 만든 순서 — 목록/선택 팝업에서 이 순서 그대로 보여준다.
    var sortOrder: Int = 0
    var createdAt: Date = Date.now
    /// CloudKit 미러링은 역관계(inverse) 없는 관계를 받아주지 않는다. 실제로 이
    /// 배열을 읽는 코드는 없지만, 없으면 저장소가 아예 안 열린다.
    @Relationship(deleteRule: .nullify, inverse: \TodoItem.category)
    var todos: [TodoItem]? = nil
    /// 앱이 처음 켜질 때 seed되는 단 하나의 카테고리(RootTabView 참고). 이름·색은
    /// 바꿀 수 있지만 지울 수는 없다 — 다른 카테고리가 삭제될 때 그 안의 할 일들이
    /// 여기로 옮겨오기 때문에, 옮겨 담을 곳이 항상 있다는 걸 보장해야 한다.
    /// 인라인 기본값을 둔 건 나중에 CloudKit을 켜기 위해서다 — CloudKit은 모든
    /// 속성이 옵셔널이거나 기본값을 갖기를 요구한다.
    var isDefault: Bool = false
    /// 이 카테고리의 할 일에 시작 전 알림을 보낼지. 알림은 카테고리 단위로 켜고
    /// 끈다 — 할 일마다 정하게 하면 매번 신경 써야 하지만, "업무는 알림 받고
    /// 개인 할 일은 안 받는다"처럼 묶어서 정하면 한 번만 정하면 된다.
    /// 기본은 켜짐 — 시간을 정해둔 일정은 알림을 원하는 게 보통이고, 필요 없으면
    /// 끄는 편이 "왜 알림이 안 오지"보다 알아채기 쉽다.
    var notifiesBeforeStart: Bool = true
    /// 시작 몇 분 전에 알릴지. notifiesBeforeStart가 false면 의미 없다.
    var notificationLeadMinutes: Int = 10

    init(name: String, colorHex: String, sortOrder: Int, isDefault: Bool = false) {
        self.id = UUID()
        self.name = name
        self.colorHex = colorHex
        self.sortOrder = sortOrder
        self.createdAt = .now
        self.isDefault = isDefault
    }
}

extension TodoCategory {
    /// 카테고리를 지우기 전에 그 안의 할 일들을 먼저 기본 카테고리로 옮긴다.
    /// 기본 카테고리 자신은 이 함수로 지울 수 없다(항상 no-op) — 옮겨 담을 곳이
    /// 없어지는 상태 자체를 만들지 않기 위해서다.
    static func delete(_ category: TodoCategory, reassigningTodosTo defaultCategory: TodoCategory, in context: ModelContext) {
        guard !category.isDefault else { return }
        let removedID = category.id
        if let items = try? context.fetch(FetchDescriptor<TodoItem>()) {
            for item in items where item.category?.id == removedID {
                item.category = defaultCategory
            }
        }
        context.delete(category)
    }
}
