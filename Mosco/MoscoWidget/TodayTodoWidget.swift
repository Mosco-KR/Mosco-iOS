import SwiftUI
import WidgetKit

/// 오늘 할 일을 보여주는 위젯.
///
/// 각 줄의 체크 동그라미는 진짜 버튼이라, **위젯에서 바로 완료 처리**된다
/// (`ToggleTodoCompletionIntent`). 앱은 열리지 않는다.
struct TodayTodoWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "MoscoTodayTodo", provider: TodayTodoProvider()) { entry in
            TodayTodoWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
                .widgetURL(WidgetDeepLink.url(kind: "today_todo"))
        }
        .configurationDisplayName("오늘 할 일")
        .description("오늘 해야 할 일을 블록으로 모아서 보여줘요.")
        // 대형을 뺐다 — 오늘 할 일이 12줄까지 늘어날 일은 드물어서 아래가 늘
        // 비었다. 소·중형이면 오늘치는 다 들어간다.
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct TodayTodoEntry: TimelineEntry {
    let date: Date
    let todos: [WidgetTodo]
    /// 완료까지 포함한 그날 전체 개수 — "3/5" 같은 요약에 쓴다.
    let totalCount: Int
    let completedCount: Int
}

struct TodayTodoProvider: TimelineProvider {
    func placeholder(in context: Context) -> TodayTodoEntry {
        TodayTodoEntry(
            date: .now,
            todos: [
                WidgetTodo(id: UUID(), title: "팀 회의", isCompleted: false, categoryColorHex: nil, timeLabel: "오후 2시"),
                WidgetTodo(id: UUID(), title: "장보기", isCompleted: false, categoryColorHex: nil, timeLabel: nil)
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
            AnalyticsBuffer.recordOncePerDay(
            .widgetRendered(kind: "today_todo", family: "\(context.family)"),
            token: "today_todo.\(context.family)"
        )
            // 날짜가 바뀌면 "오늘"이 달라지므로 자정에 다시 그린다. 그 사이 앱에서
            // 할 일을 고치면 앱이 백그라운드로 갈 때 타임라인을 다시 잡는다
            // (`RootTabView`의 scenePhase 처리).
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
            todos: Array(all.prefix(10)),
            totalCount: all.count,
            completedCount: all.count { $0.isCompleted }
        )
    }
}

struct TodayTodoWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: TodayTodoEntry

    var body: some View {
        homeScreenBody
    }

    private var homeScreenBody: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("오늘 할 일")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                if entry.totalCount > 0 {
                    Text("\(entry.completedCount)/\(entry.totalCount)")
                        .font(.system(size: 12, weight: .semibold).monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }

            if entry.todos.isEmpty {
                Spacer()
                Text("오늘 할 일 없음")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                Spacer()
            } else {
                // 줄 간격이 줄 자체의 높이를 정한다 — 카드 배경을 걷어낸 지금은
                // 이 간격만으로 목록의 밀도가 결정된다.
                VStack(alignment: .leading, spacing: 7) {
                    ForEach(entry.todos.prefix(visibleCount)) { todo in
                        WidgetTodoRow(
                            todo: todo,
                            day: today,
                            fontSize: family == .systemSmall ? 11 : 13,
                            showsTime: family != .systemSmall
                        )
                    }
                    if entry.totalCount > visibleCount {
                        Text("+\(entry.totalCount - visibleCount)개 더")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 0)
            }
        }
    }

    private var today: Date { Calendar.current.startOfDay(for: entry.date) }

    private var visibleCount: Int {
        switch family {
        case .systemSmall: 4
        case .systemLarge: 12
        default: 5
        }
    }
}
