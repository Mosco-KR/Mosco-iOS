import SwiftUI
import WidgetKit

@main
struct MoscoWidgetBundle: WidgetBundle {
    var body: some Widget {
        TodayTodoWidget()
        CalendarWidget()
    }
}
