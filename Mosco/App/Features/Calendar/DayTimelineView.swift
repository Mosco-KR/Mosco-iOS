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
    /// 시각 눈금이 차지하는 폭. `오후 12시`가 안 잘릴 만큼.
    private static let gutterWidth: CGFloat = 62
    /// 눈금과 블록 사이. 붙어 있으면 어느 줄의 시각인지 눈이 헷갈린다.
    private static let gutterGap: CGFloat = Metrics.spacingSM

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
            // 빈 자리를 눌러도 키보드가 내려가야 한다. VStack만으로는 글자가 없는
            // 곳이 터치를 안 받아서, 아래쪽 여백을 눌렀을 때 아무 일도 안 일어났다.
            .frame(maxWidth: .infinity, minHeight: 0, alignment: .topLeading)
            .contentShape(Rectangle())
        }
        .background(MoscoPalette.canvas)
        // 목록 모드와 같은 규칙이다. 이게 없으면 아래 입력창에 글을 쓰다가
        // **키보드를 내릴 방법이 없다** — 시간표에는 누를 빈 셀조차 없다.
        .scrollDismissesKeyboard(.immediately)
        .simultaneousGesture(TapGesture().onEnded {
            UIApplication.shared.sendAction(
                #selector(UIResponder.resignFirstResponder),
                to: nil, from: nil, for: nil
            )
        })
    }

    /// 시각 없는 할 일 — 축 위에 모아둔다. 헤더는 명사구로(문구 원칙 2).
    private var untimedSection: some View {
        VStack(alignment: .leading, spacing: Metrics.spacingSM) {
            Text("시간 미정")
                .font(.moscoCaption())
                .foregroundStyle(MoscoPalette.textSecondary)
                .padding(.leading, Self.gutterWidth + Self.gutterGap)

            ForEach(untimed) { todo in
                Button { onSelect(todo) } label: {
                    TodoRow(todo: todo, showsCalendarTag: showsCalendarTag, memoDisplay: .compact)
                }
                .buttonStyle(.plain)
                .padding(.leading, Self.gutterWidth + Self.gutterGap)
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
                        .font(.moscoCaption().monospacedDigit())
                        .foregroundStyle(MoscoPalette.textSecondary)
                        // 자릿수가 같아도 숫자 폭이 다르면 눈금이 흔들린다.
                        // monospacedDigit + 줄바꿈 금지로 못 박는다.
                        .lineLimit(1)
                        .fixedSize()
                        .frame(width: Self.gutterWidth, alignment: .trailing)
                        .padding(.trailing, Self.gutterGap)
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
            let laneWidth = proxy.size.width - Self.gutterWidth - Self.gutterGap
            ForEach(placements) { placement in
                if let todo = todo(for: placement.id) {
                    let width = laneWidth / CGFloat(placement.columnCount)
                    Button { onSelect(todo) } label: {
                        TimelineBlock(todo: todo, showsCalendarTag: showsCalendarTag)
                    }
                    .buttonStyle(.plain)
                    .frame(width: max(width - 2, 0), height: max(height(of: placement) - 2, 0), alignment: .topLeading)
                    .offset(
                        x: Self.gutterWidth + Self.gutterGap + width * CGFloat(placement.column),
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

    /// `오전 01`처럼 **폭이 같은** 눈금. 여기서만 앱의 다른 시각 표기와 다르다.
    ///
    /// 다른 곳은 `오전 9시`처럼 읽는 말이지만, 축 눈금은 읽는 문장이 아니라 자다.
    /// `오전 9시`와 `오후 12시`가 섞이면 글자 수가 달라 눈금이 들쭉날쭉해지고,
    /// 그러면 세로로 훑을 때 기준선이 흔들린다. 두 자리로 맞춰 고정한다.
    private func hourLabel(_ hour: Int) -> String {
        // 첫 눈금이면 앞이 없다 — 그때는 오전/오후를 붙인다.
        let previous = hour > hourRange.lowerBound ? hour - 1 : nil
        return TimelineLayout.axisLabel(hour: hour, previousHour: previous)
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
