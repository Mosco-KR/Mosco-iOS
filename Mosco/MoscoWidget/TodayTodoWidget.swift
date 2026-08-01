import SwiftUI
import WidgetKit

/// 오늘 할 일을 보여주는 위젯. 홈 화면(소·중)과 잠금화면(인라인·원형·사각) 모두 지원한다.
/// 탭하면 앱이 열리는 것 말고 위젯 자체가 하는 동작은 없다.
struct TodayTodoWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "MoscoTodayTodo", provider: TodayTodoProvider()) { entry in
            TodayTodoWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("오늘 할 일")
        .description("오늘 해야 할 일을 모아서 보여줘요.")
        .supportedFamilies([
            .systemSmall, .systemMedium,
            .accessoryInline, .accessoryCircular, .accessoryRectangular
        ])
    }
}

struct TodayTodoEntry: TimelineEntry {
    let date: Date
    let todos: [TodoSnapshot]
    /// 완료까지 포함한 그날 전체 개수 — "3/5" 같은 요약에 쓴다.
    let totalCount: Int
    let completedCount: Int
}

struct TodayTodoProvider: TimelineProvider {
    func placeholder(in context: Context) -> TodayTodoEntry {
        TodayTodoEntry(
            date: .now,
            todos: [
                TodoSnapshot(id: UUID(), title: "팀 회의", isCompleted: false, categoryColorHex: nil, timeLabel: "오후 2시"),
                TodoSnapshot(id: UUID(), title: "장보기", isCompleted: false, categoryColorHex: nil, timeLabel: nil)
            ],
            totalCount: 2,
            completedCount: 0
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (TodayTodoEntry) -> Void) {
        Task { @MainActor in completion(makeEntry()) }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TodayTodoEntry>) -> Void) {
        Task { @MainActor in
            // 날짜가 바뀌면 "오늘"이 달라지므로 자정에 다시 그린다. 그 사이 앱에서
            // 할 일을 고치면 앱이 reloadAllTimelines로 따로 깨운다.
            let entry = makeEntry()
            let nextMidnight = Calendar.current.startOfDay(for: .now.addingTimeInterval(86_400))
            completion(Timeline(entries: [entry], policy: .after(nextMidnight)))
        }
    }

    @MainActor
    private func makeEntry() -> TodayTodoEntry {
        let today = Calendar.current.startOfDay(for: .now)
        let all = WidgetStore.todos(on: today, limit: 50)
        return TodayTodoEntry(
            date: .now,
            todos: Array(all.prefix(6)),
            totalCount: all.count,
            completedCount: all.count { $0.isCompleted }
        )
    }
}

struct TodayTodoWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: TodayTodoEntry

    private var remaining: Int { entry.totalCount - entry.completedCount }

    var body: some View {
        switch family {
        case .accessoryInline:
            // 잠금화면 한 줄짜리는 글자만 허용된다.
            Text(remaining > 0 ? "할 일 \(remaining)개 남음" : "할 일 완료")

        case .accessoryCircular:
            ZStack {
                AccessoryWidgetBackground()
                VStack(spacing: 0) {
                    Image(systemName: "checklist")
                        .font(.system(size: 11, weight: .semibold))
                    Text("\(remaining)")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                }
            }

        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 2) {
                Text(remaining > 0 ? "오늘 할 일 \(remaining)개" : "오늘 할 일 없음")
                    .font(.headline)
                ForEach(entry.todos.filter { !$0.isCompleted }.prefix(2)) { todo in
                    Text(todo.title)
                        .font(.caption)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

        default:
            homeScreenBody
        }
    }

    private var homeScreenBody: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("오늘 할 일")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                if entry.totalCount > 0 {
                    Text("\(entry.completedCount)/\(entry.totalCount)")
                        .font(.caption2.weight(.semibold).monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }

            if entry.todos.isEmpty {
                Spacer()
                Text("오늘 할 일이 없어요")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                Spacer()
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(entry.todos.prefix(family == .systemSmall ? 3 : 5)) { todo in
                        row(todo)
                    }
                }
                Spacer(minLength: 0)
            }
        }
    }

    private func row(_ todo: TodoSnapshot) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(todo.color)
                .frame(width: 6, height: 6)
                .opacity(todo.isCompleted ? 0.4 : 1)

            Text(todo.title)
                .font(.caption)
                .strikethrough(todo.isCompleted)
                .foregroundStyle(todo.isCompleted ? .secondary : .primary)
                .lineLimit(1)

            if family != .systemSmall, let timeLabel = todo.timeLabel {
                Spacer(minLength: 4)
                Text(timeLabel)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
