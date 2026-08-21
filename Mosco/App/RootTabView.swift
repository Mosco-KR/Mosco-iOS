import SwiftUI
import SwiftData
import StoreKit
import WidgetKit

/// 네이티브 TabView 그대로 — iOS 26+에서는 탭 바가 시스템이 알아서 리퀴드
/// 글래스로 그려준다. "오늘" 버튼은 이제 CalendarScreen의 헤더 오른쪽에
/// 고정된 글래스 버튼으로 있어서, 여기서는 따로 얹을 게 없다.
struct RootTabView: View {
    @State private var weatherStore = WeatherStore()
    @State private var notificationScheduler = TodoNotificationScheduler()
    @State private var cloudSyncStore = CloudSyncStore()
    @State private var todoClipboard = TodoClipboard()
    @State private var reviewPrompt = ReviewPrompt()
    /// 인스턴스가 아니라 **공유본**이다. 잠금화면에서 할 일을 누르면 인텐트가
    /// 앱 프로세스에서 같은 것을 불러 화면을 곧바로 다시 그린다 — 각자 하나씩
    /// 들고 있으면 서로 다른 활동을 잡아 잠금화면에 같은 날이 두 개 뜬다.
    @State private var liveActivityController = TodoLiveActivityController.shared
    /// 첫 사용자를 위한 안내. **공유본이다** — 실제로 그려지는 곳은 앱 창 위에
    /// 얹힌 별도의 창(`TutorialOverlayWindow`)이라, 그쪽과 이 화면이 같은 진행
    /// 상태를 봐야 스포트라이트가 제자리를 겨눈다.
    @State private var tutorial = TutorialCoordinator.shared
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    /// 앱스토어 리뷰 요청. 시스템이 연 3회 한도 안에서 실제로 띄울지 정한다.
    ///
    /// **이 자리에서만 부른다.** 예전엔 할 일 셀이 직접 불렀는데, 셀은 완료 직후
    /// 목록에서 걸러져 사라질 수 있는 뷰다 — 화면에서 내려간 뷰가 1.2초 뒤에
    /// 시트를 띄우려 하고 있었다. 탭 뷰는 앱이 떠 있는 한 항상 살아 있다.
    @Environment(\.requestReview) private var requestReview
    @Query private var categories: [TodoCategory]
    @Query private var calendars: [TodoCalendar]
    /// 시드는 앱 실행당 한 번만. `onAppear`은 여러 번 불릴 수 있다.
    @State private var didSeed = false
    /// 앱을 켜면 달력부터 — 할 일과 메모는 거기서 한 번씩 옆으로 가면 된다.
    @State private var selectedTab: Tab = .calendar

    /// 탭은 둘이다. '다가오는'(앞으로 2주)은 달력 탭과 같은 질문에 답하고 있어서
    /// 걷어냈다 — 앞날은 달력이, 지금 할 일은 목록이 맡는다.
    private enum Tab: Hashable {
        case todo, calendar
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

    /// 라이브 액티비티를 다시 계산해야 하는 값들.
    ///
    /// **완료 여부가 들어가는 게 알림 키와 다른 점이다.** 잠금화면에 떠 있는
    /// 일정을 앱에서 체크하면 그 즉시 걷혀야 하는데, 알림 키에는 완료가 없어서
    /// 그것만 보고 있으면 끝낸 일이 계속 시간을 세고 있게 된다.
    private var liveActivityKey: String {
        // 스위치도 키에 넣어야 껐을 때 떠 있던 것이 즉시 걷힌다.
        "\(liveActivityController.isEnabled)|"
            + todos.map(Self.liveActivityFingerprint(of:)).joined(separator: ";")
    }

    /// 할 일 하나가 라이브 액티비티에 미치는 것들만 문자열 하나로 압축한다.
    ///
    /// 한 줄짜리 배열 리터럴로 쓰면 컴파일러가 타입 추론을 포기한다("unable to
    /// type-check this expression in reasonable time") — 항목이 아홉이라 조합이
    /// 폭발한다. 조각마다 타입을 못박아 두면 그 일이 없다.
    private static func liveActivityFingerprint(of todo: TodoItem) -> String {
        var parts: [String] = []
        parts.append(todo.id.uuidString)
        parts.append(todo.title)
        parts.append(timeKey(todo.startTime))
        parts.append(timeKey(todo.endTime))
        parts.append(timeKey(todo.date))
        parts.append(todo.repeatRule.rawValue)
        parts.append(String(todo.isCompleted))
        parts.append(todo.completedDayKeys?.joined(separator: ",") ?? "-")
        parts.append(todo.category?.colorHex ?? "-")
        // 메모도 잠금화면에 그려지므로 키에 들어가야 한다 — 빠져 있을 때는 메모만
        // 고쳐도 키가 그대로라 갱신이 안 걸렸고, 방금 적은 메모가 안 보였다.
        parts.append(todo.memo ?? "-")
        return parts.joined(separator: "|")
    }

    private static func timeKey(_ date: Date?) -> String {
        guard let date else { return "-" }
        return String(date.timeIntervalSince1970)
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

    /// 리뷰창을 띄운다.
    ///
    /// 바로 띄우지 않고 조금 기다리는 건 체크 애니메이션(스프링 0.35초) 위로
    /// 시스템 시트가 덮치지 않게 하려는 것이다 — 방금 누른 결과를 눈으로 확인한
    /// 다음에 물어야 부탁으로 읽힌다.
    ///
    /// 앱이 앞에 없으면 요청을 내지 않고 깃발을 세워둔 채 기다린다. 백그라운드로
    /// 부르면 시스템이 조용히 버리는데, 그러면 연 3회 중 한 번을 아무것도 안 띄운
    /// 채로 태워버리는 셈이다(돌아왔을 때 `scenePhase` 변화가 다시 부른다).
    private func askForReview() {
        Task {
            try? await Task.sleep(for: .seconds(1.2))
            guard scenePhase == .active else { return }
            // 안내를 따라가는 중에는 묻지 않는다 — 시스템 시트가 마스크 위로 덮치면
            // 지금 눌러야 할 것이 가려지고, 그 순간은 부탁하기에도 나쁜 자리다.
            guard !tutorial.isRunning else { return }
            requestReview()
            reviewPrompt.consumePending()
            Analytics.log(.reviewPromptRequested)
        }
    }

    /// 안내를 따라가다 막힌 사람을 위해 연습용 할 일을 대신 하나 만든다.
    ///
    /// **직접 만든 것과 똑같은 모양이어야 한다** — 시간까지 붙은 채로 만들어야
    /// 다음 단계(완료 → 달력에서 찾기 → 정리)가 원래대로 이어진다.
    private func createPracticeTodo() {
        let today = Calendar.current.startOfDay(for: .now)
        let todo = TodoItem(
            title: "러닝",
            date: today,
            startTime: Calendar.current.date(bySettingHour: 19, minute: 0, second: 0, of: today),
            category: categories.first(where: \.isDefault) ?? categories.first
        )
        todo.calendar = calendars.first(where: \.isDefault) ?? calendars.first
        modelContext.insert(todo)
        Analytics.log(
            .todoCreated(
                source: "tutorial_assist",
                hasDate: true,
                hasTime: true,
                repeatRule: RepeatRule.none.rawValue,
                isMultiDay: false
            )
        )
        tutorial.didCreateTodo(todo)
    }

    private func stableOrder(_ lhs: (Date, UUID), _ rhs: (Date, UUID)) -> Bool {
        if lhs.0 != rhs.0 { return lhs.0 < rhs.0 }
        return lhs.1.uuidString < rhs.1.uuidString
    }

    var body: some View {
        ZStack {
            // 라벨 텍스트 없이 아이콘만 — `Label` 대신 `Image`를 주면 시스템이
            // 아이콘 전용 탭으로 그린다. 접근성 이름은 `accessibilityLabel`로 남긴다
            // (텍스트를 지운다고 VoiceOver 사용자까지 못 읽게 하면 안 된다).
            TabView(selection: $selectedTab) {
                TodayTodoScreen()
                    .tabItem { Image(systemName: "list.bullet") }
                    .accessibilityLabel("할 일")
                    .tag(Tab.todo)

                CalendarScreen()
                    .tabItem { Image(systemName: "calendar") }
                    .accessibilityLabel("달력")
                    .tag(Tab.calendar)
            }
            // 명시적으로 안 주면 시스템 기본(파란색)을 쓴다 — 앱 테마(바이올렛)가
            // 선택된 탭 색상에도 이어지도록 지정.
            .tint(MoscoPalette.accent)
        }
        .environment(weatherStore)
        .environment(notificationScheduler)
        .environment(cloudSyncStore)
        .environment(todoClipboard)
        .environment(reviewPrompt)
        .environment(liveActivityController)
        .environment(tutorial)
        // 안내가 요구하는 탭으로 옮긴다. 탭을 옮기는 일은 여기서만 한다 —
        // 튜토리얼은 "어느 탭이 필요하다"까지만 말하고 실제 이동은 관여하지 않는다.
        .onChange(of: tutorial.step) { _, step in
            switch step?.tab {
            case .todo: selectedTab = .todo
            case .calendar: selectedTab = .calendar
            case nil: break
            }
        }
        // 마지막 '정리' 단계는 마스크를 걷고 돌아서(시스템 메뉴를 열어야 하므로)
        // 탭 바가 열려 있다. 거기서 탭을 옮기면 안내가 가리키던 줄이 사라지므로
        // 제자리로 되돌린다.
        .onChange(of: selectedTab) { _, tab in
            guard let wanted = tutorial.step?.tab else { return }
            switch (wanted, tab) {
            case (.todo, .calendar): selectedTab = .todo
            case (.calendar, .todo): selectedTab = .calendar
            default: break
            }
        }
        // "제가 대신 적어드릴까요?"를 눌렀을 때. 안내가 직접 모델을 건드리지 않고
        // 요청만 올리는 건, 저장소에 무엇을 넣을지는 화면 쪽 사정이기 때문이다.
        .onChange(of: tutorial.practiceTodoRequest) { _, request in
            guard request > 0 else { return }
            createPracticeTodo()
        }
        // 부탁할 때가 됐다는 깃발이 서면 여기서 실제 요청을 낸다.
        .onChange(of: reviewPrompt.isPending) { _, isPending in
            guard isPending else { return }
            askForReview()
        }
        .task {
            // 처음 쓴 날과 오늘 쓴 것을 기록해둔다 — 리뷰는 며칠 써본 뒤에만 부탁한다.
            reviewPrompt.registerLaunch()
            // 실행 자체는 Firebase가 `session_start`·`first_open`으로 이미 센다.
            // 우리가 더할 수 있는 건 "무엇을 얼마나 들고 있는가"뿐이다.
            Analytics.log(
                .dataScale(
                    todoCount: todos.count,
                    categoryCount: categories.count,
                    calendarCount: calendars.count
                )
            )
            // 위젯은 익스텐션이라 직접 못 보낸다 — App Group에 쌓아둔 걸 여기서 비운다.
            Analytics.flushPendingFromExtensions()
            // 지난 실행에서 안내를 도중에 떠났다면 지금 보고한다. 이탈은 그
            // 순간에 못 잡는다 — 앱이 죽을 때는 이벤트를 보낼 시간이 없다.
            tutorial.reportAbandonmentIfNeeded()
            // 처음 온 사람에게만, 그것도 **물어보고** 시작한다. 이미 할 일을 들고
            // 있는 사람(기기를 바꿔 iCloud에서 내려받은 경우)에게 "처음 오셨네요"는
            // 틀린 인사라 아예 띄우지 않는다.
            let willGuide = tutorial.startIfFirstLaunch(hasExistingData: !todos.isEmpty)

            // **권한은 안내가 끝난 뒤에 모아서 묻는다** (`StartupPermissionRequest`).
            // 안내가 안 뜨는 사람은 지금이 그 시점이다.
            if !willGuide {
                await StartupPermissionRequest.run(
                    notifications: notificationScheduler,
                    weather: weatherStore
                )
            }
            await cloudSyncStore.refresh()
        }
        // **안내가 끝난(또는 건너뛴) 바로 다음이 권한을 묻는 자리다.**
        // 앱을 한 번 보여준 뒤에 물어야 무엇에 쓰는 권한인지 알고 고를 수 있다.
        // 한 번 거부되면 앱에서 다시 물을 수 없으므로 이 한 번이 전부다.
        .onChange(of: tutorial.isRunning) { _, isRunning in
            guard !isRunning else { return }
            Task {
                await StartupPermissionRequest.run(
                    notifications: notificationScheduler,
                    weather: weatherStore
                )
            }
        }
        // 탭 이동은 더 이상 세지 않는다. 탭이 둘뿐이고 앱이 달력으로 열리니
        // 그 수는 "기본값이 무엇인가"를 되풀이해 말할 뿐이었다. 어느 화면을
        // 실제로 쓰는지는 만들기·완료 이벤트의 `source`가 답한다.
        // 위젯 탭(URL)은 여기서 받지 않는다. 이 앱은 SwiftUI 생명주기가 아니라
        // UIKit(AppDelegate + SceneDelegate) 위에 올라가 있어서 `.onOpenURL`이
        // 아무 일도 하지 않는다 — 콘솔에 "Cannot use Scene methods for URL ...
        // without using SwiftUI Lifecycle" 경고만 매 body마다 찍혔다.
        // 실제 처리는 `SceneDelegate`가 한다.
        // 할 일이 추가·수정·삭제되거나 카테고리 알림 설정이 바뀌면 통째로 다시 예약한다.
        .task(id: rescheduleKey) {
            await notificationScheduler.reschedule(todos: todos)
        }
        // 할 일이 바뀌면 잠금화면에 떠 있는 것도 다시 계산한다 — 시간을 옮겼거나
        // 체크했는데 잠금화면만 옛날 것을 들고 있으면 안 된다.
        .task(id: liveActivityKey) {
            await liveActivityController.sync()
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
            // 앱을 벗어나 있는 사이 부탁할 때가 됐다면 지금 묻는다.
            if reviewPrompt.isPending { askForReview() }
            Task {
                await notificationScheduler.reschedule(todos: todos)
                // **여기가 '시작 전 → 진행 중' 전환이 실제로 일어나는 자리다.**
                // 푸시 서버가 없어서 앱이 자는 동안에는 문구를 바꿀 수 없다 —
                // 남은 시간은 시스템이 알아서 세지만, 그 밖의 것은 앱이 앞으로
                // 나올 때마다 맞춰준다. 시간만 지나도 띄울 것이 달라지므로
                // 데이터가 그대로여도 매번 다시 계산한다.
                await liveActivityController.sync()
                // 안내 중에는 날씨를 다시 시도하지 않는다 — 위치 권한창이 안내
                // 위로 덮친다.
                if !tutorial.isRunning { weatherStore.retry() }
                // 설정 앱에서 iCloud에 로그인하고 돌아왔을 수 있다.
                await cloudSyncStore.refresh()
            }
        }
        .onAppear(perform: seedIfNeeded)
        // **첫 날씨는 여기서 받는다.** 예전엔 scenePhase가 .active로 *바뀔 때*와
        // 첫 실행 권한 흐름, 둘로만 열렸다. 맥은 창이 이미 활성인 채로 떠서 그
        // 변화가 안 오고, 권한을 이미 정해둔 사람은 첫 흐름도 안 지나간다 —
        // 그래서 맥에서 날씨가 통째로 안 떴다(2026-08-22).
        //
        // **아직 안 물어본 상태에서는 부르지 않는다.** 그러면 위치 권한창이
        // 안내(튜토리얼) 위로 덮친다 — 묻는 순서는 StartupPermissionRequest 몫이다.
        .task {
            if weatherStore.permission == .granted { weatherStore.loadIfNeeded() }
        }
        // 중복 정리는 **켤 때 한 번이 아니라 목록이 바뀔 때마다** 돌아야 한다.
        // iCloud를 켠 뒤로는 이런 순서가 실제로 벌어진다: 앱을 새로 깔면 로컬이
        // 비어 있으니 기본 캘린더·카테고리를 즉시 만드는데, 그 **뒤에** 클라우드에서
        // 예전 기본값이 내려온다 — 그래서 "기본"이 둘, "할 일"이 둘이 된다.
        // 실행 시점에 한 번만 보면 그 도착을 못 본다.
        .onChange(of: calendars, initial: true) { _, _ in mergeDuplicateDefaults() }
        .onChange(of: categories, initial: true) { _, _ in mergeDuplicateDefaults() }
    }
}
