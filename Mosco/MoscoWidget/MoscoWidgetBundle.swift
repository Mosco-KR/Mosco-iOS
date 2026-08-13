import SwiftUI
import WidgetKit

@main
struct MoscoWidgetBundle: WidgetBundle {
    var body: some Widget {
        TodayTodoWidget()
        WeekCalendarWidget()
        MonthCalendarWidget()
        // 라이브 액티비티도 위젯이다 — 홈 화면 위젯 갤러리에는 안 나오고,
        // 앱이 `Activity.request`로 부를 때 이 설정으로 그려진다.
        TodoLiveActivity()
    }
}
