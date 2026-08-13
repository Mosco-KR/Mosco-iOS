import AppIntents
import Foundation

/// 라이브 액티비티의 '완료' 버튼이 부르는 인텐트.
///
/// **여기서는 버튼을 따로 둔다.** 앱의 목록은 셀 몸통을 누르면 완료되지만, 잠금화면은
/// 몸통 탭이 앱을 여는 자리라 같은 방식을 쓸 수 없다 — 누를 곳을 눈에 보이게 두지
/// 않으면 잠금화면에서는 끝낼 방법이 아예 없다.
///
/// 전환이다(완료 고정이 아니라). 잘못 눌러도 같은 자리에서 되돌릴 수 있어야 하는데,
/// 완료한 일정은 곧바로 대상에서 빠져 활동이 정리되므로 실제로 되돌리는 곳은 앱이다.
///
/// `AppIntent`가 아니라 `LiveActivityIntent`인 것이 중요하다. 보통의 인텐트는
/// 위젯 익스텐션 프로세스에서 도는데, 거기서는 앱이 띄운 활동이 하나도 안 보여
/// (`Activity.activities`가 프로세스마다 따로다) 화면을 곧바로 갱신할 수 없다.
/// 이건 시스템이 **앱 프로세스**에서 실행해주므로, 저장하고 나면 앱이 그대로
/// 이어서 활동 내용까지 새로 그린다.
struct ToggleTodoFromActivityIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "할 일 완료 전환"
    /// 눌러도 앱이 화면에 뜨지 않는다 — 잠금화면에 남은 채로 체크된다.
    /// (`LiveActivityIntent`는 앱을 **백그라운드로** 깨워 실행한다.)
    static var openAppWhenRun: Bool = false

    @Parameter(title: "할 일") var todoID: String
    @Parameter(title: "날짜") var dayKey: String

    init() {}

    init(todoID: String, dayKey: String) {
        self.todoID = todoID
        self.dayKey = dayKey
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        TodoCompletionWriter.toggle(todoID: todoID, dayKey: dayKey, source: "live_activity")
        // 저장만 하고 끝내면 잠금화면은 방금 누른 줄을 아직 미완료로 그리고 있다 —
        // 앱을 열어야 취소선이 생기면 눌린 건지 아닌지 알 수가 없다.
        await TodoLiveActivityController.shared.sync()
        return .result()
    }
}
