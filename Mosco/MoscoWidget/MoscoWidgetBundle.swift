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
        // 맥에는 ActivityKit이 없어서 이 항목만 빠진다. 나머지 위젯 셋은 그대로다.
        #if !targetEnvironment(macCatalyst)
        TodoLiveActivity()
        #endif
    }
}
