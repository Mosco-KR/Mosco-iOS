import SwiftUI

/// 오늘 할 일 탭.
///
/// **하루 페이지를 그대로 쓴다.** 달력에서 날짜를 눌러 들어가는 그 화면이다.
/// 1.4.0에서 오늘 탭을 없앨 때 예전 화면(`TodayTodoScreen`, 662줄)이 하던 일은
/// 하루 페이지가 전부 이어받았다 — 오늘을 보고 있으면 디데이·지난 할 일·날짜 안
/// 정한 할 일 섹션이 그대로 붙는다. 그래서 탭을 되살리면서 지운 화면을 되살리지는
/// 않는다. 같은 것을 두 벌 들고 있으면 한쪽만 고쳐지는 날이 오고, 그게 1.3.x에서
/// 오늘 탭과 하루 페이지가 서로 어긋나 있던 이유였다.
///
/// 탭이라 뒤로 가기가 없다. 주간 스트립으로 다른 날을 보다가 '오늘'이 떠오르면
/// 한 번에 돌아온다(`jumpBack`) — 그 길이 뒤로 가기를 대신한다.
struct TodayScreen: View {
    /// 보고 있는 "오늘". 탭은 앱이 떠 있는 동안 계속 살아 있어서, 이 값을 body에서
    /// 그때그때 계산하면 **자정을 넘긴 뒤에도 어제가 오늘인 척** 남는다. 날짜가
    /// 실제로 바뀌었을 때만 갈아끼운다.
    @State private var day = Calendar.current.startOfDay(for: .now)
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        NavigationStack {
            DayTodosContentView(date: day, origin: .tab)
                // 하루 페이지는 날짜를 자기 `@State`로 들고 있다(주간 스트립으로
                // 옮겨 다니므로). 그래서 날짜가 바뀌면 뷰를 새로 세워야 전해진다.
                .id(day)
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            let today = Calendar.current.startOfDay(for: .now)
            // 같은 날이면 아무것도 하지 않는다 — 잠깐 앱을 벗어났다 돌아온 사람이
            // 보던 날짜와 편집 중이던 것을 잃지 않게.
            guard today != day else { return }
            day = today
        }
    }
}
