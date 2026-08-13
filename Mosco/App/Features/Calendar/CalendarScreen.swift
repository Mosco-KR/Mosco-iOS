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

    @State private var store = CalendarSnapshotStore()
    @State private var visibleMonth = CalendarMonth.containing(Date())
    /// 값이 들어오면 하루치 페이지가 밀려 들어온다(`navigationDestination`).
    @State private var selectedDate: Date?
    @State private var showsSettings = false
    @Query(sort: \TodoCalendar.sortOrder) private var calendars: [TodoCalendar]
    @Environment(TutorialCoordinator.self) private var tutorial: TutorialCoordinator?
    /// 숨긴 캘린더들. 비어 있으면 전부 보인다.
    @AppStorage(CalendarSelection.storageKey) private var hiddenCalendarIDs = ""
    /// 월 헤더 + 요일 헤더의 높이. 페이지 높이를 여기서 빼서 정하는데, 이 값이
    /// 압축 애니메이션과 무관하게 안정적이어야 한다 — 페이저 자신의 프레임을 재서
    /// 되먹이면 접히는 매 프레임마다 페이지가 다시 그려진다.
    @State private var topChromeHeight: CGFloat = 0

    private let calendar = Calendar.current

    var body: some View {
        // 하루치는 **밀려 들어오는 페이지**다. 예전엔 이 화면이 스스로 접혀서
        // (달 격자 → 주간 스트립) 아래에 리스트를 인라인으로 붙였는데, 한 화면이
        // 두 모습을 오가니 지금 보고 있는 게 달인지 하루인지 헷갈렸고 되돌아가는
        // 길도 직접 만든 화살표 하나뿐이었다. 페이지로 밀어 넣으면 앞뒤 관계가
        // 분명해지고 뒤로 가기(버튼 + 가장자리 스와이프)는 시스템이 맡는다.
        NavigationStack {
            GeometryReader { geometry in
                let pageSize = CGSize(
                    width: geometry.size.width - Metrics.spacingSM * 2,
                    height: max(geometry.size.height - topChromeHeight, 0)
                )

                VStack(spacing: 0) {
                    topChrome

                    MonthPagerView(
                        snapshot: store.snapshot,
                        pageSize: pageSize,
                        today: calendar.startOfDay(for: Date()),
                        visibleMonth: $visibleMonth,
                        onSelect: select
                    )
                    .padding(.horizontal, Metrics.spacingSM)
                    .frame(height: pageSize.height)
                    .clipped()
                }
            }
            .background(MoscoPalette.canvas.ignoresSafeArea(edges: .top))
            // 할 일 관찰을 이 리프 하나에 가둔다 — 이 화면의 body는 할 일이 바뀌어도
            // 다시 돌지 않는다.
            .background(TodoQueryBridge(store: store))
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(item: $selectedDate) { day in
                DayTodosContentView(date: day)
            }
            // 안내가 달력 차례로 넘어오면 오늘이 있는 달로 되돌린다 — 다른 달을
            // 보고 있었다면 "오늘을 눌러보세요"라고 말해도 오늘 칸이 화면에 없다.
            .onChange(of: tutorial.currentStep) { _, step in
                guard step == .openDay else { return }
                visibleMonth = .containing(Date())
            }
            // "대신 열어드릴까요?"를 눌렀을 때. 사용자가 직접 누른 것과 같은 길로
            // 들어가야 그 다음 단계가 똑같이 이어진다.
            .onChange(of: tutorial?.openDayRequest) { _, request in
                guard let request, request > 0 else { return }
                select(Date())
            }
            // 하루치 페이지에서 뒤로 나가면 안내도 그 앞 단계로 되돌아간다 —
            // 없는 줄을 가리키고 있는 것보다 낫다.
            .onChange(of: selectedDate) { _, date in
                if date == nil { tutorial?.didCloseDay() }
            }
            // 달을 넘길 때마다 이벤트를 남기던 것은 걷어냈다. 스와이프 한 번에
            // 하나씩 쌓이는 가장 잦은 이벤트였는데, 그 수가 어느 쪽으로 나오든
            // 다음에 만들 것이 달라지지 않았다(창 크기는 이미 ±30년이다).
            .onChange(of: visibleMonth) { _, month in
                store.focus(on: month)
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
    }

    // MARK: - 동작

    /// 날짜를 고르면 하루치 페이지로 밀고 들어간다.
    ///
    /// 격자를 그 달로 옮기지 않는다 — 페이지가 따로 뜨므로 뒤에 남은 격자는 보던
    /// 자리를 그대로 지키는 게 맞다. 예전엔 화면이 접히며 그 자리에서 바뀌었기 때문에
    /// 달을 따라 옮겨야 했고, 그래서 "들어온 자리"를 따로 기억해뒀다가 되돌리는
    /// 장치가 필요했다. 이제는 그 장치 자체가 필요 없다.
    private func select(_ day: Date) {
        let start = calendar.startOfDay(for: day)
        selectedDate = start
        tutorial?.didOpenDay(start)
    }

    private func goToToday() {
        withAnimation(.easeInOut(duration: 0.3)) {
            visibleMonth = .containing(Date())
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

            calendarChip

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

}
