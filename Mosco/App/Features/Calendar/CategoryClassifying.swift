import Foundation

/// 입력한 제목을 보고 어느 카테고리에 속할지 추천하는 분류기의 인터페이스.
/// SwiftData 모델(TodoCategory/TodoItem)은 Sendable이 아니라서, 이 프로토콜
/// 자체를 MainActor에 묶어 액터 경계를 안 넘게 한다 — 어차피 호출부(QuickAddView)도
/// MainActor라 제약이 아니라 그냥 실제 상황을 타입에 반영하는 것뿐이다.
@MainActor
protocol CategoryClassifying {
    /// existingTodos는 카테고리별 중심(centroid)을 계산할 재료 — 학습이 아니라
    /// 매번 그 자리에서 평균을 내는 것이라 카테고리를 새로 추가해도 바로 반영된다.
    func classify(_ text: String, categories: [TodoCategory], existingTodos: [TodoItem]) async -> TodoCategory?
}
