import SwiftUI

/// 네이티브 TabView 그대로 — iOS 26+에서는 탭 바가 시스템이 알아서 리퀴드
/// 글래스로 그려준다. "오늘" 버튼은 이제 CalendarScreen의 헤더 오른쪽에
/// 고정된 글래스 버튼으로 있어서, 여기서는 따로 얹을 게 없다.
struct RootTabView: View {
    var body: some View {
        TabView {
            CalendarScreen()
                .tabItem { Label("캘린더", systemImage: "calendar") }
            PriorityListScreen()
                .tabItem { Label("할 일", systemImage: "list.bullet") }
        }
        // 명시적으로 안 주면 시스템 기본(파란색)을 쓴다 — 앱 테마(바이올렛)가
        // 선택된 탭 색상에도 이어지도록 지정.
        .tint(MoscoPalette.accent)
    }
}
