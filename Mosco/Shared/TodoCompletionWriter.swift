import Foundation
import SwiftData
import WidgetKit

/// 앱 화면 밖에서 완료를 기록하는 창구 — 위젯의 체크박스와 라이브 액티비티의
/// '완료' 버튼이 여기로 온다.
///
/// **두 곳이 같은 코드를 쓴다.** 예전엔 위젯 쪽에만 있었는데, 라이브 액티비티
/// 버튼은 (프로세스 사정 때문에) 앱 프로세스에서 돌아야 해서 위젯 전용 코드에
/// 닿을 수 없다. 완료를 기록하는 규칙이 둘로 갈라지면 반복 일정의 날짜별 완료
/// 같은 까다로운 부분이 한쪽에서만 맞게 된다.
enum TodoCompletionWriter {
    /// 체크박스처럼 누를 때마다 뒤집는다.
    @MainActor
    static func toggle(todoID: String, dayKey: String, source: String) {
        write(todoID: todoID, dayKey: dayKey, to: nil, source: source)
    }

    /// 완료로 고정한다. 라이브 액티비티는 아직 안 끝난 일에만 떠 있으니 그 버튼이
    /// 뜻하는 건 언제나 "지금 끝냈다" 하나뿐이고, 전환으로 두면 이미 다른 데서
    /// 체크된 일을 도로 풀어버릴 수 있다.
    @MainActor
    static func complete(todoID: String, dayKey: String, source: String) {
        write(todoID: todoID, dayKey: dayKey, to: true, source: source)
    }

    /// `to`가 nil이면 전환, 값이면 그 값으로 고정한다.
    ///
    /// 저장 후 타임라인을 다시 잡는 게 중요하다 — 안 그러면 눌러도 위젯의
    /// 체크 표시가 다음 자정까지 그대로다.
    @MainActor
    private static func write(todoID: String, dayKey: String, to target: Bool?, source: String) {
        guard let container = SharedModelContainer.sharedIfAvailable,
              let uuid = UUID(uuidString: todoID),
              let seconds = TimeInterval(dayKey)
        else { return }

        let day = Date(timeIntervalSince1970: seconds)
        let context = container.mainContext
        // 술어(Predicate)로 UUID를 거르는 대신 전부 읽고 고르는 건 이 앱의 다른
        // 조회와 같은 방식이다 — 데이터가 애초에 몇십 건 규모다.
        guard let todo = (try? context.fetch(FetchDescriptor<TodoItem>()))?
            .first(where: { $0.id == uuid })
        else { return }

        let nowCompleted = target ?? !todo.isCompleted(on: day)
        // 이미 그 상태면 저장도 이벤트도 남기지 않는다 — 버튼이 두 번 눌렸을 때
        // 완료 이벤트가 두 번 찍히면 숫자가 부풀어 오른다.
        guard nowCompleted != todo.isCompleted(on: day) else { return }

        todo.setCompleted(nowCompleted, on: day)
        try? context.save()
        AnalyticsBuffer.record(
            .taskCompleted(
                source: source,
                completed: nowCompleted,
                isRepeating: todo.repeatRule != .none
            )
        )
        WidgetCenter.shared.reloadAllTimelines()
    }
}
