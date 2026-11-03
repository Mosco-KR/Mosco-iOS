import SwiftUI
import WidgetKit

/// 가장 가까운 디데이 하나와 남은 날을 세는 위젯.
///
/// ## 왜 하나만 보여주나
///
/// 앱의 디데이 카드도 **가장 가까운 하나만 채우고 나머지는 옅게** 둔다. 이 위젯은
/// 그보다도 작아서, 여러 개를 줄여 넣으면 숫자가 전부 작아져 정작 "며칠 남았나"가
/// 안 읽힌다. 디데이가 답하는 질문은 하나다 — **다음은 이것, 며칠 남음.**
///
/// 무엇이 디데이로 서는지는 앱과 **같은 판단**을 쓴다(`TodoListPage.dDays`). 앱은
/// 세 개가 보이는데 위젯은 다른 하나가 서 있으면, 둘 중 어느 쪽이 맞는지 알 수 없다.
struct DDayWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "MoscoDDay", provider: DDayProvider()) { entry in
            DDayWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
                .widgetURL(WidgetDeepLink.url(kind: "dday"))
        }
        .configurationDisplayName("디데이")
        .description("가장 가까운 디데이와 남은 날을 세어요.")
        // 작은 것 하나면 충분하다 — 숫자 하나와 제목 한 줄이 전부라, 넓은 자리를
        // 주면 가운데가 비어 보인다.
        .supportedFamilies([.systemSmall])
    }
}

struct DDayEntry: TimelineEntry {
    let date: Date
    /// 셀 것이 없으면 nil — 그때는 "표시해 둔 디데이가 없어요"라고 말한다.
    let title: String?
    /// 남은 날. 음수면 지난 디데이(`D+3`).
    let daysLeft: Int
    /// 그날 날짜 — 숫자 아래 작은 글씨로.
    let dayLabel: String?
}

struct DDayProvider: TimelineProvider {
    func placeholder(in context: Context) -> DDayEntry {
        DDayEntry(date: .now, title: String(localized: "제주 여행"), daysLeft: 3, dayLabel: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (DDayEntry) -> Void) {
        Task { @MainActor in completion(makeEntry()) }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<DDayEntry>) -> Void) {
        Task { @MainActor in
            AnalyticsBuffer.recordOncePerDay(
                .widgetRendered(kind: "dday", family: "\(context.family)"),
                token: "dday.\(context.family)"
            )
            // 남은 날은 자정에만 바뀐다 — 그때 다시 그린다.
            let nextMidnight = Calendar.current.startOfDay(for: .now.addingTimeInterval(86_400))
            completion(Timeline(entries: [makeEntry()], policy: .after(nextMidnight)))
        }
    }

    @MainActor
    private func makeEntry() -> DDayEntry {
        let today = Calendar.current.startOfDay(for: .now)
        guard let nearest = WidgetStore.nearestDDay(today: today) else {
            return DDayEntry(date: .now, title: nil, daysLeft: 0, dayLabel: nil)
        }
        return DDayEntry(
            date: .now,
            title: nearest.title,
            daysLeft: Calendar.current.dateComponents([.day], from: today, to: nearest.day).day ?? 0,
            dayLabel: nearest.day.localizedMonthDayWeekday
        )
    }
}

struct DDayWidgetView: View {
    let entry: DDayEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let title = entry.title {
                Text(label)
                    .font(.system(size: 34, weight: .heavy, design: .rounded).monospacedDigit())
                    .foregroundStyle(CategoryColorPalette.accent)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)

                Spacer(minLength: 6)

                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(2)

                if let dayLabel = entry.dayLabel {
                    Text(dayLabel)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            } else {
                Spacer()
                Text("표시해 둔 디데이가 없어요")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                Text("할 일을 꾹 눌러 디데이로 표시해요")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                Spacer()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    /// `D-7` · `D-DAY` · `D+3`. 지난 디데이도 센다 — 지났다고 숨기면 왜 사라졌는지
    /// 알 수 없다(앱의 디데이 카드와 같은 규칙).
    private var label: String {
        switch entry.daysLeft {
        case 0: String(localized: "D-DAY")
        case 1...: String(localized: "D-\(entry.daysLeft)")
        default: String(localized: "D+\(-entry.daysLeft)")
        }
    }
}
