import AppIntents
import SwiftData
import WidgetKit

/// 위젯의 체크박스가 부르는 인텐트. 앱을 열지 않고 위젯 프로세스에서 바로
/// 저장소를 고친다(iOS 17의 인터랙티브 위젯).
///
/// 반복 일정 때문에 **날짜를 함께 받는다**. 반복은 날마다 따로 완료되므로
/// (`TodoItem.setCompleted(_:on:)`), 어느 날의 인스턴스를 눌렀는지 모르면
/// 엉뚱한 날이 완료 처리된다.
///
/// 파라미터가 UUID·Date가 아니라 문자열인 건 인텐트 파라미터로 안전하게
/// 실어 나를 수 있는 타입으로 맞춘 것이다 — 날짜는 앱 전체가 쓰는 `dayKey`
/// 규칙(자정의 epoch 초)을 그대로 쓴다.
struct ToggleTodoCompletionIntent: AppIntent {
    static var title: LocalizedStringResource = "할 일 완료 전환"
    /// 눌러도 앱이 열리지 않는다 — 위젯에 남아서 그 자리에서 체크만 된다.
    static var openAppWhenRun: Bool = false

    @Parameter(title: "할 일") var todoID: String
    @Parameter(title: "날짜") var dayKey: String

    init() {}

    init(todoID: UUID, day: Date) {
        self.todoID = todoID.uuidString
        self.dayKey = day.dayKey
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        WidgetStore.toggleCompletion(todoID: todoID, dayKey: dayKey)
        return .result()
    }
}
