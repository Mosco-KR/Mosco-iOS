import SwiftUI
import WidgetKit

/// 위젯 한 칸에서 막대(할 일 블록)가 쓸 치수. 위젯은 크기가 가족(family)마다
/// 고정이라 앱처럼 페이지 높이로 나눌 수 없어서, 그릴 자리를 받은 뒤 거기에
/// 맞춰 정한다.
///
/// 제목을 넣을지 말지가 여기서 갈린다. 작은 위젯의 한 칸은 22pt 남짓이라
/// 글자를 넣어봐야 한 자도 안 보이고, 대신 색 막대만으로도 "며칠에 걸친 무엇이
/// 몇 개 있는지"는 읽힌다 — 점 하나보다 훨씬 많은 정보다.
struct WidgetBarMetrics: Equatable {
    let columnWidth: CGFloat
    let barHeight: CGFloat
    let barSpacing: CGFloat
    /// 이 자리에 들어가는 막대 줄 수.
    let capacity: Int

    /// 제목 없이 색만으로 그릴 때의 막대 높이. 작은 위젯의 한 칸에서 두 줄은
    /// 나오게 하려고 잡은 값이다.
    static let thinBarHeight: CGFloat = 3

    /// 제목은 막대가 충분히 높고 칸이 충분히 넓을 때만. 둘 중 하나만 모자라도
    /// 잘린 글자만 남아서 오히려 안 보이는 게 낫다.
    var showsTitle: Bool { barHeight >= 9 && columnWidth >= 30 }

    var titleFontSize: CGFloat { min(max(barHeight - 4, 7), 10) }

    /// 막대 `rows`줄이 차지하는 높이(자리 수를 넘지 않게 잘라서).
    func height(rows: Int) -> CGFloat {
        let drawn = min(max(rows, 0), capacity)
        guard drawn > 0 else { return 0 }
        return CGFloat(drawn) * barHeight + CGFloat(drawn - 1) * barSpacing
    }

    /// 주어진 자리에 맞춰 치수를 정한다. 제목이 들어갈 만하면 `preferredBarHeight`를
    /// 그대로 쓰고, 아니면 얇은 막대로 떨어뜨려 대신 더 많은 줄을 보여준다.
    static func fitting(
        columnWidth: CGFloat,
        availableHeight: CGFloat,
        preferredBarHeight: CGFloat
    ) -> WidgetBarMetrics {
        let titled = columnWidth >= 30 && availableHeight >= preferredBarHeight
        let barHeight = titled ? preferredBarHeight : thinBarHeight
        // 얇은 막대끼리는 간격까지 좁혀야 한 칸에 두 줄이 들어간다.
        let spacing: CGFloat = titled ? 1.5 : 1
        let capacity = max(Int((availableHeight + spacing) / (barHeight + spacing)), 0)
        return WidgetBarMetrics(
            columnWidth: columnWidth,
            barHeight: barHeight,
            barSpacing: spacing,
            capacity: capacity
        )
    }
}

/// 한 주(週)의 할 일 블록들. 앱의 `WeekBarsView`와 같은 표현이다 — 앞쪽에 카테고리
/// 색 세로 바, 옅은 톤 채움, 넘치면 마지막 줄을 "+N"에 내주는 것까지.
///
/// 좌표는 `CalendarSnapshotBuilder`가 이미 확정해서 넘겨준다(앱과 **같은** 계산).
/// 여기서는 `.offset`으로 자리에 놓기만 한다.
struct WidgetWeekBarsView: View {
    let bars: WeekBars
    let metrics: WidgetBarMetrics

    var body: some View {
        // 넘치는 게 있으면 마지막 한 줄을 "+N" 자리로 비워둔다(앱과 같은 규칙).
        let hasOverflow = bars.rowCount > metrics.capacity
        let limit = hasOverflow ? metrics.capacity - 1 : metrics.capacity

        ZStack(alignment: .topLeading) {
            if limit > 0 {
                ForEach(bars.bars.filter { $0.row < limit }) { bar in
                    barView(bar)
                }
            }
            if hasOverflow {
                ForEach(overflowMarks(limit: limit)) { mark in
                    overflowLabel(count: mark.count, column: mark.column, row: max(limit, 0))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    /// 잘린 막대가 있는 열과, 그 열에서 몇 개가 잘렸는지.
    private struct OverflowMark: Identifiable {
        let column: Int
        let count: Int
        var id: Int { column }
    }

    private func overflowMarks(limit: Int) -> [OverflowMark] {
        var counts = [Int](repeating: 0, count: 7)
        for bar in bars.bars where bar.row >= limit {
            for column in bar.startColumn...bar.endColumn where counts.indices.contains(column) {
                counts[column] += 1
            }
        }
        return counts.enumerated().compactMap {
            $0.element > 0 ? OverflowMark(column: $0.offset, count: $0.element) : nil
        }
    }

    @ViewBuilder
    private func overflowLabel(count: Int, column: Int, row: Int) -> some View {
        // 얇은 막대 모드에서는 "+N"을 쓸 높이가 없다 — 그 줄도 막대로 채우는 게 낫다.
        if metrics.showsTitle {
            Text("+\(count)")
                .font(.system(size: 8, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: metrics.columnWidth, height: metrics.barHeight, alignment: .leading)
                .padding(.leading, 3)
                .offset(x: metrics.columnWidth * CGFloat(column), y: rowOffset(row))
        }
    }

    private func rowOffset(_ row: Int) -> CGFloat {
        CGFloat(row) * (metrics.barHeight + metrics.barSpacing)
    }

    private func barView(_ bar: BarSpec) -> some View {
        let spanWidth = metrics.columnWidth * CGFloat(bar.endColumn - bar.startColumn + 1)
        let radius: CGFloat = metrics.showsTitle ? 4 : 1.75
        let shape = UnevenRoundedRectangle(
            topLeadingRadius: bar.continuesBefore ? 0 : radius,
            bottomLeadingRadius: bar.continuesBefore ? 0 : radius,
            bottomTrailingRadius: bar.continuesAfter ? 0 : radius,
            topTrailingRadius: bar.continuesAfter ? 0 : radius
        )
        let color = barColor(bar)

        return HStack(spacing: 2.5) {
            if metrics.showsTitle {
                if !bar.continuesBefore {
                    // 반복 일정은 이 바를 소문자 i 모양(점 + 막대)으로 바꿔 한 번짜리(|)와
                    // 구분한다 — 앱 격자와 같은 표기다.
                    VStack(spacing: 1) {
                        if bar.isRepeating {
                            Circle().fill(color).frame(width: 2, height: 2)
                        }
                        Capsule().fill(color)
                    }
                    .frame(width: 2)
                    .padding(.vertical, 2.5)
                }

                Text(bar.title)
                    .font(.system(size: metrics.titleFontSize, weight: .semibold))
                    .strikethrough(bar.isCompleted)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    // 자르기 전에 먼저 줄여서 최대한 많은 글자를 보여준다.
                    .minimumScaleFactor(0.7)
                    .truncationMode(.tail)
            }
        }
        .padding(.horizontal, metrics.showsTitle ? 2.5 : 0)
        // 폭을 고정하면 Text가 알아서 잘리므로 clipShape가 필요 없다.
        .frame(width: max(spanWidth - 1.5, 0), height: metrics.barHeight, alignment: .leading)
        .background(shape.fill(color.opacity(metrics.showsTitle ? 0.16 : 0.85)))
        .overlay(metrics.showsTitle ? shape.strokeBorder(color.opacity(0.32), lineWidth: 0.75) : nil)
        .opacity(bar.isCompleted ? 0.45 : (bar.isDimmed ? 0.35 : 1))
        .offset(x: metrics.columnWidth * CGFloat(bar.startColumn), y: rowOffset(bar.row))
    }

    private func barColor(_ bar: BarSpec) -> Color {
        guard let hex = bar.categoryColorHex else { return .secondary }
        return CategoryColorPalette.color(forHex: hex)
    }
}

/// 달력 위젯들이 공유하는 날짜 숫자 한 칸.
struct WidgetDayNumber: View {
    let day: Date
    let isToday: Bool
    let inMonth: Bool
    let fontSize: CGFloat

    private static let calendar = Calendar.current

    /// 이 글자 크기로 그렸을 때 실제로 차지하는 높이. 부르는 쪽이 "숫자 줄" 높이를
    /// 따로 어림하면 원 지름과 어긋나 한 줄 넘치거나, 남는 자리를 잘못 계산해
    /// 막대 한 줄이 통째로 사라진다 — 그래서 여기서 한 번만 정한다.
    static func height(fontSize: CGFloat) -> CGFloat { fontSize + 4 }

    var body: some View {
        let diameter = Self.height(fontSize: fontSize)
        Text("\(Self.calendar.component(.day, from: day))")
            .font(.system(size: fontSize, weight: isToday ? .bold : .regular))
            .foregroundStyle(todayForeground)
            .frame(width: diameter, height: diameter)
            .background {
                if isToday {
                    Circle().fill(Color.accentColor)
                }
            }
            .opacity(inMonth ? 1 : 0.35)
            .frame(maxWidth: .infinity)
    }

    /// 일요일·공휴일은 빨강, 토요일은 파랑 — 앱 격자와 **같은 규칙**을 쓴다
    /// (`CalendarDayTone`).
    private var todayForeground: Color {
        // 채운 원 위의 글자는 빼서 쓴다.
        isToday ? .white : CalendarDayTone.of(day).color
    }
}

/// 목록으로 늘어놓는 할 일 한 줄.
///
/// 채운 카드가 아니라 **체크리스트 한 줄**로 그린다. 예전엔 달력 막대와 똑같이
/// 옅은 채움 + 테두리를 둘렀는데, 목록에서는 그 카드 하나하나가 덩어리로 보여서
/// 큰 위젯이 뭉툭하고 답답했다. 카테고리 색은 체크 동그라미에 남겨두면 충분하다 —
/// 색은 계속 보이고 줄 높이는 글자 높이까지 내려간다.
///
/// 체크 동그라미는 진짜 버튼이다(iOS 17 인터랙티브 위젯). 누르면 앱을 열지 않고
/// 그 자리에서 완료 처리된다.
struct WidgetTodoRow: View {
    let todo: WidgetTodo
    /// 어느 날의 인스턴스인지 — 반복 일정은 날마다 따로 완료된다.
    let day: Date
    let fontSize: CGFloat
    let showsTime: Bool

    var body: some View {
        let color = todo.color

        HStack(spacing: 6) {
            Button(intent: ToggleTodoCompletionIntent(todoID: todo.id, day: day)) {
                Image(systemName: todo.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: fontSize, weight: .medium))
                    .foregroundStyle(todo.isCompleted ? color.opacity(0.55) : color)
            }
            .buttonStyle(.plain)

            Text(todo.title)
                .font(.system(size: fontSize))
                .strikethrough(todo.isCompleted)
                .foregroundStyle(todo.isCompleted ? .secondary : .primary)
                .lineLimit(1)
                .minimumScaleFactor(0.85)

            Spacer(minLength: 4)

            if showsTime, let timeLabel = todo.timeLabel {
                Text(timeLabel)
                    .font(.system(size: fontSize - 2))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .opacity(todo.isCompleted ? 0.6 : 1)
    }
}

/// 요일 머리글(일~토).
struct WidgetWeekdayHeader: View {
    let fontSize: CGFloat

    var body: some View {
        HStack(spacing: 0) {
            ForEach(KoreanCalendar.weekdaySymbols, id: \.self) { symbol in
                Text(symbol)
                    .font(.system(size: fontSize))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
    }
}
