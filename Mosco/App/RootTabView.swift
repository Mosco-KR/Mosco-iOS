import SwiftUI
import SwiftData
import WidgetKit

/// 네이티브 TabView 그대로 — iOS 26+에서는 탭 바가 시스템이 알아서 리퀴드
/// 글래스로 그려준다. "오늘" 버튼은 이제 CalendarScreen의 헤더 오른쪽에
/// 고정된 글래스 버튼으로 있어서, 여기서는 따로 얹을 게 없다.
struct RootTabView: View {
    @State private var tutorialManager = TutorialManager()
    @State private var weatherStore = WeatherStore()
    @State private var notificationScheduler = TodoNotificationScheduler()
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Query private var categories: [TodoCategory]
    @Query private var calendars: [TodoCalendar]
    /// 시드는 앱 실행당 한 번만. `onAppear`은 여러 번 불릴 수 있다.
    @State private var didSeed = false
    /// 앱을 켜면 달력부터 — 할 일과 메모는 거기서 한 번씩 옆으로 가면 된다.
    @State private var selectedTab: Tab = .calendar

    private enum Tab: Hashable {
        case todo, calendar, upcoming
    }
    /// 알림 재예약의 입력 — 할 일이나 카테고리 설정이 바뀌면 이 배열도 바뀌므로,
    /// 이걸 지켜보다가 통째로 다시 계산한다.
    @Query private var todos: [TodoItem]

    /// 앱 테마(액센트) 색과 통일된 기본 카테고리. "미분류"로 남겨두는 대신,
    /// 카테고리를 하나도 안 만든 사용자도 첫 할 일부터 뭔가에는 속하게 한다.
    private static let defaultCategoryColorHex = "8B5CF6"

    /// 알림에 영향을 주는 값들만 추린 키 — 이게 바뀔 때만 재예약한다.
    /// 제목/시간/카테고리 알림 설정이 들어가고, 색이나 메모처럼 알림과 무관한
    /// 변경으로는 다시 예약하지 않는다.
    private var rescheduleKey: String {
        // 전체 스위치도 키에 넣어야 껐을 때 예약이 즉시 걷힌다.
        "\(notificationScheduler.isEnabled)|" + todos.map { todo in
            let category = todo.category
            return [
                todo.id.uuidString,
                todo.title,
                todo.startTime.map { "\($0.timeIntervalSince1970)" } ?? "-",
                todo.date.map { "\($0.timeIntervalSince1970)" } ?? "-",
                todo.repeatRule.rawValue,
                category.map { "\($0.notifiesBeforeStart)-\($0.notificationLeadMinutes)" } ?? "-"
            ].joined(separator: "|")
        }
        .joined(separator: ";")
    }

    /// 기본 카테고리·캘린더를 보장하고, 아직 어느 캘린더에도 안 들어간 할 일을
    /// 기본 캘린더로 옮긴다.
    ///
    /// **`@Query` 배열이 아니라 `modelContext`에서 직접 조회하는 게 핵심이다.**
    /// 예전엔 `calendars.isEmpty`로 판단했는데, `onAppear`이 쿼리 결과가 갱신되기
    /// 전에 한 번 더 돌면 방금 넣은 걸 못 보고 또 넣었다 — 앱을 지웠다 다시 깔면
    /// "기본" 캘린더가 두 개가 되던 원인이다. 컨텍스트 조회는 아직 저장 안 된
    /// 삽입까지 함께 보여주므로 이 창이 없다.
    private func seedIfNeeded() {
        guard !didSeed else { return }
        didSeed = true

        let existingCategories = (try? modelContext.fetch(FetchDescriptor<TodoCategory>())) ?? []
        if existingCategories.isEmpty {
            modelContext.insert(
                TodoCategory(name: "할 일", colorHex: Self.defaultCategoryColorHex, sortOrder: 0, isDefault: true)
            )
        }

        let existingCalendars = (try? modelContext.fetch(FetchDescriptor<TodoCalendar>())) ?? []
        let fallback = existingCalendars.min { $0.createdAt < $1.createdAt } ?? {
            let created = TodoCalendar(
                name: "기본",
                colorHex: Self.defaultCategoryColorHex,
                sortOrder: 0,
                isDefault: true
            )
            modelContext.insert(created)
            return created
        }()
        fallback.isDefault = true

        // 캘린더 기능이 생기기 전에 만든 할 일은 `calendar`가 nil이라, 특정 캘린더를
        // 끄는 순간 통째로 사라진 것처럼 보인다. 소속을 지정하는 UI가 따로 없으므로
        // nil은 항상 "아직 배정 안 됨"이지 "일부러 비워둠"이 아니다.
        let allTodos = (try? modelContext.fetch(FetchDescriptor<TodoItem>())) ?? []
        for todo in allTodos where todo.calendar == nil {
            todo.calendar = fallback
        }
    }

    /// 기본 캘린더·기본 카테고리는 각각 하나만 있어야 한다. 둘 이상이면 가장
    /// 먼저 만들어진 것만 남기고 나머지의 소속 항목을 옮긴 뒤 지운다.
    ///
    /// 정렬 기준에 `id`까지 넣는 건 **여러 기기가 같은 결론에 도달하게** 하려는
    /// 것이다. `createdAt`만 보면 기기 시계가 다를 때 서로 상대를 지워버릴 수 있다.
    private func mergeDuplicateDefaults() {
        let duplicateCalendars = calendars
            .filter(\.isDefault)
            .sorted { stableOrder(($0.createdAt, $0.id), ($1.createdAt, $1.id)) }
        if duplicateCalendars.count > 1, let keeper = duplicateCalendars.first {
            for duplicate in duplicateCalendars.dropFirst() {
                // `TodoCalendar.delete`는 기본 캘린더를 지키려고 isDefault면 아무것도
                // 안 한다 — 지울 쪽의 기본 표시를 먼저 내려야 그 안전장치를 통과한다.
                duplicate.isDefault = false
                TodoCalendar.delete(duplicate, reassigningTodosTo: keeper, in: modelContext)
            }
        }

        let duplicateCategories = categories
            .filter(\.isDefault)
            .sorted { stableOrder(($0.createdAt, $0.id), ($1.createdAt, $1.id)) }
        if duplicateCategories.count > 1, let keeper = duplicateCategories.first {
            for duplicate in duplicateCategories.dropFirst() {
                duplicate.isDefault = false
                TodoCategory.delete(duplicate, reassigningTodosTo: keeper, in: modelContext)
            }
        }
    }

    private func stableOrder(_ lhs: (Date, UUID), _ rhs: (Date, UUID)) -> Bool {
        if lhs.0 != rhs.0 { return lhs.0 < rhs.0 }
        return lhs.1.uuidString < rhs.1.uuidString
    }

    var body: some View {
        // .environment()를 overlay 뒤에 체이닝하는 대신, ZStack 전체를 감싼
        // 가장 바깥 수식자로 둔다 — TabView + 오버레이 양쪽 다 확실히 그 아래
        // 자손이 되게 해서, 환경 전파 순서를 둘러싼 애매함을 없앤다.
        ZStack {
            // 라벨 텍스트 없이 아이콘만 — `Label` 대신 `Image`를 주면 시스템이
            // 아이콘 전용 탭으로 그린다. 접근성 이름은 `accessibilityLabel`로 남긴다
            // (텍스트를 지운다고 VoiceOver 사용자까지 못 읽게 하면 안 된다).
            TabView(selection: $selectedTab) {
                TodayTodoScreen()
                    .tabItem { Image(systemName: "list.bullet") }
                    .accessibilityLabel("오늘 계획")
                    .tag(Tab.todo)

                CalendarScreen()
                    .tabItem { Image(systemName: "calendar") }
                    .accessibilityLabel("달력")
                    .tag(Tab.calendar)

                UpcomingScreen()
                    .tabItem { Image(systemName: "calendar.badge.clock") }
                    .accessibilityLabel("앞으로 2주")
                    .tag(Tab.upcoming)
            }
            // 명시적으로 안 주면 시스템 기본(파란색)을 쓴다 — 앱 테마(바이올렛)가
            // 선택된 탭 색상에도 이어지도록 지정.
            .tint(MoscoPalette.accent)

        }
        // 튜토리얼이 "지금 눌러야 할 자리"를 알려면 그 요소들의 화면 좌표가 필요하다.
        // 각 화면이 `.tutorialAnchor(...)`로 등록한 좌표를 여기서 한꺼번에 받는다.
        .overlayPreferenceValue(TutorialAnchorKey.self) { anchors in
            GeometryReader { proxy in
                TutorialOverlayView(
                    rects: anchors.mapValues { proxy[$0] },
                    screenSize: proxy.size
                )
            }
            .ignoresSafeArea()
        }
        .environment(tutorialManager)
        .environment(weatherStore)
        .environment(notificationScheduler)
        .task {
            Analytics.log(.appOpened(isColdStart: true))
            // 사람들이 실제로 몇 건을 들고 쓰는지 모르면 성능 작업의 목표를
            // 정할 수 없다 — 지금까지 전부 추측이었다.
            Analytics.log(
                .dataScale(
                    todoCount: todos.count,
                    categoryCount: categories.count,
                    calendarCount: calendars.count
                )
            )
            // 위젯은 익스텐션이라 직접 못 보낸다 — App Group에 쌓아둔 걸 여기서 비운다.
            Analytics.flushPendingFromExtensions()
            // 실패해도(권한 거부/케이퍼빌리티 미설정) 조용히 넘어가고 날씨만 안 보인다.
            weatherStore.loadIfNeeded()
            await notificationScheduler.refreshAuthorizationStatus()
        }
        .onChange(of: selectedTab, initial: true) { _, tab in
            Analytics.log(.tabViewed(tab: String(describing: tab)))
        }
        // 위젯이 실어 보낸 표시를 읽어 어느 위젯으로 들어왔는지 남긴다.
        // 위젯은 원래 눌러도 그냥 앱이 열릴 뿐이라 구분할 방법이 없었다.
        .onOpenURL { url in
            guard let kind = WidgetDeepLink.kind(from: url) else { return }
            Analytics.log(.widgetTapped(kind: kind))
        }
        // 할 일이 추가·수정·삭제되거나 카테고리 알림 설정이 바뀌면 통째로 다시 예약한다.
        .task(id: rescheduleKey) {
            await notificationScheduler.reschedule(todos: todos)
        }
        .onChange(of: scenePhase) { _, phase in
            // 위젯은 자정에만 스스로 다시 그린다 — 그 사이 앱에서 할 일을 고쳐도
            // 홈 화면은 옛날 것을 계속 보여준다. 편집이 끝나고 앱을 벗어나는
            // 시점이 다시 그리기 가장 좋은 자리다(편집 중에 매번 깨우면 시스템이
            // 갱신 예산을 금세 소진한다).
            if phase == .background {
                WidgetCenter.shared.reloadAllTimelines()
            }
            // 설정 앱에서 권한을 바꾸고 돌아왔을 수 있다 — 돌아올 때마다 맞춰준다.
            guard phase == .active else { return }
            Task {
                await notificationScheduler.reschedule(todos: todos)
                weatherStore.retry()
            }
        }
        .onAppear(perform: seedIfNeeded)
        // 중복 정리는 **켤 때 한 번이 아니라 목록이 바뀔 때마다** 돌아야 한다.
        // iCloud를 켠 뒤로는 이런 순서가 실제로 벌어진다: 앱을 새로 깔면 로컬이
        // 비어 있으니 기본 캘린더·카테고리를 즉시 만드는데, 그 **뒤에** 클라우드에서
        // 예전 기본값이 내려온다 — 그래서 "기본"이 둘, "할 일"이 둘이 된다.
        // 실행 시점에 한 번만 보면 그 도착을 못 본다.
        .onChange(of: calendars, initial: true) { _, _ in mergeDuplicateDefaults() }
        .onChange(of: categories, initial: true) { _, _ in mergeDuplicateDefaults() }
    }
}
