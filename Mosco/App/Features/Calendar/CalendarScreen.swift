import SwiftUI
import SwiftData

struct CalendarScreen: View {
    @Query(sort: \TodoItem.date) private var todos: [TodoItem]
    @State private var displayedMonth = Date()
    @State private var selectedDate: Date?
    /// 월 헤더 + 요일 헤더가 차지하는 높이 — 전체 화면 높이에서 이만큼을 뺀
    /// 나머지를 캘린더 영역의 최소 높이로 써서, 블록이 적어 콘텐츠가 짧을 땐
    /// 탭바 바로 위까지 꽉 채우고 블록이 많아지면 자연스럽게 스크롤된다.
    /// (스크롤뷰 자기 자신의 렌더링 크기를 재서 그대로 최소 높이로 되먹이면,
    /// 탭바 안전영역 반영 타이밍에 따라 실제보다 크게 측정돼 콘텐츠가 탭바
    /// 밑으로 밀려 들어가 일부가 가려지는 경우가 있었다 — 그래서 이 화면
    /// 전체(GeometryReader)에서 헤더 높이만 빼는 방식으로 바꿨다.)
    @State private var topChromeHeight: CGFloat = 0

    private let calendar = Calendar.current

    /// 이전/현재/다음 달 페이지가 함께 쓰는 블록 계산 범위.
    private var blockWindow: DateInterval? {
        guard let prev = calendar.date(byAdding: .month, value: -1, to: displayedMonth),
              let next = calendar.date(byAdding: .month, value: 1, to: displayedMonth),
              let prevInterval = calendar.dateInterval(of: .month, for: prev),
              let nextInterval = calendar.dateInterval(of: .month, for: next)
        else { return nil }
        return DateInterval(start: prevInterval.start, end: nextInterval.end)
    }

    /// 원본 + 반복 인스턴스를 전부 블록으로 펼친다(현재 보이는 3개월 범위만).
    private var blocks: [CalendarBlock] {
        guard let window = blockWindow else { return [] }
        return todos.flatMap { occurrenceBlocks(for: $0, in: window) }
    }

    private func occurrenceBlocks(for todo: TodoItem, in window: DateInterval) -> [CalendarBlock] {
        // 날짜 없는(백로그) 항목은 캘린더에 아예 나오지 않는다 — "할 일" 탭에만 있는다.
        guard let todoDate = todo.date, let todoEnd = todo.effectiveEndDate else { return [] }
        let baseStart = calendar.startOfDay(for: todoDate)
        let baseEnd = calendar.startOfDay(for: todoEnd)
        var result = [
            CalendarBlock(
                id: "\(todo.id.uuidString)-base",
                title: todo.title,
                priority: todo.priority,
                start: baseStart,
                end: baseEnd,
                isCompleted: todo.isCompleted(on: baseStart)
            )
        ]

        guard todo.repeatRule != .none else { return result }

        // 계산 범위 앞쪽에서 시작해 범위 안으로 이어지는 반복도 잡히도록,
        // 일정 길이만큼 앞당긴 지점부터 하루씩 훑는다.
        let scanStart = max(
            calendar.date(byAdding: .day, value: 1, to: baseStart) ?? baseStart,
            calendar.date(byAdding: .day, value: -todo.durationDays, to: window.start) ?? window.start
        )
        var cursor = scanStart
        while cursor < window.end {
            if todo.isRepeatStart(cursor) {
                let end = calendar.date(byAdding: .day, value: todo.durationDays, to: cursor) ?? cursor
                result.append(
                    CalendarBlock(
                        id: "\(todo.id.uuidString)-\(cursor.dayKey)",
                        title: todo.title,
                        priority: todo.priority,
                        start: cursor,
                        end: end,
                        // 반복은 날짜별로 완료 상태가 다르다 — 그 인스턴스의 기록만 본다.
                        isCompleted: todo.isCompleted(on: cursor)
                    )
                )
            }
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }
        return result
    }

    /// 전체 블록에 안정적인 행을 한 번에 배정 — 겹치는 일정이 주마다 자리를
    /// 바꾸거나 깜빡이지 않고, 항상 같은 줄에 그려진다.
    private var positionedBlocks: [PositionedBlock] {
        BlockLayout.position(blocks)
    }

    /// 선택된 날짜가 지금 보이는 달에 속할 때만 그 주의 행 번호를 계산한다 —
    /// MonthGridView가 이 값 하나로 "그 행만 44pt로 남기고 나머지는 접는다"를
    /// 처리한다(실제 레이아웃 하나로 압축·복원이 항상 대칭으로 이어진다).
    private var selectedRowIndex: Int? {
        guard let selectedDate, calendar.isDate(selectedDate, equalTo: displayedMonth, toGranularity: .month) else {
            return nil
        }
        return calendar.weekRowIndex(of: selectedDate, in: displayedMonth)
    }

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                VStack(spacing: 0) {
                    monthHeader
                        .padding(.horizontal, Metrics.spacingMD)
                        .padding(.top, Metrics.spacingSM)

                    weekdayHeader
                        .padding(.horizontal, Metrics.spacingSM)
                        .padding(.top, Metrics.spacingLG)
                        .padding(.bottom, Metrics.spacingSM)
                }
                .background(
                    GeometryReader { headerProxy in
                        Color.clear
                            .onAppear { topChromeHeight = headerProxy.size.height }
                            .onChange(of: headerProxy.size.height) { _, newValue in
                                topChromeHeight = newValue
                            }
                    }
                )

                // 세로 스크롤은 캐러셀 "바깥"에 하나만 둔다 — 페이지마다 스크롤을
                // 넣으면 가로 스와이프를 스크롤뷰가 가로채 인식이 나빠지고, 달을
                // 넘길 때 페이지별 스크롤 위치가 제각각이라 툭툭 튀어 보인다.
                ScrollViewReader { proxy in
                    ScrollView(showsIndicators: false) {
                        MonthCarouselView(
                            width: geometry.size.width - Metrics.spacingSM * 2,
                            displayedMonth: displayedMonth,
                            positionedBlocks: positionedBlocks,
                            selectedDate: selectedDate,
                            selectedRowIndex: selectedRowIndex,
                            onSelect: { day in select(day) },
                            onMonthChange: { direction in
                                if let newMonth = calendar.date(byAdding: .month, value: direction, to: displayedMonth) {
                                    displayedMonth = newMonth
                                }
                            }
                        )
                        .padding(.horizontal, Metrics.spacingSM)
                        // 압축 중엔 이 최소 높이를 강제하면 44pt로 줄어들지 못하니 뺀다.
                        .frame(minHeight: selectedDate == nil ? max(geometry.size.height - topChromeHeight, 0) : nil)
                        .id("calendarTop")
                    }
                    .scrollDisabled(selectedDate != nil)
                    .onChange(of: calendar.dateInterval(of: .month, for: displayedMonth)?.start) { _, _ in
                        // 달이 바뀌면 위로 부드럽게 복귀 — 이전 달에서 내려둔 스크롤
                        // 위치가 그대로 남아 어색하게 잘려 보이지 않게.
                        withAnimation(.easeOut(duration: 0.25)) {
                            proxy.scrollTo("calendarTop", anchor: .top)
                        }
                    }
                }
                .frame(maxHeight: selectedDate == nil ? .infinity : 44)
                .clipped()
                // 압축된 상태에서 아래로 쓸어내리면 전체 달력으로 복귀.
                .simultaneousGesture(
                    DragGesture(minimumDistance: 16)
                        .onEnded { value in
                            guard selectedDate != nil, value.translation.height > 30 else { return }
                            collapse()
                        }
                )

                if let selectedDate {
                    DayTodosContentView(date: selectedDate)
                        .transition(.opacity)
                } else {
                    Spacer(minLength: 0)
                }
            }
            // selectedDate 하나가 그리드 압축/복원, 아래 리스트 삽입·제거, 뒤로가기
            // 화살표 등장까지 전부 같은 트랜잭션으로 묶어 자연스럽게 이어지게 한다.
            .animation(.spring(response: 0.4, dampingFraction: 0.88), value: selectedDate)
        }
        .background(MoscoPalette.canvas.ignoresSafeArea(edges: .top))
    }

    private func select(_ day: Date) {
        // 이전/다음 달의 흐린 날짜를 탭해도 그 달로 넘어가면서 선택되게 한다.
        if !calendar.isDate(day, equalTo: displayedMonth, toGranularity: .month) {
            displayedMonth = day
        }
        selectedDate = day
    }

    private func collapse() {
        selectedDate = nil
    }

    private var monthHeader: some View {
        HStack(alignment: .lastTextBaseline, spacing: Metrics.spacingSM) {
            if selectedDate != nil {
                Button {
                    collapse()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(MoscoPalette.textPrimary)
                }
                .transition(.scale(scale: 0.6).combined(with: .opacity))
            }

            HStack(alignment: .lastTextBaseline, spacing: 4) {
                // 자릿수가 1→2로 바뀌어도(9월→10월) 폭이 툭 끊기지 않고 스르륵
                // 늘어나도록 SwiftUI의 숫자 전용 콘텐츠 트랜지션을 쓴다.
                Text("\(calendar.component(.month, from: displayedMonth))")
                    .font(.system(size: 38, weight: .bold).monospacedDigit())
                    .contentTransition(.numericText(value: Double(calendar.component(.month, from: displayedMonth))))

                Text("월")
                    .font(.moscoTitle())
                    .foregroundStyle(MoscoPalette.textSecondary)

                // 올해가 아닌 달을 보고 있을 때만 연도를 붙인다.
                if !calendar.isDate(displayedMonth, equalTo: Date(), toGranularity: .year) {
                    Text(verbatim: "\(calendar.component(.year, from: displayedMonth))년")
                        .font(.moscoCaption())
                        .foregroundStyle(MoscoPalette.textSecondary)
                        .transition(.opacity)
                }
            }
            .foregroundStyle(MoscoPalette.textPrimary)
            .animation(.easeInOut(duration: 0.3), value: displayedMonth)

            // 날짜를 골라 리스트로 들어와 있으면, 오늘 기준 며칠인지 배지로 보여준다.
            // 월 숫자 바로 옆(spacing 4) 대신 별도 여백을 둬서 눌려 붙어 보이지 않게 한다.
            if let selectedDate {
                Text(dDayLabel(for: selectedDate))
                    .font(.moscoCaption().weight(.semibold))
                    .foregroundStyle(MoscoPalette.accent)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(MoscoPalette.accent.opacity(0.12), in: Capsule())
                    .padding(.leading, Metrics.spacingXS)
                    .transition(.opacity.combined(with: .scale(scale: 0.85)))
            }

            Spacer()

            todayButton
        }
    }

    /// 항상 상단 오른쪽에 고정 — 압축 여부/현재 달 여부와 무관하게 항상 눌러서
    /// 오늘이 있는 달로, 펼쳐진 상태로 돌아올 수 있다.
    private var todayButton: some View {
        Button {
            goToToday()
        } label: {
            Image(systemName: "smallcircle.filled.circle")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(MoscoPalette.accent)
                .frame(width: 34, height: 34)
        }
        .moscoGlass(in: Circle())
    }

    private var weekdayHeader: some View {
        HStack(spacing: 0) {
            ForEach(KoreanCalendar.weekdaySymbols, id: \.self) { symbol in
                Text(symbol)
                    .font(.moscoCaption())
                    .foregroundStyle(MoscoPalette.textSecondary)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private func goToToday() {
        withAnimation(.easeInOut(duration: 0.3)) {
            displayedMonth = Date()
            selectedDate = nil
        }
    }

    /// 오늘 기준 D-day 표기: 미래는 D-n, 과거는 D+n, 오늘은 "오늘".
    private func dDayLabel(for day: Date) -> String {
        let days = calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: Date()),
            to: calendar.startOfDay(for: day)
        ).day ?? 0
        if days == 0 { return "오늘" }
        return days > 0 ? "D-\(days)" : "D+\(-days)"
    }
}
