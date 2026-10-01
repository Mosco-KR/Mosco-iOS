import SwiftUI
import SwiftData
import UIKit

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
    @State private var showsMonthPicker = false
    /// 홈 입력창의 키보드가 떠 있는가. 떠 있는 동안만 달력 위에 '내리기' 판을 깐다.
    @State private var isKeyboardShown = false
    @State private var showsSearch = false
    @State private var searchPickedDate: Date?
    @State private var navigation = AppNavigation.shared
    /// 오늘 탭이 사라진 걸 예전 사용자에게 한 번 알린다(`CalendarHomeNotice`).
    @AppStorage(CalendarHomeNotice.key) private var homeNotice = ""
    /// 홈 입력창이 고치고 있는 할 일. 홈에는 목록이 없어 대개 비어 있다.
    @State private var homeEditingTodo: TodoItem?
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
                        onSelect: { select($0, from: "calendar_cell") }
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
            // **키보드가 올라와도 달력 크기는 그대로다.** 이게 없으면 격자 높이가
            // 키보드만큼 줄어 칸이 통째로 찌그러졌다가 펴진다. 입력창만 키보드 위로
            // 올라간다(아래 `safeAreaInset`) — 하루 페이지와 같은 방식.
            .ignoresSafeArea(.keyboard, edges: .bottom)
            // 키보드가 떠 있는 동안 달력을 누르거나 아래로 쓸면 키보드만 내린다.
            // 그 첫 손짓은 날짜를 열지 않는다 — 키보드를 내리려고 누른 자리가 마침
            // 날짜 칸이라 하루 페이지가 밀려 들어오면, 쓰던 것을 잃은 것처럼 보인다.
            .overlay {
                if isKeyboardShown {
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture { dismissKeyboard() }
                        .gesture(
                            DragGesture(minimumDistance: 12).onEnded { value in
                                if value.translation.height > 0 { dismissKeyboard() }
                            }
                        )
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
                isKeyboardShown = true
            }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
                isKeyboardShown = false
            }
            // 다른 달을 보고 있을 때만 '이번 달'이 떠오른다.
            .jumpBack(String(localized: "이번 달"), isShown: visibleMonth != .containing(Date())) {
                goToToday()
            }
            // 입력창은 늘 아래에 있다 — 앱을 켜자마자 적을 수 있어야 한다. 예전엔
            // 달력 화면에 입력창이 없어서, 날짜를 눌러 들어가야 적을 수 있었다.
            // 오늘로 적힌다(입력창의 날짜 칩으로 바꿀 수 있다).
            .safeAreaInset(edge: .bottom, spacing: 0) {
                QuickAddView(
                    date: calendar.startOfDay(for: Date()),
                    editingTodo: $homeEditingTodo,
                    analyticsSource: "calendar_home"
                )
            }
            .sheet(isPresented: $showsMonthPicker) {
                MonthPickerSheet(month: $visibleMonth)
            }
            // '오늘 할 일' 위젯·라이브 액티비티로 들어오면 오늘 페이지를 바로 연다.
            // 꺼져 있다 켜진 경우엔 URL이 먼저 와 있으므로 처음 값도 본다.
            .onChange(of: navigation.todayPageRequest, initial: true) { _, source in
                guard let source else { return }
                navigation.todayPageRequest = nil
                select(Date(), from: source)
            }
            .overlay(alignment: .bottom) {
                // 다른 달을 볼 때는 그 자리를 '이번 달' 버튼이 쓰므로 비켜준다.
                if homeNotice == CalendarHomeNotice.pending, visibleMonth == .containing(Date()) {
                    homeMoveNotice
                        .padding(.horizontal, Metrics.spacingMD)
                        .padding(.bottom, Metrics.spacingSM)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.85), value: homeNotice)
            // 검색 결과를 고르면 시트가 닫힌 **뒤에** 그날 페이지를 연다 — 닫히는 중에
            // 밀어 넣으면 내비게이션이 씹힌다.
            .sheet(isPresented: $showsSearch, onDismiss: {
                // 검색이 쓰이는지 — 결과를 골라 그날로 갔는지만 센다.
                Analytics.log(.searchClosed(openedResult: searchPickedDate != nil))
                if let date = searchPickedDate {
                    searchPickedDate = nil
                    select(date, from: "search")
                }
            }) {
                SearchSheet { searchPickedDate = $0 }
            }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(item: $selectedDate) { day in
                DayTodosContentView(date: day)
            }
            #if DEBUG
            .task {
                guard ScreenshotDemo.scene == .today else { return }
                selectedDate = Calendar.current.startOfDay(for: .now)
            }
            #endif
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
                select(Date(), from: "tutorial")
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
    private func select(_ day: Date, from source: String) {
        // 홈 입력창에 쓰던 키보드가 하루 페이지까지 따라가지 않게 먼저 내린다.
        dismissKeyboard()
        let start = calendar.startOfDay(for: day)
        Analytics.log(.dayOpened(from: source, isToday: calendar.isDateInToday(start)))
        // 안내가 가리키던 일(오늘을 눌러 열기)을 했으면 안내는 할 일을 다 했다.
        if homeNotice == CalendarHomeNotice.pending, calendar.isDateInToday(start) {
            homeNotice = CalendarHomeNotice.done
        }
        selectedDate = start
        tutorial?.didOpenDay(start)
    }

    private func dismissKeyboard() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil, from: nil, for: nil
        )
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
                // 영어는 숫자 대신 달 이름("Aug")이 온다 — "8"만으로는 달로 읽히지 않는다.
                Text(verbatim: AppLanguage.current == .en ? DateText.monthName(visibleMonth.month) : "\(visibleMonth.month)")
                    .font(.system(size: 38, weight: .bold).monospacedDigit())
                    .contentTransition(.numericText(value: Double(visibleMonth.month)))

                // '월'·연도·화살표를 한 덩어리로 세로 가운데에 맞춘다. 화살표가 위첨자처럼
                // 붙으면 누르는 건지 장식인지 헷갈렸다. 달 고르기가 열리면 위로 뒤집힌다.
                HStack(alignment: .center, spacing: 5) {
                    if AppLanguage.current != .en {
                        Text(verbatim: AppLanguage.current == .ja ? "月" : "월")
                            .font(.moscoTitle())
                            .foregroundStyle(MoscoPalette.textSecondary)
                    }

                    // 올해가 아닌 달을 보고 있을 때만 연도를 붙인다.
                    if visibleMonth.year != calendar.component(.year, from: Date()) {
                        Text(verbatim: DateText.yearLabel(visibleMonth.year))
                            .font(.moscoCaption())
                            .foregroundStyle(MoscoPalette.textSecondary)
                            .transition(.opacity)
                    }

                    Image(systemName: "chevron.down")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(MoscoPalette.textSecondary)
                        .rotationEffect(.degrees(showsMonthPicker ? 180 : 0))
                        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: showsMonthPicker)
                }
            }
            .foregroundStyle(MoscoPalette.textPrimary)
            .animation(.spring(response: 0.25, dampingFraction: 0.9), value: visibleMonth)
            // 달 이름을 누르면 달 고르기 — 몇 달을 넘겨 가야 하는 일을 한 번에 끝낸다.
            .contentShape(Rectangle())
            .onTapGesture { showsMonthPicker = true }
            .accessibilityAddTraits(.isButton)
            .accessibilityHint("달을 골라 이동합니다")

            calendarChip

            Spacer()

            // '오늘'은 여기 없다 — 달력의 오늘 동그라미가 이미 말하고, 다른 달을 볼 때만
            // 아래에 '이번 달'이 떠오른다(`jumpBack`). 늘 박혀 있으면 같은 말을 두 번 한다.
            searchButton
            settingsButton
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
        if visibleCalendars.count == calendars.count { return String(localized: "전체") }
        if let only = visibleCalendars.first, visibleCalendars.count == 1 { return only.name }
        return String(localized: "\(visibleCalendars.count)개")
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

    /// 업데이트 뒤 처음 한 번. 탭 바를 눌러 오늘 할 일을 보던 사람에게 그 자리가
    /// 어디로 갔는지 알린다. 오늘을 눌러보거나 닫으면 다시 안 뜬다.
    private var homeMoveNotice: some View {
        HStack(spacing: 12) {
            Image(systemName: "hand.point.up.left.fill")
                .font(.system(size: 18))
                .foregroundStyle(MoscoPalette.accent)
            VStack(alignment: .leading, spacing: 2) {
                Text("오늘 할 일은 여기로 옮겼어요")
                    .font(.moscoCaption().weight(.semibold))
                    .foregroundStyle(MoscoPalette.textPrimary)
                Text("달력에서 오늘을 누르면 열려요")
                    .font(.moscoCaption())
                    .foregroundStyle(MoscoPalette.textSecondary)
            }
            Spacer(minLength: 0)
            Button {
                homeNotice = CalendarHomeNotice.done
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(MoscoPalette.textSecondary)
                    .frame(width: 32, height: 32)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("안내 닫기")
        }
        .padding(.leading, 14)
        .padding(.vertical, 10)
        .padding(.trailing, 4)
        // 떠 있는 요소라 글라스를 쓴다(규범: 글라스는 떠 있는 것에만).
        .moscoGlass(in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: .black.opacity(0.1), radius: 12, y: 4)
    }

    private var searchButton: some View {
        Button {
            showsSearch = true
        } label: {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(MoscoPalette.accent)
                .frame(width: 34, height: 34)
        }
        .moscoGlass(in: Circle())
        .accessibilityLabel("검색")
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
    private var weekdayHeader: some View {
        HStack(spacing: 0) {
            ForEach(DateText.weekdaySymbols(), id: \.self) { symbol in
                Text(symbol)
                    .font(.moscoCaption())
                    .foregroundStyle(MoscoPalette.textSecondary)
                    .frame(maxWidth: .infinity)
            }
        }
    }

}
