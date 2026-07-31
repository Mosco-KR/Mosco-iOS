import SwiftUI
import SwiftData

/// 네이티브 TabView 그대로 — iOS 26+에서는 탭 바가 시스템이 알아서 리퀴드
/// 글래스로 그려준다. "오늘" 버튼은 이제 CalendarScreen의 헤더 오른쪽에
/// 고정된 글래스 버튼으로 있어서, 여기서는 따로 얹을 게 없다.
struct RootTabView: View {
    @State private var tutorialManager = TutorialManager()
    @Environment(\.modelContext) private var modelContext
    @Query private var categories: [TodoCategory]

    /// 앱 테마(액센트) 색과 통일된 기본 카테고리. "미분류"로 남겨두는 대신,
    /// 카테고리를 하나도 안 만든 사용자도 첫 할 일부터 뭔가에는 속하게 한다.
    private static let defaultCategoryColorHex = "8B5CF6"

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
        .onAppear {
            guard categories.isEmpty else { return }
            modelContext.insert(TodoCategory(name: "할 일", colorHex: Self.defaultCategoryColorHex, sortOrder: 0, isDefault: true))
        }
    }
}
