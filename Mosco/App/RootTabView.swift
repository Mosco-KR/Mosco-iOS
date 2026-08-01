import SwiftUI
import SwiftData

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

    var body: some View {
        // .environment()를 overlay 뒤에 체이닝하는 대신, ZStack 전체를 감싼
        // 가장 바깥 수식자로 둔다 — TabView + 오버레이 양쪽 다 확실히 그 아래
        // 자손이 되게 해서, 환경 전파 순서를 둘러싼 애매함을 없앤다.
        ZStack {
            TabView {
                CalendarScreen()
                    .tabItem { Label("캘린더", systemImage: "calendar") }
                TodayTodoScreen()
                    .tabItem { Label("오늘 할 일", systemImage: "list.bullet") }
            }
            // 명시적으로 안 주면 시스템 기본(파란색)을 쓴다 — 앱 테마(바이올렛)가
            // 선택된 탭 색상에도 이어지도록 지정.
            .tint(MoscoPalette.accent)

            TutorialOverlayView()
        }
        .environment(tutorialManager)
        .environment(weatherStore)
        .environment(notificationScheduler)
        .task {
            // 실패해도(권한 거부/케이퍼빌리티 미설정) 조용히 넘어가고 날씨만 안 보인다.
            weatherStore.loadIfNeeded()
            await notificationScheduler.refreshAuthorizationStatus()
        }
        // 할 일이 추가·수정·삭제되거나 카테고리 알림 설정이 바뀌면 통째로 다시 예약한다.
        .task(id: rescheduleKey) {
            await notificationScheduler.reschedule(todos: todos)
        }
        .onChange(of: scenePhase) { _, phase in
            // 설정 앱에서 권한을 바꾸고 돌아왔을 수 있다 — 돌아올 때마다 맞춰준다.
            guard phase == .active else { return }
            Task {
                await notificationScheduler.reschedule(todos: todos)
                weatherStore.retry()
            }
        }
        .onAppear {
            guard categories.isEmpty else { return }
            modelContext.insert(TodoCategory(name: "할 일", colorHex: Self.defaultCategoryColorHex, sortOrder: 0, isDefault: true))
        }
    }
}
