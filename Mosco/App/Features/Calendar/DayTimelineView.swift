import Combine
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
    /// 수정 화면으로 보낸다 — 꾹 눌러 나오는 메뉴의 '수정'.
    let onSelect: (TodoItem) -> Void
    /// 이 할 일을 지운다 — 메뉴의 '삭제'.
    var onDelete: (TodoItem) -> Void = { _ in }
    /// 반복 일정의 완료를 날짜별로 기록하려면 어느 날인지 알아야 한다.
    var date: Date? = nil

    @Environment(TutorialCoordinator.self) private var tutorial: TutorialCoordinator?
    @Environment(ReviewPrompt.self) private var reviewPrompt

    /// 현재 시각 줄이 서는 자리. 1분마다 갱신한다 — 한 시간이 60pt라 1분은 1pt고,
    /// 그보다 자주 갱신해도 눈에 보이는 차이가 없다.
    @State private var now = Date()
    private let clock = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    /// 한 시간이 차지하는 높이. 60pt면 30분짜리가 30pt라 제목 한 줄이 들어간다.
    private static let hourHeight: CGFloat = 60
    /// 시각 눈금이 차지하는 폭. `오후 12시`가 안 잘릴 만큼.
    private static let gutterWidth: CGFloat = 62
    /// 눈금과 블록 사이. 붙어 있으면 어느 줄의 시각인지 눈이 헷갈린다.
    private static let gutterGap: CGFloat = Metrics.spacingSM
    /// 현재 시각 줄 왼쪽 끝의 점.
    private static let nowDotSize: CGFloat = 7

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
    private var untimed: [TodoItem] { todos.filter { $0.timelineStartMinute < 0 } }

    /// **오늘을 볼 때만 그린다.** 어제나 내일의 축에 지금 시각을 얹으면 그건
    /// 그 날짜에 대해 아무 뜻도 없는 선이다.
    private var showsNowLine: Bool {
        guard let date else { return false }
        return Calendar.current.isDateInToday(date)
    }

    private var nowMinute: Int {
        let parts = Calendar.current.dateComponents([.hour, .minute], from: now)
        return (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
    }

    /// 오늘이면 축이 현재 시각을 품게 한다 — 새벽 세 시에 열었는데 축이 8시부터
    /// 시작하면 줄을 놓을 자리가 없다(`TimelineLayout`이 범위를 넓혀준다).
    private var hourRange: ClosedRange<Int> {
        TimelineLayout.visibleHourRange(items, including: showsNowLine ? nowMinute / 60 : nil)
    }

    private func todo(for id: String) -> TodoItem? {
        todos.first { $0.id.uuidString == id }
    }

    var body: some View {
        ScrollViewReader { proxy in
            scrollBody(proxy)
        }
    }

    private func scrollBody(_ proxy: ScrollViewProxy) -> some View {
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
        // 열자마자 지금이 보여야 한다. 축이 하루를 다 그리면 화면 두 배가 넘어서,
        // 오늘을 열었는데 아침 여덟 시가 보이는 일이 생긴다. 눈금 단위로 맞춘다 —
        // 분까지 맞추지 않아도 줄은 화면 안에 들어온다.
        .onAppear {
            guard showsNowLine else { return }
            proxy.scrollTo(nowMinute / 60, anchor: .center)
        }
        .onReceive(clock) { tick in
            guard showsNowLine else { return }
            now = tick
        }
    }

    /// 시각 없는 할 일 — 축 위에 모아둔다. 헤더는 명사구로(문구 원칙 2).
    ///
    /// **축 폭에 맞추지 않고 화면 폭을 그대로 쓴다.** 예전엔 눈금 칸만큼 오른쪽으로
    /// 밀어서 블록과 줄을 맞췄는데, 이것들은 애초에 시간축 위에 있지 않아서
    /// 무엇에 맞춘 줄인지 알 수 없었고 헤더까지 따라 밀려 어중간했다.
    /// 목록 화면의 셀과 같은 폭이라 오히려 익숙하다.
    private var untimedSection: some View {
        VStack(alignment: .leading, spacing: Metrics.spacingSM) {
            Text("시간 미정")
                .font(.moscoCaption())
                .foregroundStyle(MoscoPalette.textSecondary)

            ForEach(untimed) { todo in
                // 목록 셀 그대로다 — 탭하면 완료되고 꾹 누르면 메뉴가 나온다.
                // 삭제도 그 메뉴에 있다. 손으로 만든 스와이프를 얹어봤다가
                // 걷어냈다(2026-08-22, `DesignSystem/README.md`).
                TodoRow(
                    todo: todo,
                    onTap: { onSelect(todo) },
                    onDelete: { onDelete(todo) },
                    showsCalendarTag: showsCalendarTag
                )
            }
        }
        .padding(.horizontal, Metrics.spacingMD)
    }

    private var axis: some View {
        ZStack(alignment: .topLeading) {
            hourLines
            blocks
            // 블록 위에 온다 — 지금이 어느 블록 안인지가 이 줄로 읽힌다.
            if showsNowLine { nowLine }
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
                // 화면을 열 때 현재 시각으로 스크롤하는 표적이다.
                .id(hour)
            }
        }
    }

    /// 현재 시각 줄. 눈금선과 달리 왼쪽 끝에 점을 하나 찍는다 — 헤어라인 하나만
    /// 그으면 눈금선과 굵기가 비슷해 어느 게 지금인지 한눈에 안 잡힌다.
    ///
    /// 색은 팔레트의 `must`다. 새 색을 만들지 않았고, 축 위에서 빨간 것은 이 줄
    /// 하나뿐이라 "색은 한 행에 한 번"과도 어긋나지 않는다.
    private var nowLine: some View {
        HStack(spacing: 0) {
            Circle()
                .fill(MoscoPalette.must)
                .frame(width: Self.nowDotSize, height: Self.nowDotSize)
            Rectangle()
                .fill(MoscoPalette.must)
                .frame(height: 1.5)
        }
        .padding(.leading, Self.gutterWidth + Self.gutterGap - Self.nowDotSize / 2)
        // 점의 한가운데가 그 시각에 오도록 반지름만큼 올린다.
        .offset(y: nowOffset - Self.nowDotSize / 2)
        .allowsHitTesting(false)
        .accessibilityElement()
        .accessibilityLabel("현재 시각 \(now.formatted(date: .omitted, time: .shortened))")
    }

    private var nowOffset: CGFloat {
        CGFloat(nowMinute - hourRange.lowerBound * 60) / 60 * Self.hourHeight
    }

    private var blocks: some View {
        GeometryReader { proxy in
            let laneWidth = proxy.size.width - Self.gutterWidth - Self.gutterGap
            ForEach(placements) { placement in
                if let todo = todo(for: placement.id) {
                    let width = laneWidth / CGFloat(placement.columnCount)
                    TimelineBlock(
                        todo: todo,
                        // **목록과 같다 — 몸통을 누르면 완료된다.** 수정은 꾹 눌러
                        // 나오는 메뉴에 있다. 화면마다 같은 손짓이 다른 일을 하면
                        // 어느 쪽이 맞는지 매번 생각해야 한다.
                        onToggle: {
                            TodoCompletion.toggle(
                                todo,
                                occurrenceDate: date,
                                tutorial: tutorial,
                                reviewPrompt: reviewPrompt
                            )
                        }
                    )
                    // 꾹 누르면 목록과 **똑같은** 메뉴가 나온다.
                    .modifier(TodoActions(
                        todo: todo,
                        occurrenceDate: date,
                        onTap: { onSelect(todo) },
                        onDelete: { onDelete(todo) }
                    ))
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

/// 축 위에 놓이는 블록 하나.
///
/// **목록 셀과 같은 언어로 그린다** — 중립색 카드, 헤어라인 테두리, 왼쪽 카테고리
/// 막대, 완료 체크. 예전엔 카테고리 색을 배경에 옅게 깔고 띠를 세웠는데, 목록은
/// 색을 체크 한 곳에만 쓰는 규칙이라 두 화면이 서로 다른 앱처럼 보였다
/// (`DesignSystem/README.md`의 "색은 한 행에 한 번").
///
/// 높이가 30pt까지 내려갈 수 있어서 목록 셀보다 촘촘하다. 조각은 같고 크기만 줄인다.
private struct TimelineBlock: View {
    let todo: TodoItem
    let onToggle: () -> Void

    /// 블록이 낮으면 시각 줄을 접는다 — 제목이 먼저다.
    @State private var height: CGFloat = 0

    private var isDone: Bool { todo.isCompleted }
    private var accentColor: Color { todo.category?.color ?? MoscoPalette.textSecondary }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Metrics.buttonRadius, style: .continuous)

        HStack(alignment: .top, spacing: 6) {
            TodoCategoryBar(color: accentColor)

            Button(action: onToggle) {
                TodoCheckMark(isDone: isDone, size: 20)
            }
            .buttonStyle(.plain)
            .padding(.top, 1)

            VStack(alignment: .leading, spacing: 1) {
                Text(todo.title)
                    .font(.moscoCaption().weight(.semibold))
                    .strikethrough(isDone)
                    .foregroundStyle(isDone ? MoscoPalette.textSecondary : MoscoPalette.textPrimary)
                    .lineLimit(2)

                // 30분짜리 블록에서는 두 줄이 안 들어간다. 제목을 자르느니 시각을 접는다.
                if height >= 44, let range = todo.timeRangeLabel {
                    Text(range)
                        .font(.moscoCaption())
                        .foregroundStyle(MoscoPalette.textSecondary)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 5)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(MoscoPalette.surface, in: shape)
        .overlay(shape.strokeBorder(MoscoPalette.border.opacity(0.4), lineWidth: 0.5))
        .opacity(isDone ? 0.55 : 1)
        .contentShape(shape)
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { height = $0 }
    }
}
