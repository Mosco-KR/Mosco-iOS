import Foundation
import SwiftData
import SwiftUI

/// 위젯이 그릴 때 필요한 것만 담은 값 타입. SwiftData 모델(@Model 클래스)을 타임라인
/// 엔트리에 그대로 넣으면 위젯 프로세스가 다시 살아날 때 컨텍스트가 없어 접근이
/// 위험하므로, 읽는 시점에 값으로 복사해둔다.
struct TodoSnapshot: Identifiable, Hashable {
    let id: UUID
    let title: String
    let isCompleted: Bool
    let categoryColorHex: String?
    /// 시작 시각 표기("오후 3시"). 종일 일정이면 nil.
    let timeLabel: String?
}

/// 그날 할 일이 몇 개인지만 아는, 캘린더 위젯용 요약.
struct DayCountSnapshot: Hashable {
    let date: Date
    let count: Int
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

    /// 그날에 걸치는(반복 포함) 할 일을, 미완료 먼저 시간순으로.
    @MainActor
    static func todos(on day: Date, limit: Int) -> [TodoSnapshot] {
        guard let container else { return [] }
        let context = container.mainContext
        guard let all = try? context.fetch(FetchDescriptor<TodoItem>()) else { return [] }

        return all
            .filter { $0.occurs(on: day) }
            .sorted { lhs, rhs in
                let lhsDone = lhs.isCompleted(on: day)
                let rhsDone = rhs.isCompleted(on: day)
                if lhsDone != rhsDone { return !lhsDone }
                return lhs.sortableMinutes < rhs.sortableMinutes
            }
            .prefix(limit)
            .map { todo in
                TodoSnapshot(
                    id: todo.id,
                    title: todo.title,
                    isCompleted: todo.isCompleted(on: day),
                    categoryColorHex: todo.category?.colorHex,
                    timeLabel: todo.startTime?.koreanTime
                )
            }
    }

    /// 이번 달 날짜별 할 일 개수 — 캘린더 위젯에서 점 표시에 쓴다.
    @MainActor
    static func dayCounts(inMonthOf date: Date) -> [String: Int] {
        guard let container else { return [:] }
        let context = container.mainContext
        guard let all = try? context.fetch(FetchDescriptor<TodoItem>()) else { return [:] }

        let calendar = Calendar.current
        guard let interval = calendar.dateInterval(of: .month, for: date) else { return [:] }

        var result: [String: Int] = [:]
        var cursor = interval.start
        while cursor < interval.end {
            let count = all.count { $0.occurs(on: cursor) }
            if count > 0 { result[cursor.dayKey] = count }
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }
        return result
    }
}

extension TodoSnapshot {
    var color: Color {
        guard let categoryColorHex else { return .secondary }
        return CategoryColorPalette.color(forHex: categoryColorHex)
    }
}
