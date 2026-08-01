import SwiftUI
import SwiftData

struct CalendarScreen: View {
    @Environment(TutorialManager.self) private var tutorialManager
    @Environment(WeatherStore.self) private var weatherStore
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
    @State private var showsSettings = false
    /// 계산해둔 블록 배치. computed property로 두면 body가 돌 때마다 3개월치
    /// 반복 일정을 다시 펼쳐서, 달을 넘기는 순간 프레임이 떨어졌다.
    @State private var positionedBlocks: [PositionedBlock] = []
    /// 블록을 미리 계산해둔 범위의 중심. displayedMonth와 따로 두어 스와이프마다
    /// 재계산되지 않게 한다(recenterBlocksIfNeeded 참고).
    @State private var blocksCenter = Date()
    /// positionedBlocks가 갱신될 때마다 오르는 번호 — 하위 뷰의 == 비용을 상수로 만든다.
    @State private var blocksRevision = 0

    private let calendar = Calendar.current

    /// 블록을 계산해둘 범위의 한가운데. 보고 있는 달을 그대로 따라가면 스와이프
    /// 때마다 전 범위를 다시 펼치게 되므로, 창 가장자리에 가까워질 때만 옮긴다.
    /// 캐러셀이 ±2개월을 미리 올려두므로 그보다 넉넉한 ±4개월을 계산해둔다.
    private static let blockWindowRadius = 4
    /// 중심에서 이만큼 멀어지면 그때 다시 계산한다(가장자리에 닿기 전에).
    private static let blockRecenterThreshold = 2

    /// 미리 올려둔 페이지들이 함께 쓰는 블록 계산 범위.
    private var blockWindow: DateInterval? {
        guard let first = calendar.date(byAdding: .month, value: -Self.blockWindowRadius, to: blocksCenter),
              let last = calendar.date(byAdding: .month, value: Self.blockWindowRadius, to: blocksCenter),
              let firstInterval = calendar.dateInterval(of: .month, for: first),
              let lastInterval = calendar.dateInterval(of: .month, for: last)
        else { return nil }
        return DateInterval(start: firstInterval.start, end: lastInterval.end)
    }

    /// 원본 + 반복 인스턴스를 전부 블록으로 펼친다(미리 계산해둔 범위만).
    private var blocks: [CalendarBlock] {
        guard let window = blockWindow else { return [] }
        return todos.flatMap { occurrenceBlocks(for: $0, in: window) }
    }

    /// 보고 있는 달이 중심에서 충분히 멀어졌을 때만 중심을 옮긴다. 이 값이 바뀌면
    /// blocksKey가 바뀌어 재계산이 걸리므로, 자주 바뀌지 않는 게 중요하다.
    private func recenterBlocksIfNeeded() {
        let months = calendar.dateComponents([.month], from: blocksCenter, to: displayedMonth).month ?? 0
        guard abs(months) >= Self.blockRecenterThreshold else { return }
        blocksCenter = calendar.dateInterval(of: .month, for: displayedMonth)?.start ?? displayedMonth
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
                categoryColorHex: todo.category?.colorHex,
                isRepeating: todo.repeatRule != .none,
                start: baseStart,
                end: baseEnd,
                isCompleted: todo.isCompleted(on: baseStart),
                createdAt: todo.createdAt
            )
        ]

        guard todo.repeatRule != .none else { return result }

        // 계산 범위 앞쪽에서 시작해 범위 안으로 이어지는 반복도 잡히도록,
        // 일정 길이만큼 앞당긴 지점부터 훑는다.
        let scanStart = max(
            calendar.date(byAdding: .day, value: 1, to: baseStart) ?? baseStart,
            calendar.date(byAdding: .day, value: -todo.durationDays, to: window.start) ?? window.start
        )

        // 예전엔 하루씩 커서를 옮기며 매번 isRepeatStart를 물었다 — 3개월 범위면
        // 반복 일정 하나당 90번씩 캘린더 날짜 연산이 돌아서, 달을 넘기는 순간
        // 프레임이 눈에 띄게 떨어졌다. 규칙이 이미 주기를 알고 있으므로 그만큼
        // 건너뛰면 후보 자체가 3~12개로 줄어든다.
        // (요일 지정 주간 반복만은 한 주 안에서 여러 날이 걸릴 수 있어 하루씩 보되,
        //  범위를 주 단위로 끊어 확인한다.)
        for cursor in repeatCandidates(for: todo, base: baseStart, from: scanStart, until: window.end) {
            guard todo.isRepeatStart(cursor) else { continue }
            let end = calendar.date(byAdding: .day, value: todo.durationDays, to: cursor) ?? cursor
            result.append(
                CalendarBlock(
                    id: "\(todo.id.uuidString)-\(cursor.dayKey)",
                    title: todo.title,
                    categoryColorHex: todo.category?.colorHex,
                    isRepeating: true,
                    start: cursor,
                    end: end,
                    // 반복은 날짜별로 완료 상태가 다르다 — 그 인스턴스의 기록만 본다.
                    isCompleted: todo.isCompleted(on: cursor),
                    createdAt: todo.createdAt
                )
            )
        }
        return result
    }

    /// 반복 규칙별로 "확인해볼 만한 날짜"만 추린다. 최종 판정은 여전히
    /// `isRepeatStart`가 하므로(반복 종료일·요일 조건 등) 여기서는 실제 반복일을
    /// 빠짐없이 포함하는 후보만 내면 되고, 하루씩 전부 훑지만 않으면 된다.
    ///
    /// 주기의 기준점은 반드시 **원본 시작일**이다. 스캔 시작점부터 주기만큼
    /// 건너뛰면 위상이 어긋나서(예: 매월 15일 반복인데 1일부터 한 달씩 더하면
    /// 영영 15일에 안 닿는다) 반복이 통째로 사라진다.
    private func repeatCandidates(for todo: TodoItem, base: Date, from start: Date, until end: Date) -> [Date] {
        switch todo.repeatRule {
        case .none:
            return []

        case .daily:
            return stride(from: max(base, start), to: end, by: 1)

        case .everyNDays:
            let interval = max(todo.repeatInterval ?? 2, 1)
            // base + k*interval 중 start 이후 첫 지점을 구해 위상을 맞춘다.
            let elapsed = calendar.dateComponents([.day], from: base, to: start).day ?? 0
            let steps = max(Int(ceil(Double(elapsed) / Double(interval))), 0)
            let first = calendar.date(byAdding: .day, value: steps * interval, to: base) ?? start
            return stride(from: first, to: end, by: interval)

        case .weekly:
            // 요일을 여러 개 고를 수 있으면 주 안의 날짜를 다 봐야 한다(그래도
            // 범위가 3개월이라 상한이 낮다). 안 골랐으면 원본과 같은 요일만.
            guard todo.repeatWeekdays.isEmpty else {
                return stride(from: max(base, start), to: end, by: 1)
            }
            let weekdayOffset = ((calendar.dateComponents([.day], from: base, to: start).day ?? 0) % 7 + 7) % 7
            let aligned = calendar.date(byAdding: .day, value: weekdayOffset == 0 ? 0 : 7 - weekdayOffset, to: start) ?? start
            return stride(from: max(base, aligned), to: end, by: 7)

        case .monthly, .yearly:
            // 달마다 날짜 수가 달라(31일 반복 등) 단순 덧셈으로는 어긋난다.
            // 시스템의 날짜 매칭에 맡기고, 없는 날짜(2월 31일)는 건너뛴다.
            let units: Set<Calendar.Component> = todo.repeatRule == .monthly ? [.day] : [.month, .day]
            var result: [Date] = []
            calendar.enumerateDates(
                startingAfter: max(base, calendar.date(byAdding: .day, value: -1, to: start) ?? start),
                matching: calendar.dateComponents(units, from: base),
                matchingPolicy: .strict
            ) { date, _, stop in
                guard let date, date < end else {
                    stop = true
                    return
                }
                result.append(calendar.startOfDay(for: date))
            }
            return result
        }
    }

    /// startOfDay 정렬을 유지하면서 일 단위로 건너뛴 날짜 목록.
    private func stride(from start: Date, to end: Date, by days: Int) -> [Date] {
        var result: [Date] = []
        var cursor = calendar.startOfDay(for: start)
        while cursor < end {
            result.append(cursor)
            guard let next = calendar.date(byAdding: .day, value: days, to: cursor) else { break }
            cursor = next
        }
        return result
    }

    /// 블록 계산에 실제로 영향을 주는 값만 추린 키. 이게 바뀔 때만 다시 계산한다 —
    /// 날씨 갱신이나 날짜 선택처럼 무관한 이유로 body가 다시 돌 때 3개월치를
    /// 통째로 재계산하던 걸 막는다.
    private var blocksKey: String {
        var key = "\(blocksCenter.timeIntervalSince1970)"
        for todo in todos {
            key += "|" + todo.id.uuidString
            key += "~" + todo.title
            key += "~" + timestamp(todo.date)
            key += "~" + timestamp(todo.endDate)
            key += "~" + todo.repeatRule.rawValue
            key += "~\(todo.repeatInterval ?? 0)"
            key += "~" + todo.repeatWeekdays.map(String.init).joined(separator: ",")
            key += "~" + timestamp(todo.repeatEndDate)
            key += "~" + (todo.category?.colorHex ?? "-")
            key += "~\(todo.isCompleted)"
            key += "~" + (todo.completedDayKeys ?? []).joined(separator: ",")
        }
        return key
    }

    private func timestamp(_ date: Date?) -> String {
        guard let date else { return "-" }
        return "\(date.timeIntervalSince1970)"
    }

    /// 전체 블록에 안정적인 행을 한 번에 배정 — 겹치는 일정이 주마다 자리를
    /// 바꾸거나 깜빡이지 않고, 항상 같은 줄에 그려진다.
    ///
    /// 달을 넘길 때 새로 필요한 건 화면 밖의 페이지뿐이고(들어오는 페이지는 이미
    /// 이전 창에 들어있었다), 그래서 이 계산이 한 프레임 늦어도 눈에 안 띈다 —
    /// 슬라이드 도중 동기적으로 도는 것보다 훨씬 매끄럽다.
    private func recomputeBlocks() {
        positionedBlocks = BlockLayout.position(blocks)
        blocksRevision &+= 1
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
                    ScrollView {
                        MonthCarouselView(
                            width: geometry.size.width - Metrics.spacingSM * 2,
                            displayedMonth: displayedMonth,
                            positionedBlocks: positionedBlocks,
                            blocksRevision: blocksRevision,
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
                // 압축된 주간 스트립의 제스처. 아래로 쓸면 전체 달력으로 돌아가고,
                // 좌우로 밀면 주 단위로 이동한다.
                .simultaneousGesture(
                    DragGesture(minimumDistance: 16)
                        .onEnded { value in
                            guard selectedDate != nil else { return }
                            let dx = value.translation.width
                            let dy = value.translation.height

                            if abs(dx) > abs(dy) {
                                guard abs(dx) > 40 else { return }
                                shiftSelectedDate(by: dx < 0 ? 7 : -7)
                            } else if dy > 30 {
                                collapse()
                            }
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
        .task(id: blocksKey) {
            recomputeBlocks()
        }
        // 달이 바뀔 때마다가 아니라, 미리 계산해둔 범위의 가장자리에 가까워질 때만
        // 중심을 옮긴다 — 그때만 blocksKey가 바뀌어 재계산이 걸린다.
        .onChange(of: displayedMonth) { _, _ in
            recenterBlocksIfNeeded()
        }
        .sheet(isPresented: $showsSettings) {
            SettingsScreen()
        }
    }

    private func select(_ day: Date) {
        // 이전/다음 달의 흐린 날짜를 탭해도 그 달로 넘어가면서 선택되게 한다.
        if !calendar.isDate(day, equalTo: displayedMonth, toGranularity: .month) {
            displayedMonth = day
        }
        selectedDate = day
        tutorialManager.userDidSelectDate()
    }

    private func collapse() {
        selectedDate = nil
    }

    /// 압축된 주간 스트립을 좌우로 밀어 주 단위로 이동. 달이 바뀌면 표시 중인
    /// 달도 같이 옮겨야 전체 달력으로 돌아갔을 때 엉뚱한 달이 보이지 않는다.
    private func shiftSelectedDate(by delta: Int) {
        guard let current = selectedDate,
              let next = calendar.date(byAdding: .day, value: delta, to: current)
        else { return }
        selectedDate = next
        if !calendar.isDate(next, equalTo: displayedMonth, toGranularity: .month) {
            displayedMonth = next
        }
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
            // 0.3초 easeInOut은 스와이프 속도에 비해 굼떠서 숫자가 뒤늦게 따라오는
            // 느낌을 준다. 페이지 스냅(response 0.28)보다 살짝 빠른 스프링으로
            // 맞춰서, 손을 떼면 숫자가 먼저 도착해 있는 것처럼 보이게 한다.
            .animation(.spring(response: 0.25, dampingFraction: 0.9), value: displayedMonth)

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

            settingsButton
            todayButton
        }
    }

    private var settingsButton: some View {
        Button {
            showsSettings = true
        } label: {
            Image(systemName: "gearshape.fill")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(MoscoPalette.accent)
                .frame(width: 34, height: 34)
        }
        .moscoGlass(in: Circle())
    }

    /// 항상 상단 오른쪽에 고정 — 압축 여부/현재 달 여부와 무관하게 항상 눌러서
    /// 오늘이 있는 달로, 펼쳐진 상태로 돌아올 수 있다.
    ///
    /// 오늘 날씨가 있으면 같은 캡슐 안에 아이콘과 기온을 붙인다 — 날씨만을 위한
    /// 자리를 새로 만들지 않고, 이미 "오늘"을 가리키는 버튼에 얹는 편이 헤더가
    /// 안 복잡해진다. 못 받아왔으면 원래 모습 그대로다.
    private var todayButton: some View {
        Button {
            goToToday()
        } label: {
            HStack(spacing: 5) {
                Text("오늘")
                    .font(.moscoCaption().weight(.semibold))
                    .foregroundStyle(MoscoPalette.accent)

                if let today = weatherStore.weather(for: Date()) {
                    Image(systemName: today.symbolName)
                        .font(.system(size: 12))
                        .symbolRenderingMode(.multicolor)
                    Text("\(today.highCelsius)°")
                        .font(.moscoCaption())
                        .foregroundStyle(MoscoPalette.textSecondary)
                }
            }
            .padding(.horizontal, 14)
            .frame(height: 34)
        }
        .moscoGlass(in: Capsule())
        .animation(.easeOut(duration: 0.25), value: weatherStore.weather(for: Date()))
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
