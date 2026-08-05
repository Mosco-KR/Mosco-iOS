import SwiftUI
import WidgetKit

/// 이번 주 달력 위젯. 한 주만 보여주는 대신 한 칸이 넓어서, 달력 위젯 중
/// **제목이 붙은 할 일 블록**이 제대로 보이는 크기다. 여러 날에 걸친 일정은
/// 앱에서와 똑같이 하나의 막대로 이어진다.
struct WeekCalendarWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "MoscoWeekCalendar", provider: WeekCalendarProvider()) { entry in
            WeekCalendarWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
                .widgetURL(WidgetDeepLink.url(kind: "week_calendar"))
        }
        .configurationDisplayName("주간 달력")
        .description("이번 주 일곱 칸에 할 일 블록을 보여줘요.")
        // 중형 하나만 남겼다. 소형은 한 칸이 22pt라 제목이 못 들어갔고, 대형은
        // 한 주치 블록으로 채우기엔 세로가 너무 남아서 아래가 늘 허전했다 —
        // 아래를 "오늘 할 일"로 메워봤지만 그건 결국 두 위젯을 억지로 붙인 것이라,
        // 오늘 할 일을 보고 싶으면 그 위젯을 쓰는 게 맞다.
        .supportedFamilies([.systemMedium])
        .contentMarginsDisabled()
    }
}

struct WeekCalendarEntry: TimelineEntry {
    let date: Date
    /// 이번 주 일~토.
    let days: [Date]
    let bars: WeekBars
    /// 헤더 오른쪽에 붙일 오늘 남은 개수.
    let remainingToday: Int
}

struct WeekCalendarProvider: TimelineProvider {
    func placeholder(in context: Context) -> WeekCalendarEntry {
        WeekCalendarEntry(
            date: .now,
            days: WeekCalendarProvider.week(of: .now),
            bars: .empty,
            remainingToday: 0
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (WeekCalendarEntry) -> Void) {
        Task { @MainActor in completion(makeEntry()) }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WeekCalendarEntry>) -> Void) {
        Task { @MainActor in
            AnalyticsBuffer.record(.widgetRendered(kind: "week_calendar", family: "\(context.family)"))
            let nextMidnight = Calendar.current.startOfDay(for: .now.addingTimeInterval(86_400))
            completion(Timeline(entries: [makeEntry()], policy: .after(nextMidnight)))
        }
    }

    @MainActor
    private func makeEntry() -> WeekCalendarEntry {
        let days = WeekCalendarProvider.week(of: .now)
        let today = Calendar.current.startOfDay(for: .now)
        return WeekCalendarEntry(
            date: .now,
            days: days,
            bars: days.first.map { WidgetStore.weekBars(startingAt: $0) } ?? .empty,
            remainingToday: WidgetStore.todos(on: today, limit: 50).count { !$0.isCompleted }
        )
    }

    /// 주어진 날이 속한 주의 일~토.
    static func week(of date: Date) -> [Date] {
        let calendar = Calendar.current
        guard let interval = calendar.dateInterval(of: .weekOfYear, for: date) else { return [] }
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: interval.start) }
    }
}

struct WeekCalendarWidgetView: View {
    let entry: WeekCalendarEntry

    private let calendar = Calendar.current

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Text(rangeLabel)
                    .font(.system(size: 12, weight: .bold))
                Spacer(minLength: 0)
                if entry.remainingToday > 0 {
                    Text("오늘 \(entry.remainingToday)개")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
            }

            GeometryReader { proxy in
                let columnWidth = proxy.size.width / 7
                let fontSize: CGFloat = 11
                // 요일 글자 + 간격 + 날짜 원. 어림하지 않고 그리는 쪽과 같은 식을 쓴다.
                let headerHeight = (fontSize - 2) * 1.3 + 1 + WidgetDayNumber.height(fontSize: fontSize)
                let barsHeight = max(proxy.size.height - headerHeight, 0)
                let metrics = WidgetBarMetrics.fitting(
                    columnWidth: columnWidth,
                    availableHeight: barsHeight,
                    preferredBarHeight: 14
                )

                VStack(spacing: 2) {
                    HStack(spacing: 0) {
                        ForEach(Array(entry.days.enumerated()), id: \.offset) { index, day in
                            VStack(spacing: 1) {
                                Text(KoreanCalendar.weekdaySymbols[index])
                                    .font(.system(size: fontSize - 2))
                                    .foregroundStyle(.secondary)
                                WidgetDayNumber(
                                    day: day,
                                    isToday: calendar.isDateInToday(day),
                                    inMonth: true,
                                    fontSize: fontSize
                                )
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                    .frame(height: headerHeight)

                    WidgetWeekBarsView(bars: entry.bars, metrics: metrics)
                        .frame(height: metrics.height(rows: entry.bars.rowCount), alignment: .topLeading)

                    Spacer(minLength: 0)
                }
            }
        }
        // 월 달력과 같은 좌우 여백 — 위젯끼리 글자가 시작하는 자리가 어긋나면
        // 나란히 놓았을 때 그게 먼저 눈에 띈다.
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    private var rangeLabel: String {
        guard let first = entry.days.first, let last = entry.days.last else { return "" }
        let firstMonth = calendar.component(.month, from: first)
        let lastMonth = calendar.component(.month, from: last)
        let firstDay = calendar.component(.day, from: first)
        let lastDay = calendar.component(.day, from: last)
        return firstMonth == lastMonth
            ? "\(firstMonth)월 \(firstDay)–\(lastDay)일"
            : "\(firstMonth)월 \(firstDay)일 – \(lastMonth)월 \(lastDay)일"
    }
}
