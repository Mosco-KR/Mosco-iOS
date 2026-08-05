import SwiftUI
import WidgetKit

/// 이번 달 달력 위젯. 날짜 아래에 **할 일 블록**을 그린다 — 예전엔 일정이 있는
/// 날에 점 하나만 찍었는데, 그건 "뭔가 있다"까지만 알려주고 정작 무엇이 며칠에
/// 걸쳐 있는지는 못 보여줬다. 앱 격자와 같은 계산(`CalendarSnapshotBuilder`)을
/// 쓰므로 같은 달을 앱에서 열어도 줄이 어긋나지 않는다.
///
/// `kind`는 예전 이름(`MoscoCalendar`)을 그대로 둔다 — 바꾸면 이미 홈 화면에
/// 올려둔 위젯이 사라진다.
struct MonthCalendarWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "MoscoCalendar", provider: MonthCalendarProvider()) { entry in
            MonthCalendarWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
                .widgetURL(WidgetDeepLink.url(kind: "month_calendar"))
        }
        .configurationDisplayName("월 달력")
        .description("이번 달 달력에 할 일 블록을 함께 보여줘요.")
        // 대형 하나만. 소형·중형은 한 주에 5~8pt밖에 안 남아 블록에 제목을 못
        // 붙이고, 그러면 남는 건 색 막대뿐이라 결국 "일정이 있다"는 점 표시와
        // 다를 바 없어진다 — 이 위젯을 다시 만든 이유가 바로 그거였다.
        //
        // 잠금화면(사각)도 뺐다. 160×72pt에 한 달 격자를 넣으면 한 칸이 22pt라
        // 결국 같은 문제로 돌아가고, 단색 렌더라 공휴일·주말 색도 안 산다.
        // 잠금화면은 별도 방식으로 다시 다룬다.
        .supportedFamilies([.systemLarge])
        // 기본 여백(16pt)이 붙으면 6주 격자에 블록 자리가 안 남는다. 여백은
        // 아래에서 직접 주되, 글자가 모서리에 붙지 않게 넉넉히 준다.
        .contentMarginsDisabled()
    }
}

struct MonthCalendarEntry: TimelineEntry {
    let date: Date
    let month: CalendarMonth
    let grid: MonthLayout
    let layout: MonthEventLayout
}

struct MonthCalendarProvider: TimelineProvider {
    func placeholder(in context: Context) -> MonthCalendarEntry {
        let month = CalendarMonth.containing(.now)
        return MonthCalendarEntry(
            date: .now,
            month: month,
            grid: MonthLayout.make(month),
            layout: .empty
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (MonthCalendarEntry) -> Void) {
        Task { @MainActor in completion(makeEntry()) }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<MonthCalendarEntry>) -> Void) {
        Task { @MainActor in
            // 실제로 홈 화면에 올라가 있을 때만 불린다(`getSnapshot`은 갤러리
            // 미리보기라 세면 안 된다) — 어떤 위젯이 정말 쓰이는지의 유일한 신호다.
            AnalyticsBuffer.record(.widgetRendered(kind: "month_calendar", family: "\(context.family)"))
            // 날짜가 바뀌면 "오늘" 표시가 옮겨가야 하므로 자정에 다시 그린다.
            let nextMidnight = Calendar.current.startOfDay(for: .now.addingTimeInterval(86_400))
            completion(Timeline(entries: [makeEntry()], policy: .after(nextMidnight)))
        }
    }

    @MainActor
    private func makeEntry() -> MonthCalendarEntry {
        let month = CalendarMonth.containing(.now)
        return MonthCalendarEntry(
            date: .now,
            month: month,
            grid: MonthLayout.make(month),
            layout: WidgetStore.monthLayout(of: month)
        )
    }
}

struct MonthCalendarWidgetView: View {
    let entry: MonthCalendarEntry

    private let calendar = Calendar.current

    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Text(monthLabel)
                    .font(.system(size: 15, weight: .bold))
                Spacer(minLength: 0)
            }

            WidgetWeekdayHeader(fontSize: 10)

            GeometryReader { proxy in
                let weekCount = max(entry.grid.weeks.count, 1)
                let rowHeight = proxy.size.height / CGFloat(weekCount)
                let columnWidth = proxy.size.width / 7

                VStack(spacing: 0) {
                    ForEach(Array(entry.grid.weeks.enumerated()), id: \.offset) { index, week in
                        weekRow(
                            week,
                            bars: entry.layout.week(index),
                            rowHeight: rowHeight,
                            columnWidth: columnWidth
                        )
                    }
                }
            }
        }
        // 시스템 기본 여백(16pt)에 맞춘 좌우 여백. 예전 8pt는 "2026년 8월"이
        // 모서리에 붙어 보여서 위젯이 잘린 것처럼 불안했다. 위아래는 격자에
        // 줄 자리를 남겨야 해서 조금 줄인다.
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    private func weekRow(
        _ week: MonthLayout.WeekRow,
        bars: WeekBars,
        rowHeight: CGFloat,
        columnWidth: CGFloat
    ) -> some View {
        // 날짜 숫자 줄과 블록 줄의 몫을 여기서 가른다. 숫자는 읽히기만 하면 되니
        // 최소한만 가져가고 나머지를 전부 블록에 준다.
        let fontSize = min(max(rowHeight * 0.2, 8), 11)
        let headerHeight = WidgetDayNumber.height(fontSize: fontSize)
        let barsHeight = max(rowHeight - headerHeight - 1, 0)
        let metrics = WidgetBarMetrics.fitting(
            columnWidth: columnWidth,
            availableHeight: barsHeight,
            preferredBarHeight: 10
        )

        return VStack(spacing: 1) {
            HStack(spacing: 0) {
                ForEach(Array(week.dates.enumerated()), id: \.offset) { column, day in
                    WidgetDayNumber(
                        day: day,
                        isToday: calendar.isDateInToday(day),
                        inMonth: week.inMonth[column],
                        fontSize: fontSize
                    )
                }
            }
            .frame(height: headerHeight)

            WidgetWeekBarsView(bars: bars, metrics: metrics)
                .frame(height: barsHeight, alignment: .topLeading)
        }
        .frame(height: rowHeight, alignment: .top)
    }

    private var monthLabel: String { "\(entry.month.year)년 \(entry.month.month)월" }
}
