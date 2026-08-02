import SwiftUI
import SwiftData
import UIKit

/// 날짜를 선택했을 때 압축된 캘린더 아래에 인라인으로 붙는 리스트 + 입력창.
/// 모달이 아니라 같은 화면(CalendarScreen) 안에 있어서, 시트 리사이즈/키보드
/// 동기화 문제 자체가 없다 — 키보드 회피는 이 화면 하나만 신경 쓰면 된다.
/// 뒤로가기는 상단 월 헤더의 버튼이 맡으므로, 여긴 별도 헤더가 없다.
///
/// 날짜 이동은 위쪽 압축 캘린더가 주 단위 페이징으로 맡는다. 여기서 좌우 스와이프를
/// 쓰지 않는 건, 그게 셀의 스와이프 삭제와 방향이 같아 서로 먹히기 때문이다.
struct DayTodosContentView: View {
    let date: Date

    @Environment(\.modelContext) private var modelContext
    @Environment(TutorialManager.self) private var tutorialManager
    /// 기존 항목을 누르면 여기 채워지고, 하단 QuickAddView가 새로 만들기 대신
    /// 이 항목을 고치는 채팅형 입력창으로 바뀐다.
    @State private var editingTodo: TodoItem?

    var body: some View {
        // 날짜별 페이지를 좌우로 밀던 캐러셀은 걷어냈다. 그 스와이프가 셀의 좌우
        // 스와이프(삭제)와 방향이 같아 서로 먹혔고, 결국 삭제를 버튼/메뉴로 옮겨야
        // 했다. 날짜 이동은 위쪽 압축 캘린더가 주 단위 페이징으로 맡고, 여기서는
        // 리스트가 좌우 스와이프를 온전히 쓴다.
        //
        // 날짜를 identity로 준다 — 안 주면 날짜가 바뀔 때 SwiftUI가 같은 뷰를
        // 재사용하면서 date만 갈아끼우고, 그러면 반복 일정의 완료 상태가 바뀐
        // 것처럼 보여 TodoRow의 완료 스프링이 실행된다(체크를 누른 것처럼 깜빡였다).
        dayList(for: date)
            .id(date)
            // List가 키보드에 반응해 content inset을 또 조정하면 컴포즈 바의 반응과
            // 겹쳐 이중으로 움직인다. List는 키보드를 무시하고, 컴포즈 바만 따라가게 한다.
            .ignoresSafeArea(.keyboard, edges: .bottom)
            .safeAreaInset(edge: .bottom) {
                QuickAddView(date: date, editingTodo: $editingTodo)
            }
    }

    private func dayList(for pageDate: Date) -> some View {
        DayTodoList(
            date: pageDate,
            onSelect: { editingTodo = $0 },
            onDelete: { todos in
                for todo in todos { modelContext.delete(todo) }
                tutorialManager.userDidDeleteTodo()
            }
        )
    }
}

/// 하루치 할 일 목록 하나. 자기 날짜에 걸치는 항목만 @Query 결과에서 걸러 그린다.
private struct DayTodoList: View {
    let date: Date
    let onSelect: (TodoItem) -> Void
    let onDelete: ([TodoItem]) -> Void

    @Query(sort: [SortDescriptor(\TodoItem.startTime)]) private var allTodos: [TodoItem]
    /// 위쪽 격자와 같은 캘린더만 보여야 한다 — 격자엔 없는 일정이 아래 리스트에만
    /// 나오면 어느 쪽이 맞는지 알 수 없다.
    @AppStorage(CalendarSelection.storageKey) private var hiddenCalendarIDs = ""

    /// 반복 인스턴스는 저장소에 없고 규칙으로 계산되므로 #Predicate로는 못 거른다.
    /// 개인용 앱 규모에선 전체를 메모리에서 거르는 게 단순하고 충분히 빠르다 —
    /// 원본 기간과 겹치는 날은 물론, 반복이 그날에 걸치는 항목까지 함께 잡힌다.
    private var todosForDay: [TodoItem] {
        let hidden = CalendarSelection.hidden(from: hiddenCalendarIDs)
        return allTodos.filter {
            CalendarSelection.matches($0, hidden: hidden) && $0.occurs(on: date)
        }
    }

    /// 화면에 두 개 이상의 캘린더가 섞여 있을 때만 소속을 밝힌다.
    private var showsCalendarTag: Bool {
        Set(todosForDay.compactMap { $0.calendar?.id }).count > 1
    }

    var body: some View {
        List {
            if todosForDay.isEmpty {
                ContentUnavailableView(
                    "이날은 비어 있어요",
                    systemImage: "checkmark.circle",
                    description: Text("아래에 적으면 이날 일정으로 들어가요")
                )
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            } else {
                // 리스트에서 날짜를 넘기던 스와이프를 걷어냈으므로, 좌우 스와이프를
                // 원래 자리인 스와이프 삭제로 되돌린다.
                ForEach(Array(todosForDay.enumerated()), id: \.element.id) { index, todo in
                    TodoRow(
                        todo: todo,
                        occurrenceDate: date,
                        onTap: { onSelect(todo) },
                        onDelete: { onDelete([todo]) },
                        showsCalendarTag: showsCalendarTag,
                        isTutorialAnchor: index == 0
                    )
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 6, leading: Metrics.spacingMD, bottom: 6, trailing: Metrics.spacingMD))
                    .tutorialAnchor(index == 0 ? .firstTodoRow : nil)
                }
                .onDelete { offsets in
                    onDelete(offsets.map { todosForDay[$0] })
                }
            }
        }
        .scrollContentBackground(.hidden)
        // List가 자체 스크롤/탭 제스처를 먼저 가져가버려서 .background에 올린
        // onTapGesture는 아예 안 불렸다. simultaneousGesture로 List의 제스처를
        // 막지 않으면서 같이 받는다. 스크롤 시작 시에도 바로 내려가게 처리.
        .scrollDismissesKeyboard(.immediately)
        .simultaneousGesture(
            TapGesture().onEnded {
                UIApplication.shared.sendAction(
                    #selector(UIResponder.resignFirstResponder),
                    to: nil, from: nil, for: nil
                )
            }
        )
    }
}
