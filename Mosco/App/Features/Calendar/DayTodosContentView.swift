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
    @Environment(TodoClipboard.self) private var clipboard
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
            // 붙여넣기 줄과 컴포즈 바를 **각각 따로** 붙인다. 둘을 VStack 하나로
            // 묶어 넘겼더니 그려지기는 해도 탭이 하나도 안 들어왔다 —
            // safeAreaInset은 넘긴 뷰를 그대로 한 덩어리로 앉히는데, 그 덩어리가
            // 커지면 히트 영역이 따라오지 않는다. 먼저 붙인 쪽이 안쪽(위)에 온다.
            .safeAreaInset(edge: .bottom, spacing: Metrics.spacingSM) { pasteBar }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                QuickAddView(date: date, editingTodo: $editingTodo)
            }
    }

    /// 복사해둔 할 일이 있을 때만 나타나는 줄. 이 화면이 "지금 어느 날짜를 보고
    /// 있는가"를 아는 유일한 곳이라, 붙여넣기가 여기 산다 — 달력을 넘겨 다니다가
    /// 원하는 날에서 한 번 누르면 끝난다.
    ///
    /// 비어 있으면 자리 자체가 없다. 늘 보이는 버튼으로 두면 평소엔 쓸 일 없는
    /// 것이 입력창 위 한 줄을 계속 차지한다.
    @ViewBuilder
    private var pasteBar: some View {
        if let copied = clipboard.item {
            // 두 버튼은 **형제**여야 한다. 지우기를 붙여넣기 버튼의 label 안에
            // 넣었더니 바깥 버튼이 안쪽 버튼에 탭을 다 빼앗겨 아무 데를 눌러도
            // 붙여넣기가 안 됐다 — 버튼 안에 버튼을 넣지 않는다.
            HStack(spacing: 6) {
                Button {
                    withAnimation(.easeOut(duration: 0.2)) {
                        clipboard.paste(on: date, in: modelContext)
                    }
                    Analytics.log(.taskDuplicated(source: "calendar_day_list", method: "paste"))
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "doc.on.clipboard")
                            .font(.system(size: 12, weight: .semibold))
                        Text("‘\(copied.title)’ 붙여넣기")
                            .font(.moscoCaption().weight(.semibold))
                            .lineLimit(1)
                        Spacer(minLength: 0)
                    }
                    .foregroundStyle(MoscoPalette.accent)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                // 복사해둔 걸 물릴 방법이 없으면, 안 쓸 항목 하나가 이 줄을
                // 계속 차지한 채 남는다.
                Button {
                    withAnimation(.easeOut(duration: 0.2)) { clipboard.clear() }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 15))
                        .foregroundStyle(MoscoPalette.textSecondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .moscoGlass(in: Capsule())
            .padding(.horizontal, Metrics.spacingMD)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    private func dayList(for pageDate: Date) -> some View {
        DayTodoList(
            date: pageDate,
            onSelect: { editingTodo = $0 },
            onDelete: { todos in
                for todo in todos { modelContext.delete(todo) }
                Analytics.log(.taskDeleted(source: "calendar_day_list", count: todos.count))
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
                    description: Text("아래에 적으면 이날 할 일이 돼요")
                )
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            } else {
                // 리스트에서 날짜를 넘기던 스와이프를 걷어냈으므로, 좌우 스와이프를
                // 원래 자리인 스와이프 삭제로 되돌린다.
                ForEach(todosForDay) { todo in
                    TodoRow(
                        todo: todo,
                        occurrenceDate: date,
                        onTap: { onSelect(todo) },
                        onDelete: { onDelete([todo]) },
                        showsCalendarTag: showsCalendarTag,
                        analyticsSource: "calendar_day_list"
                    )
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: Metrics.listRowGap, leading: Metrics.spacingMD, bottom: Metrics.listRowGap, trailing: Metrics.spacingMD))
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
