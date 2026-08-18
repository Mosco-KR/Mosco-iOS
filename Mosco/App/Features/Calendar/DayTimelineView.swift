import SwiftUI

/// 하루치를 세로 시간축으로 본다.
///
/// 배치 계산은 `TimelineLayout`(순수 로직, 테스트로 덮임)이 하고 여기서는 그
/// 결과를 그리기만 한다 — 분 단위 위치를 픽셀로 바꾸는 것만 화면 몫이다.
///
/// **시각 없는 할 일은 축에 못 놓는다.** 아무 데나 놓으면 거짓말이 되고, 빼면
/// 화면에서 사라진다. 그래서 축 위쪽에 따로 모은다.
struct DayTimelineView: View {
    let todos: [TodoItem]
    let showsCalendarTag: Bool
    let onSelect: (TodoItem) -> Void

    /// 한 시간이 차지하는 높이. 60pt면 30분짜리가 30pt라 제목 한 줄이 들어간다.
    private static let hourHeight: CGFloat = 60
    /// 시각 눈금이 차지하는 폭.
    private static let gutterWidth: CGFloat = 52

    private var items: [TimelineItem] {
        todos.map { todo in
            TimelineItem(
                id: todo.id.uuidString,
                startMinute: todo.timelineStartMinute,
                endMinute: todo.timelineEndMinute
            )
        }
    }

    private var placements: [TimelinePlacement] { TimelineLayout.place(items) }
    private var hourRange: ClosedRange<Int> { TimelineLayout.visibleHourRange(items) }
    private var untimed: [TodoItem] { todos.filter { $0.timelineStartMinute < 0 } }

    private func todo(for id: String) -> TodoItem? {
        todos.first { $0.id.uuidString == id }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Metrics.spacingMD) {
                if !untimed.isEmpty { untimedSection }
                axis
            }
            .padding(.vertical, Metrics.spacingMD)
        }
        .background(MoscoPalette.canvas)
    }

    /// 시각 없는 할 일 — 축 위에 모아둔다. 헤더는 명사구로(문구 원칙 2).
    private var untimedSection: some View {
        VStack(alignment: .leading, spacing: Metrics.spacingSM) {
            Text("시간 미정")
                .font(.moscoCaption())
                .foregroundStyle(MoscoPalette.textSecondary)
                .padding(.leading, Self.gutterWidth)

            ForEach(untimed) { todo in
                Button { onSelect(todo) } label: {
                    TodoRow(todo: todo, showsCalendarTag: showsCalendarTag, memoDisplay: .compact)
                }
                .buttonStyle(.plain)
                .padding(.leading, Self.gutterWidth)
                .padding(.trailing, Metrics.spacingMD)
            }
        }
    }

    private var axis: some View {
        ZStack(alignment: .topLeading) {
            hourLines
            blocks
        }
        .frame(height: CGFloat(hourRange.count) * Self.hourHeight, alignment: .top)
        .padding(.trailing, Metrics.spacingMD)
    }

    /// 시각 눈금과 가로선. 선은 경계선 토큰을 그대로 쓴다(새 색을 만들지 않는다).
    private var hourLines: some View {
        VStack(spacing: 0) {
            ForEach(Array(hourRange), id: \.self) { hour in
                HStack(alignment: .top, spacing: 0) {
                    Text(hourLabel(hour))
                        .font(.moscoCaption())
                        .foregroundStyle(MoscoPalette.textSecondary)
                        .frame(width: Self.gutterWidth, alignment: .trailing)
                        .padding(.trailing, Metrics.spacingSM)
                        // 선 위에 글자 가운데가 오도록 살짝 올린다.
                        .offset(y: -6)
                    Rectangle()
                        .fill(MoscoPalette.border)
                        .frame(height: 0.5)
                }
                .frame(height: Self.hourHeight, alignment: .top)
            }
        }
    }

    private var blocks: some View {
        GeometryReader { proxy in
            let laneWidth = proxy.size.width - Self.gutterWidth
            ForEach(placements) { placement in
                if let todo = todo(for: placement.id) {
                    let width = laneWidth / CGFloat(placement.columnCount)
                    Button { onSelect(todo) } label: {
                        TimelineBlock(todo: todo, showsCalendarTag: showsCalendarTag)
                    }
                    .buttonStyle(.plain)
                    .frame(width: max(width - 2, 0), height: max(height(of: placement) - 2, 0), alignment: .topLeading)
                    .offset(
                        x: Self.gutterWidth + width * CGFloat(placement.column),
                        y: offset(of: placement)
                    )
                }
            }
        }
    }

    private func height(of placement: TimelinePlacement) -> CGFloat {
        CGFloat(placement.durationMinutes) / 60 * Self.hourHeight
    }

    private func offset(of placement: TimelinePlacement) -> CGFloat {
        CGFloat(placement.startMinute - hourRange.lowerBound * 60) / 60 * Self.hourHeight
    }

    /// `오전 9시`처럼 앱의 다른 시각 표기와 같은 말을 쓴다.
    private func hourLabel(_ hour: Int) -> String {
        hour == 24 ? "밤 12시" : TimeExpressionParser.koreanTimeLabel(hour24: hour, minute: 0)
    }
}

/// 축 위에 놓이는 블록 하나. 카드 표면은 기존 토큰을 그대로 쓴다.
private struct TimelineBlock: View {
    let todo: TodoItem
    let showsCalendarTag: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(todo.title)
                .font(.moscoCaption().weight(.semibold))
                .foregroundStyle(MoscoPalette.textPrimary)
                .strikethrough(todo.isCompleted)
                .lineLimit(2)
            if let range = todo.timeRangeLabel {
                Text(range)
                    .font(.moscoCaption())
                    .foregroundStyle(MoscoPalette.textSecondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, Metrics.spacingSM)
        .padding(.vertical, Metrics.spacingXS)
        .frame(maxWidth: .infinity, alignment: .leading)
        // 색은 한 행에 한 번 — 카테고리 색은 왼쪽 띠에만 쓰고 배경은 톤으로 낮춘다.
        .background(alignment: .leading) {
            RoundedRectangle(cornerRadius: Metrics.buttonRadius, style: .continuous)
                .fill((todo.category?.color ?? MoscoPalette.accent).opacity(todo.isCompleted ? 0.06 : 0.12))
        }
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(todo.category?.color ?? MoscoPalette.accent)
                .frame(width: 3)
                .padding(.vertical, 2)
        }
        .opacity(todo.isCompleted ? 0.55 : 1)
    }
}
