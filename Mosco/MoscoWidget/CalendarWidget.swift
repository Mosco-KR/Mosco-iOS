import SwiftUI
import WidgetKit

/// 이번 달 달력을 보여주는 위젯. 할 일이 있는 날엔 숫자 아래 점을 찍는다.
struct CalendarWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "MoscoCalendar", provider: CalendarProvider()) { entry in
            CalendarWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("달력")
        .description("이번 달 달력과 할 일이 있는 날을 보여줘요.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular])
    }
}

struct CalendarEntry: TimelineEntry {
    let date: Date
    /// dayKey → 그날 할 일 개수.
    let countsByDayKey: [String: Int]
    /// 잠금화면 사각 위젯에서 이번 주 아래에 붙일 오늘의 일정들.
    let todayTodos: [TodoSnapshot]
}

struct CalendarProvider: TimelineProvider {
    func placeholder(in context: Context) -> CalendarEntry {
        CalendarEntry(date: .now, countsByDayKey: [:], todayTodos: [])
    }

    func getSnapshot(in context: Context, completion: @escaping (CalendarEntry) -> Void) {
        Task { @MainActor in
            completion(makeEntry())
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<CalendarEntry>) -> Void) {
        Task { @MainActor in
            let nextMidnight = Calendar.current.startOfDay(for: .now.addingTimeInterval(86_400))
            completion(Timeline(entries: [makeEntry()], policy: .after(nextMidnight)))
        }
    }

    @MainActor
    private func makeEntry() -> CalendarEntry {
        CalendarEntry(
            date: .now,
            countsByDayKey: WidgetStore.dayCounts(inMonthOf: .now),
            // 잠금화면 한 줄에 두세 개면 충분하다 — 더 받아와도 그릴 자리가 없다.
            todayTodos: WidgetStore.todos(on: .now, limit: 3)
        )
    }
}

struct CalendarWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: CalendarEntry

    private let calendar = Calendar.current

    var body: some View {
        if family == .accessoryRectangular {
            lockScreenBody
        } else {
            homeScreenBody
        }
    }

    /// 잠금화면(사각)에는 한 달 격자가 안 들어간다 — 대신 **이번 주 일곱 칸**을
    /// 넣고 그 아래에 오늘 일정을 붙인다. 예전엔 "할 일 3개"라는 개수만 있어서
    /// 달력이라 부를 것도, 볼 것도 없었다.
    ///
    /// 잠금화면 위젯은 단색(vibrant)으로 그려지므로 색으로는 구분할 수 없다 —
    /// 오늘은 채운 원, 일정이 있는 날은 밑의 점, 나머지는 흐리게로 가른다.
    private var lockScreenBody: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 0) {
                ForEach(currentWeek, id: \.self) { day in
                    lockScreenDay(day)
                }
            }

            if entry.todayTodos.isEmpty {
                Text("오늘 할 일 없음")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            } else {
                // 두 줄까지만. 세 번째부터는 "+N"으로 접는다.
                ForEach(entry.todayTodos.prefix(2)) { todo in
                    Text(todo.timeLabel.map { "\($0) \(todo.title)" } ?? todo.title)
                        .font(.system(size: 11))
                        .lineLimit(1)
                }
                if entry.todayTodos.count > 2 {
                    Text("+\(entry.todayTodos.count - 2)")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func lockScreenDay(_ day: Date) -> some View {
        let isToday = calendar.isDateInToday(day)
        let hasTodos = (entry.countsByDayKey[day.dayKey] ?? 0) > 0

        return VStack(spacing: 1) {
            Text("\(calendar.component(.day, from: day))")
                .font(.system(size: 10, weight: isToday ? .bold : .regular))
                .frame(width: 15, height: 15)
                .background {
                    if isToday {
                        Circle().fill(.tertiary)
                    }
                }
            Circle()
                .fill(hasTodos ? AnyShapeStyle(.primary) : AnyShapeStyle(.clear))
                .frame(width: 2.5, height: 2.5)
        }
        .opacity(isToday ? 1 : 0.7)
        .frame(maxWidth: .infinity)
    }

    /// 오늘이 속한 주의 일~토.
    private var currentWeek: [Date] {
        guard let week = calendar.dateInterval(of: .weekOfYear, for: entry.date) else { return [] }
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: week.start) }
    }

    private var homeScreenBody: some View {
        VStack(spacing: 4) {
            Text("\(calendar.component(.month, from: entry.date))월")
                .font(.caption.weight(.bold))
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 0) {
                ForEach(["일", "월", "화", "수", "목", "금", "토"], id: \.self) { symbol in
                    Text(symbol)
                        .font(.system(size: 8))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }

            ForEach(Array(weeks.enumerated()), id: \.offset) { _, week in
                HStack(spacing: 0) {
                    ForEach(week, id: \.self) { day in
                        dayCell(day)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func dayCell(_ day: Date) -> some View {
        let inMonth = calendar.isDate(day, equalTo: entry.date, toGranularity: .month)
        let isToday = calendar.isDateInToday(day)
        let count = entry.countsByDayKey[day.dayKey] ?? 0

        VStack(spacing: 1) {
            Text("\(calendar.component(.day, from: day))")
                .font(.system(size: 9, weight: isToday ? .bold : .regular))
                .foregroundStyle(isToday ? Color.white : (inMonth ? .primary : .secondary))
                .frame(width: 14, height: 14)
                .background(isToday ? Color.accentColor : .clear, in: Circle())

            // 할 일이 있는 날만 점 — 개수까지 적기엔 칸이 너무 작다.
            Circle()
                .fill(inMonth && count > 0 ? Color.accentColor : .clear)
                .frame(width: 3, height: 3)
        }
        .opacity(inMonth ? 1 : 0.35)
        .frame(maxWidth: .infinity)
    }

    /// 이번 달이 걸쳐 있는 주들을 일~토 7칸씩.
    private var weeks: [[Date]] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: entry.date),
              let firstWeek = calendar.dateInterval(of: .weekOfYear, for: monthInterval.start)
        else { return [] }

        var result: [[Date]] = []
        var cursor = firstWeek.start
        while cursor < monthInterval.end {
            var week: [Date] = []
            for offset in 0..<7 {
                week.append(calendar.date(byAdding: .day, value: offset, to: cursor) ?? cursor)
            }
            result.append(week)
            cursor = calendar.date(byAdding: .weekOfYear, value: 1, to: cursor) ?? monthInterval.end
        }
        return result
    }
}

// `dayKeyForWidget`을 여기서 따로 만들어 쓰고 있었는데("%04d-%02d-%02d"), 정작 키를
// 만드는 쪽(WidgetStore.dayCounts)은 앱의 `Date.dayKey`(epoch 초 문자열)를 썼다.
// 두 규칙이 달라서 조회가 **한 번도 맞지 않았고**, 그래서 달력 위젯에 점이 하나도
// 안 찍혔다. `Date+Korean.swift`는 Shared라 위젯 타겟에도 있으니 그걸 그대로 쓴다.
