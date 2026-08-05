import Foundation
import SwiftData
import SwiftUI
import WidgetKit

/// 위젯이 목록으로 그릴 때 필요한 것만 담은 값 타입. SwiftData 모델(@Model 클래스)을
/// 타임라인 엔트리에 그대로 넣으면 위젯 프로세스가 다시 살아날 때 컨텍스트가 없어
/// 접근이 위험하므로, 읽는 시점에 값으로 복사해둔다.
///
/// 달력 격자용 값 타입은 이것과 별개다 — 거기엔 앱과 **같은** `TodoSnapshot`을 쓴다
/// (`Shared/TodoSnapshot.swift`). 이름이 겹치지 않게 여기는 `WidgetTodo`로 둔다.
struct WidgetTodo: Identifiable, Hashable {
    let id: UUID
    let title: String
    let isCompleted: Bool
    let categoryColorHex: String?
    /// 시작 시각 표기("오후 3시"). 종일 일정이면 nil.
    let timeLabel: String?
}

/// 위젯에서 저장소를 읽는 얇은 창구. 앱과 같은 App Group 컨테이너를 연다.
enum WidgetStore {
    /// 위젯은 짧게 살고 자주 죽어서, 매번 컨테이너를 새로 여는 대신 재사용한다.
    ///
    /// 설정을 여기서 직접 만들지 않고 앱과 **같은 함수**를 쓴다. 예전엔 이 파일이
    /// `ModelConfiguration(schema:url:)`을 따로 만들었는데, 앱이 CloudKit을 켠 뒤로
    /// 같은 파일을 서로 다른 설정으로 열게 돼서 컨테이너 생성이 실패했다 —
    /// `try?`가 그 실패를 삼키는 바람에 위젯은 아무 오류 없이 그냥 빈 목록을 그렸다.
    private static let container: ModelContainer? = {
        if let shared = try? ModelContainer(
            for: SharedModelContainer.schema,
            configurations: SharedModelContainer.makeConfiguration()
        ) {
            return shared
        }
        // iCloud를 못 쓰는 상황(계정 없음 등)에서는 앱도 로컬 전용으로 물러난다 —
        // 위젯도 같은 자리로 물러나야 둘이 계속 같은 파일을 본다.
        return try? ModelContainer(
            for: SharedModelContainer.schema,
            configurations: SharedModelContainer.localOnlyConfiguration()
        )
    }()

    @MainActor
    private static func allItems() -> [TodoItem] {
        guard let container else { return [] }
        guard let all = try? container.mainContext.fetch(FetchDescriptor<TodoItem>()) else { return [] }
        return all
    }

    /// 그날에 걸치는(반복 포함) 할 일을, 미완료 먼저 시간순으로.
    @MainActor
    static func todos(on day: Date, limit: Int) -> [WidgetTodo] {
        allItems()
            .filter { $0.occurs(on: day) }
            .sorted { lhs, rhs in
                let lhsDone = lhs.isCompleted(on: day)
                let rhsDone = rhs.isCompleted(on: day)
                if lhsDone != rhsDone { return !lhsDone }
                return lhs.sortableMinutes < rhs.sortableMinutes
            }
            .prefix(limit)
            .map { todo in
                WidgetTodo(
                    id: todo.id,
                    title: todo.title,
                    isCompleted: todo.isCompleted(on: day),
                    categoryColorHex: todo.category?.colorHex,
                    timeLabel: todo.startTime?.koreanTime
                )
            }
    }

    /// 위젯 체크박스가 부르는 완료 전환. 위젯 프로세스에서 App Group 저장소를
    /// 직접 고치므로, 앱이 떠 있지 않아도 동작한다.
    ///
    /// 저장 후 타임라인을 다시 잡는 게 중요하다 — 안 그러면 눌러도 화면의
    /// 체크 표시가 다음 자정까지 그대로다.
    @MainActor
    static func toggleCompletion(todoID: String, dayKey: String) {
        guard let container,
              let uuid = UUID(uuidString: todoID),
              let seconds = TimeInterval(dayKey)
        else { return }

        let day = Date(timeIntervalSince1970: seconds)
        let context = container.mainContext
        // 술어(Predicate)로 UUID를 거르는 대신 전부 읽고 고르는 건 이 파일의 다른
        // 조회와 같은 방식이다 — 위젯이 보는 데이터가 애초에 몇십 건 규모다.
        guard let todo = (try? context.fetch(FetchDescriptor<TodoItem>()))?
            .first(where: { $0.id == uuid })
        else { return }

        let nowCompleted = !todo.isCompleted(on: day)
        todo.setCompleted(nowCompleted, on: day)
        try? context.save()
        AnalyticsBuffer.record(
            .todoCompletionToggled(
                source: "widget",
                completed: nowCompleted,
                isRepeating: todo.repeatRule != .none
            )
        )
        WidgetCenter.shared.reloadAllTimelines()
    }

    /// 달력 위젯이 쓸 막대 배치. 앱의 격자와 **같은 계산**(`CalendarSnapshotBuilder`)을
    /// 거치므로, 같은 달을 앱에서 볼 때와 줄이 어긋나지 않는다.
    @MainActor
    static func monthLayout(of month: CalendarMonth) -> MonthEventLayout {
        CalendarSnapshotBuilder.monthLayout(todos: calendarSnapshots(), month: month)
    }

    /// 주간 위젯이 쓸 한 주치 막대 배치.
    @MainActor
    static func weekBars(startingAt weekStart: Date) -> WeekBars {
        CalendarSnapshotBuilder.weekBars(todos: calendarSnapshots(), weekStart: weekStart)
    }

    /// 날짜 없는 백로그 항목은 `TodoSnapshot.init?`이 걸러낸다 — 달력에 자리가 없다.
    @MainActor
    private static func calendarSnapshots() -> [TodoSnapshot] {
        allItems().compactMap { TodoSnapshot($0) }
    }
}

extension WidgetTodo {
    var color: Color {
        guard let categoryColorHex else { return .secondary }
        return CategoryColorPalette.color(forHex: categoryColorHex)
    }
}
