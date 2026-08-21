import SwiftUI
import SwiftData

/// 할 일 하나에 붙는 **꾹 눌러 나오는 메뉴와 그 뒤에 열리는 것들**.
///
/// 목록 셀(`TodoRow`)에만 있던 것을 꺼냈다. 시간표 블록에도 같은 메뉴가 필요한데,
/// **같은 동작이 화면마다 다르면 그건 다른 기능처럼 읽힌다** — 목록에서는 꾹 눌러
/// 복사가 되는데 시간표에서는 아무 일도 안 일어나면, 사용자는 그걸 고장으로 여긴다.
///
/// 메뉴만 옮긴 게 아니라 메모 시트·경고·삭제 확인까지 한 덩어리로 왔다. 메뉴 항목
/// 하나하나가 그중 무언가를 여는 것이라, 나누면 두 곳을 같이 고쳐야 한다.
struct TodoActions: ViewModifier {
    let todo: TodoItem
    /// 반복 인스턴스라면 그 날짜. 원본이면 nil.
    var occurrenceDate: Date? = nil
    /// 수정 화면으로 보낸다. nil이면 '수정' 항목을 감춘다.
    var onTap: (() -> Void)? = nil
    /// 이 할 일을 지운다. nil이면 삭제 항목을 감춘다.
    var onDelete: (() -> Void)? = nil

    @Environment(TodoClipboard.self) private var clipboard
    /// 튜토리얼이 없는 자리에서도 안전하도록 옵셔널로 받는다.
    @Environment(TutorialCoordinator.self) private var tutorial: TutorialCoordinator?
    @Query(sort: \TodoCalendar.sortOrder) private var calendars: [TodoCalendar]
    @State private var showsMemoEditor = false
    @State private var showsDeleteConfirmation = false
    /// 잠금화면에 띄우려다 막힌 이유. nil이면 아무 일도 없었다.
    @State private var liveActivityBlock: LiveActivityBlock?

    enum LiveActivityBlock: Identifiable {
        /// 시작까지 8시간 넘게 남았다.
        case tooFar
        /// 시작 시각이 이미 지났거나, 날짜가 없어 실제 시각을 만들 수 없다.
        case notUpcoming
        /// 앱 설정이나 시스템 설정에서 라이브 액티비티가 꺼져 있다.
        case unavailable

        var id: Self { self }

        var title: String {
            switch self {
            case .tooFar: "8시간 안에 시작하는 할 일만 띄울 수 있어요"
            case .notUpcoming: "이미 시작한 할 일이에요"
            case .unavailable: "라이브 액티비티가 꺼져 있어요"
            }
        }

        var message: String {
            switch self {
            case .tooFar: "잠금화면 표시는 띄운 때부터 8시간까지만 살아 있어요."
            case .notUpcoming: "남은 시간을 셀 수 없어요."
            case .unavailable: "설정에서 켜면 잠금화면에 띄울 수 있어요."
            }
        }
    }

    func body(content: Content) -> some View {
        content
        .contextMenu {
            // **튜토리얼 중에는 비워둔다.** 이 메뉴는 시스템이 화면을 통째로 덮으며
            // 띄우는 것이라, 지금 따라가야 할 지시가 그 뒤로 사라진다. 마지막
            // '정리' 단계에서만 열린다 — 그 단계는 이 메뉴를 여는 것이 곧 과제다.
            // (항목이 하나도 없으면 시스템은 메뉴를 아예 띄우지 않는다.)
            if tutorial?.suppressesRowMenu != true { contextMenuItems }
        }
        .sheet(isPresented: $showsMemoEditor) {
            TodoDetailSheet(todo: todo)
        }
        // 띄우지 못한 이유는 반드시 말해준다 — 메뉴를 눌렀는데 아무 일도 안 일어나면
        // 사용자는 그걸 고장으로 여긴다.
        .alert(
            liveActivityBlock?.title ?? "",
            isPresented: Binding(
                get: { liveActivityBlock != nil },
                set: { if !$0 { liveActivityBlock = nil } }
            ),
            presenting: liveActivityBlock
        ) { _ in
            Button("확인", role: .cancel) {}
        } message: { block in
            Text(block.message)
        }
        // 반복 일정은 하나를 지우면 모든 날짜의 인스턴스가 같이 사라지므로,
        // 확인 문구에서 그걸 먼저 알려준다. 한 번짜리는 확인 없이 바로 지운다.
        .confirmationDialog(
            "모든 반복을 삭제할까요?",
            isPresented: $showsDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("삭제", role: .destructive) { onDelete?() }
            Button("취소", role: .cancel) {}
        } message: {
            Text("이 할 일은 반복돼요. 하루만 골라 삭제할 수는 없어요.")
        }
    }

    /// 꾹 눌러 나오는 메뉴의 알맹이. 셀 몸통 탭이 완료로 가면서, 나머지 조작은
    /// 전부 여기로 모였다 — 평소엔 안 보이니 행도 복잡해지지 않는다.
    @ViewBuilder
    private var contextMenuItems: some View {
        // 맨 위에 둔다 — 몸통 탭에서 밀려난 조작이라 제일 먼저 눈에 띄어야 한다.
        if onTap != nil {
            Button {
                onTap?()
            } label: {
                Label("수정", systemImage: "pencil")
            }
        }

        Button {
            showsMemoEditor = true
        } label: {
            Label(hasMemo ? "메모 보기" : "메모 추가", systemImage: "note.text")
        }

        Button {
            if !todo.isDDay { Analytics.log(.dDaySet) }
            todo.isDDay.toggle()
        } label: {
            Label(
                todo.isDDay ? "디데이 해제" : "디데이로 표시",
                systemImage: todo.isDDay ? "flag.slash" : "flag"
            )
        }

        // 시작 시각을 적어둔 할 일에만 나온다 — 셀 것이 없으면 메뉴에 자리도
        // 만들지 않는다. 여기서만 띄울 수 있는 건 앱이 자기 자신을 깨울 수
        // 없어서다(`TodoLiveActivityController` 참고): 꾹 누르는 이 순간이
        // 앱이 확실히 앞에 나와 있는 자리다.
        // 맥에는 라이브 액티비티가 없다(`TodoLiveActivityController.isSupported`).
        // 눌러도 아무 일이 안 일어나는 항목을 두느니 자리를 안 만든다.
        if TodoLiveActivityController.isSupported, todo.startTime != nil, !isDone {
            Button {
                Task { await toggleLiveActivity() }
            } label: {
                Label(
                    isShowingLiveActivity ? "잠금화면에서 내리기" : "잠금화면에 남은 시간 표시",
                    systemImage: isShowingLiveActivity ? "timer.circle.fill" : "timer"
                )
            }
        }

        // 다른 날에도 같은 일이 필요할 때. 복사해두고 달력을 넘겨 다니다가
        // 원하는 날에 붙여넣는다 — 날짜 고르기 시트로는 그날 다른 일정도
        // 날씨도 못 보고 고르게 된다.
        Button {
            clipboard.copy(todo)
        } label: {
            Label("복사", systemImage: "doc.on.doc")
        }

        // 만들 때 고른 캘린더를 나중에 바꿀 방법이 없었다 — 옮기려면 지우고
        // 다시 만드는 수밖에 없었다.
        if calendars.count > 1 {
            Menu {
                ForEach(calendars) { calendar in
                    Button {
                        todo.calendar = calendar
                    } label: {
                        if todo.calendar?.id == calendar.id {
                            Label(calendar.name, systemImage: "checkmark")
                        } else {
                            Text(calendar.name)
                        }
                    }
                }
            } label: {
                Label("캘린더 옮기기", systemImage: "square.stack.3d.up")
            }
        }

        if onDelete != nil {
            Button(role: .destructive) {
                if todo.repeatRule == .none {
                    onDelete?()
                } else {
                    showsDeleteConfirmation = true
                }
            } label: {
                Label("삭제", systemImage: "trash")
            }
        }
    }

    private var hasMemo: Bool { todo.memo != nil }

    /// 반복 인스턴스는 날짜별로 완료가 따로 기록된다.
    private var isDone: Bool {
        if let occurrenceDate { return todo.isCompleted(on: occurrenceDate) }
        return todo.isCompleted
    }

    private var isShowingLiveActivity: Bool {
        TodoLiveActivityController.shared.showingTodoID == todo.id.uuidString
    }

    /// 떠 있으면 내리고, 아니면 띄운다. 막히면 이유를 알린다.
    ///
    /// 어느 날의 인스턴스인지가 필요하다 — 반복 일정은 날마다 따로 서 있고,
    /// `startTime`은 시·분만 의미가 있어서(`TodoItem` 참고) 날짜와 합쳐야 실제
    /// 시각이 된다.
    private func toggleLiveActivity() async {
        let controller = TodoLiveActivityController.shared

        if isShowingLiveActivity {
            await controller.stop()
            return
        }

        guard let day = occurrenceDate ?? todo.date else {
            liveActivityBlock = .notUpcoming
            Analytics.log(.liveActivity(result: "not_upcoming"))
            return
        }

        // 성공만 세면 채택률이 낮을 때 "안 쓰는 것"인지 "조건에 걸리는 것"인지
        // 알 수 없다 — 결과를 그대로 실어 보낸다.
        switch await controller.start(todo: todo, on: Calendar.current.startOfDay(for: day)) {
        case .started:
            liveActivityBlock = nil
            Analytics.log(.liveActivity(result: "started"))
        case .tooFar:
            liveActivityBlock = .tooFar
            Analytics.log(.liveActivity(result: "too_far"))
        case .notUpcoming:
            liveActivityBlock = .notUpcoming
            Analytics.log(.liveActivity(result: "not_upcoming"))
        case .unavailable:
            liveActivityBlock = .unavailable
            Analytics.log(.liveActivity(result: "unavailable"))
        }
    }
}
