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
    var id: UUID
    var name: String
    var colorHex: String
    /// 사용자가 만든 순서 — 목록/선택 팝업에서 이 순서 그대로 보여준다.
    var sortOrder: Int
    var createdAt: Date
    /// 앱이 처음 켜질 때 seed되는 단 하나의 카테고리(RootTabView 참고). 이름·색은
    /// 바꿀 수 있지만 지울 수는 없다 — 다른 카테고리가 삭제될 때 그 안의 할 일들이
    /// 여기로 옮겨오기 때문에, 옮겨 담을 곳이 항상 있다는 걸 보장해야 한다.
    /// 기존 데이터와의 라이트웨이트 마이그레이션을 위해 기본값을 인라인으로 둔다.
    var isDefault: Bool = false

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
