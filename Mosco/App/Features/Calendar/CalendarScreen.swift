import SwiftUI
import SwiftData

/// 캘린더 탭. 이 화면은 **조립만** 한다 — 데이터 계산은 `CalendarSnapshotStore`가
/// 백그라운드에서, 페이징은 `MonthPagerView`가(=UIScrollView), 터치는
/// `MonthPageInteractionLayer`가 각자 맡는다.
///
/// 예전엔 여기서 `@Query`로 할 일을 직접 들고, 반복 일정을 펼치고, 재계산 여부를
/// 판단할 키까지 computed property로 만들었다. 그래서 할 일이 하나만 바뀌어도,
/// 심지어 달을 넘기기만 해도 화면 전체 body가 다시 돌면서 그 계산들이 프레임
/// 안으로 딸려 들어왔다.
struct CalendarScreen: View {
    @Environment(WeatherStore.self) private var weatherStore

    @State private var store = CalendarSnapshotStore()
    @State private var visibleMonth = CalendarMonth.containing(Date())
    @State private var selectedDate: Date?
    /// 압축(주간 스트립) 상태에서 보고 있는 주의 시작일. 페이저가 좌우로 넘어가면
    /// 이 값이 바뀌고, 그에 맞춰 선택 날짜가 **요일을 유지한 채** 따라간다.
    @State private var visibleWeekStart = WeekWindow.normalized(Date())
    /// 날짜를 고르기 **직전에** 보고 있던 달. 뒤로 나올 때 여기로 되돌린다.
    ///
    /// 두 가지 이상함을 한 번에 없앤다. ① 6월 격자에서 5월 말 흐린 날짜를 눌렀다가
    /// 뒤로 나오면 5월에 가 있었다(고른 날짜의 달을 그대로 따라갔으니까).
    /// ② 압축 상태로 주를 넘겨 9월까지 갔다가 뒤로 나오면 격자는 8월인데 헤더만
    /// 9월이었다 — 둘 다 "들어온 자리로 돌아온다"로 정리된다.
    @State private var monthBeforeSelection: CalendarMonth?
    @State private var showsSettings = false
    @Query(sort: \TodoCalendar.sortOrder) private var calendars: [TodoCalendar]
    /// 숨긴 캘린더들. 비어 있으면 전부 보인다.
    @AppStorage(CalendarSelection.storageKey) private var hiddenCalendarIDs = ""
    /// 월 헤더 + 요일 헤더의 높이. 페이지 높이를 여기서 빼서 정하는데, 이 값이
    /// 압축 애니메이션과 무관하게 안정적이어야 한다 — 페이저 자신의 프레임을 재서
    /// 되먹이면 접히는 매 프레임마다 페이지가 다시 그려진다.
    @State private var topChromeHeight: CGFloat = 0

    private let calendar = Calendar.current

    var body: some View {
        GeometryReader { geometry in
            let pageSize = CGSize(
                width: geometry.size.width - Metrics.spacingSM * 2,
                height: max(geometry.size.height - topChromeHeight, 0)
            )

            VStack(spacing: 0) {
                topChrome

                // 펼친 상태는 달 페이저, 고른 상태는 주 페이저 — 둘 다 가로 페이징
                // 스크롤뷰다. 예전엔 하나의 달 페이지가 "선택된 주만 남기고 접는"
                // 방식으로 둘을 겸했는데, 그러면 주를 넘길 때 행이 접히고 펴지는 게
                // 세로 애니메이션으로 보였다.
                Group {
                    if selectedDate == nil {
                        MonthPagerView(
                            snapshot: store.snapshot,
                            pageSize: pageSize,
                            today: calendar.startOfDay(for: Date()),
                            visibleMonth: $visibleMonth,
                            onSelect: select
                        )
                    } else {
                        WeekPagerView(
                            width: pageSize.width,
                            today: calendar.startOfDay(for: Date()),
                            selectedDate: selectedDate,
                            weatherSymbol: { weatherStore.weather(for: $0)?.symbolName },
                            visibleWeekStart: $visibleWeekStart,
                            onSelect: select,
                            onExpand: collapse
                        )
                    }
                }
                .padding(.horizontal, Metrics.spacingSM)
                .frame(height: selectedDate == nil ? pageSize.height : WeekStripView.height)
                .clipped()

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
        // 할 일 관찰을 이 리프 하나에 가둔다 — 이 화면의 body는 할 일이 바뀌어도
        // 다시 돌지 않는다.
        .background(TodoQueryBridge(store: store))
        .onChange(of: visibleMonth) { _, month in
            store.focus(on: month)
            // 오늘로부터 몇 달 떨어진 곳을 보는지. 스냅샷 계산 범위(±8개월)가
            // 실제 사용과 맞는지 판단할 근거가 된다.
            Analytics.log(
                .monthNavigated(offsetFromToday: CalendarMonth.containing(Date()).distance(to: month))
            )
        }
        // 주 페이저가 좌우로 넘어가면 선택 날짜를 **같은 요일 자리**로 옮긴다
        // (iOS 캘린더와 같은 거동). select()가 이 값을 바꿀 때도 이 핸들러가 도는데,
        // 그때는 계산 결과가 이미 선택된 날짜와 같아서 아무 일도 안 일어난다.
        .onChange(of: visibleWeekStart) { _, weekStart in
            guard let current = selectedDate else { return }
            let weekdayOffset = calendar.dateComponents(
                [.day],
                from: WeekWindow.normalized(current),
                to: current
            ).day ?? 0
            guard let moved = calendar.date(byAdding: .day, value: weekdayOffset, to: weekStart),
                  moved != current
            else { return }
            selectedDate = moved
            let month = CalendarMonth.containing(moved)
            if month != visibleMonth { visibleMonth = month }
        }
        // 지운 캘린더의 id가 숨김 목록에 남아 있어도 동작에 영향은 없지만,
        // 나중에 같은 id가 재사용될 일은 없으니 그냥 정리해둔다.
        .onChange(of: calendars.map(\.id), initial: true) { _, ids in
            let alive = Set(ids.map(\.uuidString))
            let pruned = hiddenIDs.intersection(alive)
            guard pruned != hiddenIDs else { return }
            hiddenCalendarIDs = CalendarSelection.raw(from: pruned)
        }
        .sheet(isPresented: $showsSettings) {
            SettingsScreen()
        }
    }

    // MARK: - 동작

    private func select(_ day: Date) {
        let normalized = calendar.startOfDay(for: day)
        // 격자에서 처음 들어올 때만 기억한다 — 압축 상태에서 스트립의 다른 날짜를
        // 눌러 이동하는 동안 이 값이 덮어써지면 "들어온 자리"를 잃는다.
        if selectedDate == nil { monthBeforeSelection = visibleMonth }

        // 이전/다음 달의 흐린 날짜를 탭해도 그 달로 넘어가면서 선택되게 한다.
        let month = CalendarMonth.containing(normalized)
        if month != visibleMonth { visibleMonth = month }
        // selectedDate를 먼저 정하는 게 중요하다 — visibleWeekStart의 onChange가
        // 이 값을 기준으로 요일을 유지하므로, 순서가 바뀌면 엉뚱한 날로 튄다.
        selectedDate = normalized
        visibleWeekStart = WeekWindow.normalized(normalized)
    }

    private func collapse() {
        if let origin = monthBeforeSelection { visibleMonth = origin }
        monthBeforeSelection = nil
        selectedDate = nil
    }

    private func goToToday() {
        withAnimation(.easeInOut(duration: 0.3)) {
            // "오늘"은 들어온 자리와 무관하게 오늘로 가는 버튼이라, 기억해둔 달을
            // 되돌리면 안 된다 — 지우고 간다.
            monthBeforeSelection = nil
            visibleMonth = .containing(Date())
            visibleWeekStart = WeekWindow.normalized(Date())
            selectedDate = nil
        }
    }

    // MARK: - 헤더

    private var topChrome: some View {
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
                Text("\(visibleMonth.month)")
                    .font(.system(size: 38, weight: .bold).monospacedDigit())
                    .contentTransition(.numericText(value: Double(visibleMonth.month)))

                Text("월")
                    .font(.moscoTitle())
                    .foregroundStyle(MoscoPalette.textSecondary)

                // 올해가 아닌 달을 보고 있을 때만 연도를 붙인다.
                if visibleMonth.year != calendar.component(.year, from: Date()) {
                    Text(verbatim: "\(visibleMonth.year)년")
                        .font(.moscoCaption())
                        .foregroundStyle(MoscoPalette.textSecondary)
                        .transition(.opacity)
                }
            }
            .foregroundStyle(MoscoPalette.textPrimary)
            .animation(.spring(response: 0.25, dampingFraction: 0.9), value: visibleMonth)

            // 날짜를 고른 상태에선 감춘다 — 뒤로가기 화살표와 D-day 배지가 같은
            // 줄을 쓰는데 칩까지 넣으면 "오늘" 버튼이 두 줄로 깨진다. 그 상태에선
            // 하루에 집중하는 중이고, 한 번 나가면 다시 보인다.
            if selectedDate == nil {
                calendarChip
                    .transition(.opacity.combined(with: .scale(scale: 0.85)))
            }

            // 날짜를 골라 리스트로 들어와 있으면, 오늘 기준 며칠인지 배지로 보여준다.
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

    /// 어떤 캘린더를 볼지 고르는 칩. 하나만 고르는 게 아니라 **체크로 켜고 끈다** —
    /// 그래서 "통합"이라는 별도 항목이 없다. 전부 켜져 있으면 그게 곧 전체 보기다.
    private var calendarChip: some View {
        Menu {
            ForEach(calendars) { calendar in
                Button {
                    toggleVisibility(of: calendar)
                } label: {
                    Label(
                        calendar.name,
                        systemImage: CalendarSelection.isVisible(calendar, hidden: hiddenIDs)
                            ? "checkmark.circle.fill"
                            : "circle"
                    )
                }
            }
        } label: {
            HStack(spacing: 4) {
                Circle()
                    .fill(chipColor)
                    .frame(width: 7, height: 7)
                Text(chipLabel)
                    .font(.moscoCaption().weight(.semibold))
                    .foregroundStyle(MoscoPalette.textPrimary)
                    .lineLimit(1)
                Image(systemName: "chevron.down")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(MoscoPalette.textSecondary)
            }
            .padding(.horizontal, 10)
            // 라벨 글자가 "전체"/"기본"/"2개"로 바뀌면 폭도 같이 변한다. 그 변화가
            // 애니메이션으로 흐르면 유리 배경이 따라오지 못해 한 프레임 사각형으로
            // 보였다가 캡슐로 돌아온다 — 폭에 하한을 줘서 흔들림 자체를 줄인다.
            .frame(minWidth: 52, minHeight: 28)
        }
        .moscoGlass(in: Capsule())
        // 유리가 한 프레임 네모로 그려지더라도 여기서 잘려 캡슐 밖으로 안 나온다.
        .clipShape(Capsule())
        // 선택이 바뀌는 순간의 크기 변화는 애니메이션 없이 즉시 반영한다.
        .animation(nil, value: chipLabel)
    }

    private var hiddenIDs: Set<String> {
        CalendarSelection.hidden(from: hiddenCalendarIDs)
    }

    private var visibleCalendars: [TodoCalendar] {
        CalendarSelection.visible(calendars, hidden: hiddenIDs)
    }

    /// 하나만 켜져 있으면 그 이름을, 전부면 "전체", 그 사이면 개수를 보여준다.
    private var chipLabel: String {
        if visibleCalendars.count == calendars.count { return "전체" }
        if let only = visibleCalendars.first, visibleCalendars.count == 1 { return only.name }
        return "\(visibleCalendars.count)개"
    }

    private var chipColor: Color {
        guard visibleCalendars.count == 1, let only = visibleCalendars.first else {
            return MoscoPalette.textSecondary.opacity(0.5)
        }
        return CategoryColorPalette.color(forHex: only.colorHex)
    }

    private func toggleVisibility(of calendar: TodoCalendar) {
        var hidden = hiddenIDs
        let key = calendar.id.uuidString
        if hidden.contains(key) {
            hidden.remove(key)
        } else {
            hidden.insert(key)
        }
        hiddenCalendarIDs = CalendarSelection.raw(from: hidden)
        Analytics.log(
            .calendarFilterChanged(
                visibleCount: calendars.count - hidden.count,
                totalCount: calendars.count
            )
        )
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
    /// "오늘"만 담는다. 예전엔 여기에 날씨 아이콘과 기온까지 붙어 있었는데, 그
    /// 폭 때문에 헤더가 넘쳐서 달 숫자가 잘리고 버튼 글자가 두 줄로 깨졌다.
    /// 날씨는 주간 스트립의 날짜 칸에 날짜별로 이미 나오므로, 헤더에서 한 번 더
    /// 자리를 차지할 이유가 없다.
    private var todayButton: some View {
        Button {
            goToToday()
        } label: {
            Text("오늘")
                .font(.moscoCaption().weight(.semibold))
                .foregroundStyle(MoscoPalette.accent)
                .lineLimit(1)
                .fixedSize()
                .padding(.horizontal, 14)
                .frame(height: 34)
        }
        .moscoGlass(in: Capsule())
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
