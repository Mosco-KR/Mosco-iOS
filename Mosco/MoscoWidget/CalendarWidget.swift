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
}

struct CalendarProvider: TimelineProvider {
    func placeholder(in context: Context) -> CalendarEntry {
        CalendarEntry(date: .now, countsByDayKey: [:])
    }

    func getSnapshot(in context: Context, completion: @escaping (CalendarEntry) -> Void) {
        Task { @MainActor in
            completion(CalendarEntry(date: .now, countsByDayKey: WidgetStore.dayCounts(inMonthOf: .now)))
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<CalendarEntry>) -> Void) {
        Task { @MainActor in
            let entry = CalendarEntry(date: .now, countsByDayKey: WidgetStore.dayCounts(inMonthOf: .now))
            let nextMidnight = Calendar.current.startOfDay(for: .now.addingTimeInterval(86_400))
            completion(Timeline(entries: [entry], policy: .after(nextMidnight)))
        }
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

    /// 잠금화면은 좁아서 달력 격자가 안 들어간다 — 오늘 날짜와 개수만.
    private var lockScreenBody: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(entry.date.formatted(.dateTime.month(.wide).day()))
                .font(.headline)
            Text(todayCount > 0 ? "할 일 \(todayCount)개" : "할 일 없음")
                .font(.caption)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var todayCount: Int {
        entry.countsByDayKey[calendar.startOfDay(for: entry.date).dayKeyForWidget] ?? 0
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
        let count = entry.countsByDayKey[day.dayKeyForWidget] ?? 0

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

private extension Date {
    /// 앱의 dayKey와 같은 규칙 — 위젯 타겟은 앱 소스를 전부 안 가져오므로 여기 둔다.
    var dayKeyForWidget: String {
        let components = Calendar.current.dateComponents([.year, .month, .day], from: self)
        return String(format: "%04d-%02d-%02d", components.year ?? 0, components.month ?? 0, components.day ?? 0)
    }
}
