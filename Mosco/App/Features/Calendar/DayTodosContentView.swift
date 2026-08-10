import SwiftUI
import SwiftData
import UIKit

/// 하루치 할 일 페이지. 달력에서 날짜를 누르면 **밀려 들어온다**.
///
/// 예전엔 같은 화면 안에서 달력이 주간 스트립으로 접히고 그 아래에 인라인으로
/// 붙었다. 한 화면이 두 가지 모습을 오가는 구조라, 지금 보고 있는 게 달인지
/// 하루인지 헷갈렸고 되돌아가는 길도 직접 만든 화살표 하나뿐이었다. 페이지를
/// 밀어 넣으면 앞뒤 관계가 분명해지고 뒤로 가기는 시스템이 맡는다.
///
/// 여기서 좌우 스와이프로 날짜를 넘기지 않는 건, 그게 셀의 스와이프 삭제와 방향이
/// 같아 서로 먹히기 때문이다. 날짜를 바꾸려면 뒤로 나가 달력에서 고른다.
struct DayTodosContentView: View {
    let date: Date

    @Environment(\.modelContext) private var modelContext
    @Environment(TodoClipboard.self) private var clipboard
    @Environment(WeatherStore.self) private var weatherStore
    /// 기존 항목을 누르면 여기 채워지고, 하단 QuickAddView가 새로 만들기 대신
    /// 이 항목을 고치는 채팅형 입력창으로 바뀐다.
    @State private var editingTodo: TodoItem?
    /// 끌어서 순서를 바꾸는 동안만 켜진다. 할 일 목록과 같은 `sortIndex`를 쓰므로,
    /// 여기서 정한 순서가 그쪽에도 그대로 간다.
    @State private var isEditing = false

    private let calendar = Calendar.current

    var body: some View {
        // 날짜를 identity로 준다 — 안 주면 날짜가 바뀔 때 SwiftUI가 같은 뷰를
        // 재사용하면서 date만 갈아끼우고, 그러면 반복 일정의 완료 상태가 바뀐
        // 것처럼 보여 TodoRow의 완료 스프링이 실행된다(체크를 누른 것처럼 깜빡였다).
        DayTodoList(
            date: date,
            isEditing: isEditing,
            onSelect: { editingTodo = $0 },
            onDelete: { todos in
                for todo in todos { modelContext.delete(todo) }
                Analytics.log(.taskDeleted(source: "calendar_day_list", count: todos.count))
            }
        )
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
        .background(MoscoPalette.canvas.ignoresSafeArea())
        // 밀려 들어온 페이지라 시스템 내비게이션 바를 그대로 쓴다 — 뒤로 가기
        // 버튼과 가장자리 스와이프를 공짜로 얻는다. 직접 만든 헤더로는 그 두 개를
        // 다시 만들어야 하고, 스와이프는 흉내 내기도 어렵다.
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) { titleView }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { isEditing.toggle() }
                } label: {
                    Text(isEditing ? "완료" : "순서")
                        .font(.moscoCaption().weight(.semibold))
                        .foregroundStyle(MoscoPalette.accent)
                }
            }
        }
    }

    /// 날짜와 그날 날씨를 한 줄로. 날씨는 예전에 주간 스트립의 날짜 칸에 붙어
    /// 있었는데, 그 스트립이 사라지면서 갈 곳을 잃었다 — 하루를 보는 화면이야말로
    /// 그날 날씨가 필요한 자리다.
    private var titleView: some View {
        HStack(spacing: 6) {
            Text(date.koreanMonthDayWeekday)
                .font(.moscoBody().weight(.semibold))
                .foregroundStyle(MoscoPalette.textPrimary)

            if let weather = weatherStore.weather(for: date) {
                Image(systemName: weather.symbolName)
                    .font(.system(size: 12))
                    .foregroundStyle(MoscoPalette.textSecondary)
                Text("\(weather.highCelsius)°/\(weather.lowCelsius)°")
                    .font(.moscoCaption())
                    .foregroundStyle(MoscoPalette.textSecondary)
            }
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

}

/// 하루치 할 일 목록 하나. 자기 날짜에 걸치는 항목만 @Query 결과에서 걸러 그린다.
private struct DayTodoList: View {
    let date: Date
    let isEditing: Bool
    let onSelect: (TodoItem) -> Void
    let onDelete: ([TodoItem]) -> Void

    @Query private var allTodos: [TodoItem]
    /// 위쪽 격자와 같은 캘린더만 보여야 한다 — 격자엔 없는 일정이 아래 리스트에만
    /// 나오면 어느 쪽이 맞는지 알 수 없다.
    @AppStorage(CalendarSelection.storageKey) private var hiddenCalendarIDs = ""

    /// 반복 인스턴스는 저장소에 없고 규칙으로 계산되므로 #Predicate로는 못 거른다.
    /// 개인용 앱 규모에선 전체를 메모리에서 거르는 게 단순하고 충분히 빠르다 —
    /// 원본 기간과 겹치는 날은 물론, 반복이 그날에 걸치는 항목까지 함께 잡힌다.
    ///
    /// **정렬은 사용자가 정한 순서(`sortIndex`)가 먼저다.** 예전엔 시작 시각으로만
    /// 세워서, 할 일 목록에서 끌어 옮긴 순서가 이 화면에 오면 없던 일이 됐다 —
    /// 같은 할 일이 화면마다 다른 자리에 서 있으면 어느 쪽이 맞는지 알 수 없다.
    /// 아직 한 번도 안 옮긴 항목들은 번호가 모두 같아서, 그때는 시각순이 그대로
    /// 유지된다(종전 동작).
    private var todosForDay: [TodoItem] {
        let hidden = CalendarSelection.hidden(from: hiddenCalendarIDs)
        return allTodos
            .filter { CalendarSelection.matches($0, hidden: hidden) && $0.occurs(on: date) }
            .sorted { lhs, rhs in
                if lhs.sortIndex != rhs.sortIndex { return lhs.sortIndex < rhs.sortIndex }
                if lhs.sortableMinutes != rhs.sortableMinutes {
                    return lhs.sortableMinutes < rhs.sortableMinutes
                }
                return lhs.createdAt < rhs.createdAt
            }
    }

    /// 끌어서 놓은 결과를 0부터 다시 매긴다 — 할 일 목록의 `move`와 같은 규칙이라,
    /// 어느 화면에서 옮기든 같은 줄 번호가 된다.
    private func move(from source: IndexSet, to destination: Int) {
        var reordered = todosForDay
        reordered.move(fromOffsets: source, toOffset: destination)
        for (index, todo) in reordered.enumerated() {
            todo.sortIndex = index
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
                .onMove(perform: move)
                .onDelete { offsets in
                    onDelete(offsets.map { todosForDay[$0] })
                }
            }
        }
        .environment(\.editMode, .constant(isEditing ? .active : .inactive))
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
