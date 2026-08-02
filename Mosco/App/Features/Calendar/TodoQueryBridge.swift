import SwiftUI
import SwiftData

/// `@Query`를 소유하는 **유일한** 뷰. 그림은 아무것도 안 그리고, 할 일이 바뀔 때
/// 스냅샷 저장소에 값을 넘겨주기만 한다.
///
/// 이 뷰가 따로 있는 게 이 설계의 핵심 중 하나다. 예전엔 `CalendarScreen`이 직접
/// `@Query`를 들고 있어서, 할 일이 하나만 바뀌어도 헤더·격자·하루치 리스트까지
/// 화면 전체 body가 다시 돌았다. 관찰을 이 리프에 가둬두면 그 파급이 여기서 끝난다.
struct TodoQueryBridge: View {
    @Query(sort: \TodoItem.date) private var todos: [TodoItem]
    /// 카테고리 색이 바뀌면 막대 색도 따라가야 한다. `TodoItem`만 관찰하면 관계
    /// 건너편(카테고리)의 변경은 이 뷰를 깨우지 않아서, 색이 그대로 남는다.
    @Query private var categories: [TodoCategory]
    /// 숨긴 캘린더들. 비어 있으면 전부 보인다.
    @AppStorage(CalendarSelection.storageKey) private var hiddenCalendarIDs = ""

    let store: CalendarSnapshotStore

    var body: some View {
        // 캘린더 필터를 **여기 한 곳에서만** 건다. 스냅샷이 통째로 바뀌므로 격자와
        // 막대는 저절로 따라온다 — 화면마다 따로 거르면 어디선가 빠뜨리게 된다.
        let hidden = CalendarSelection.hidden(from: hiddenCalendarIDs)
        let visible = todos.filter { CalendarSelection.matches($0, hidden: hidden) }
        // 값 타입으로 베껴두면 ① 실제로 달라졌을 때만 재계산이 걸리고(배열 비교),
        // ② 이후 계산을 메인 스레드 밖으로 보낼 수 있다(@Model은 못 보낸다).
        let snapshots = visible.compactMap { TodoSnapshot($0) }
        let categoryRevision = categories.map(\.colorHex).joined(separator: ",")

        return Color.clear
            .frame(width: 0, height: 0)
            .allowsHitTesting(false)
            .task(id: TodoQueryBridge.Signal(todos: snapshots, categories: categoryRevision)) {
                store.ingest(snapshots)
            }
    }

    /// `.task(id:)`가 볼 변경 신호. 할 일 값 자체와 카테고리 색을 함께 본다.
    private struct Signal: Equatable {
        let todos: [TodoSnapshot]
        let categories: String
    }
}
