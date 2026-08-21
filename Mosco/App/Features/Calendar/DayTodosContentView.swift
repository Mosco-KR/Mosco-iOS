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
/// **날짜는 맨 위 주간 스트립에서 바꾼다.** 본문에는 좌우 스와이프를 걸지 않는다 —
/// 그건 셀의 스와이프 삭제와 방향이 같아 서로 먹힌다. 스트립 한 줄에만 걸어두면
/// 두 손짓이 자리로 구분된다.
struct DayTodosContentView: View {
    /// 지금 보고 있는 날짜. 달력에서 눌러 들어온 날짜로 시작한다. 뒤에 남은
    /// 달력은 들어온 자리를 그대로 지키므로(`CalendarScreen.select`) 여기서
    /// 옮겨 다닌 결과를 밖으로 올리지 않는다.
    @State private var shownDate: Date
    /// 스트립이 보여주는 주의 시작일. 날짜를 고르면 그 날이 든 주로 따라간다.
    @State private var visibleWeekStart: Date

    init(date: Date) {
        _shownDate = State(initialValue: date)
        _visibleWeekStart = State(initialValue: WeekWindow.normalized(date))
    }

    @Environment(\.modelContext) private var modelContext
    @Environment(TodoClipboard.self) private var clipboard
    @Environment(WeatherStore.self) private var weatherStore
    @Environment(TutorialCoordinator.self) private var tutorial: TutorialCoordinator?
    /// 기존 항목을 누르면 여기 채워지고, 하단 QuickAddView가 새로 만들기 대신
    /// 이 항목을 고치는 채팅형 입력창으로 바뀐다.
    @State private var editingTodo: TodoItem?
    /// 끌어서 순서를 바꾸는 동안만 켜진다. 할 일 목록과 같은 `sortIndex`를 쓰므로,
    /// 여기서 정한 순서가 그쪽에도 그대로 간다.
    @State private var isEditing = false
    /// 툴바가 모양에 따라 달라지므로 상위 뷰도 이 값을 안다.
    @AppStorage(DayViewMode.storageKey) private var viewModeRaw = DayViewMode.list.rawValue

    private let calendar = Calendar.current

    var body: some View {
        // 날짜를 identity로 준다 — 안 주면 날짜가 바뀔 때 SwiftUI가 같은 뷰를
        // 재사용하면서 date만 갈아끼우고, 그러면 반복 일정의 완료 상태가 바뀐
        // 것처럼 보여 TodoRow의 완료 스프링이 실행된다(체크를 누른 것처럼 깜빡였다).
        DayTodoList(
            date: shownDate,
            isEditing: isEditing,
            onSelect: { editingTodo = $0 },
            onDelete: { todos in
                // 지우기 **전에** 알린다 — 지운 뒤에는 id를 읽을 수 없다.
                tutorial?.didDelete(ids: todos.map(\.id))
                for todo in todos { modelContext.delete(todo) }
            }
        )
        .id(shownDate)
        // List가 키보드에 반응해 content inset을 또 조정하면 컴포즈 바의 반응과
        // 겹쳐 이중으로 움직인다. List는 키보드를 무시하고, 컴포즈 바만 따라가게 한다.
        .ignoresSafeArea(.keyboard, edges: .bottom)
        // 붙여넣기 줄과 컴포즈 바를 **각각 따로** 붙인다. 둘을 VStack 하나로
        // 묶어 넘겼더니 그려지기는 해도 탭이 하나도 안 들어왔다 —
        // safeAreaInset은 넘긴 뷰를 그대로 한 덩어리로 앉히는데, 그 덩어리가
        // 커지면 히트 영역이 따라오지 않는다. 먼저 붙인 쪽이 안쪽(위)에 온다.
        .safeAreaInset(edge: .bottom, spacing: Metrics.spacingSM) { pasteBar }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            QuickAddView(date: shownDate, editingTodo: $editingTodo, analyticsSource: "calendar_day")
        }
        .safeAreaInset(edge: .top, spacing: 0) { weekStrip }
        .background(MoscoPalette.canvas.ignoresSafeArea())
        // 밀려 들어온 페이지라 시스템 내비게이션 바를 그대로 쓴다 — 뒤로 가기
        // 버튼과 가장자리 스와이프를 공짜로 얻는다. 직접 만든 헤더로는 그 두 개를
        // 다시 만들어야 하고, 스와이프는 흉내 내기도 어렵다.
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbarContent }
    }

    /// 할 일 화면의 편집 버튼과 같은 이름·같은 모양이다. 하는 일도 같다 —
    /// 끌어서 순서를 바꾸고 스와이프로 지우는 모드로 들어간다.
    ///
    /// **시스템이 씌우는 배경을 끄는 게 핵심이다.** iOS 26의 툴바는 항목마다 유리
    /// 배경을 알아서 깔아주는데, 이 버튼은 자기 캡슐을 이미 들고 있어서 테두리가
    /// 두 겹으로 겹쳐 보였다 — 같은 버튼이 할 일 화면에서는 한 겹, 여기서는 두
    /// 겹이라 두 화면을 오갈 때 크기가 달라 보였다.
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .principal) { titleView }
        ToolbarItem(placement: .topBarTrailing) { viewModeButton }
        // 시간표에서는 순서를 끌어 옮길 수 없다 — 거기서 끄는 것은 순서가 아니라
        // 시각이라 뜻이 달라진다. 그래서 편집 버튼도 목록에서만 보인다.
        if DayViewMode.from(viewModeRaw) == .list {
            ToolbarItem(placement: .topBarTrailing) { editButton }
        }
    }

    /// 목록 ↔ 시간표. 편집 버튼과 같은 컴포넌트를 써서 두 버튼이 한 벌로 보이게 한다.
    /// **지금 무엇으로 보고 있는지가 아니라 누르면 무엇이 되는지**를 보여준다 —
    /// 토글은 결과를 미리 알려주는 편이 덜 헷갈린다.
    private var viewModeButton: some View {
        let current = DayViewMode.from(viewModeRaw)
        let next: DayViewMode = current == .list ? .timeline : .list
        return HeaderGlassButton(
            systemImage: next.symbol,
            accessibilityName: "\(next.label)으로 보기",
            drawsBackground: false
        ) {
            withAnimation(.easeInOut(duration: 0.2)) {
                viewModeRaw = next.rawValue
                // 시간표로 가면 편집 모드는 의미가 없으므로 내린다.
                if next == .timeline { isEditing = false }
            }
        }
        .accessibilityHint("하루치를 \(next.label) 모양으로 봅니다")
    }

    /// 배경은 툴바가 그린다(`drawsBackground: false`). 자체 캡슐을 들고 들어가면
    /// 그 위에 시스템 배경이 한 겹 더 깔려, 같은 버튼이 할 일 화면에서는 한 겹,
    /// 여기서는 두 겹이 됐다.
    private var editButton: some View {
        HeaderGlassButton(
            // 상태가 바뀌면 아이콘도 바뀐다 — 글자를 뺐으니 모양이 유일한 단서다.
            systemImage: isEditing ? "checkmark" : "arrow.up.arrow.down",
            accessibilityName: isEditing ? "편집 마치기" : "순서 편집",
            drawsBackground: false
        ) {
            withAnimation(.easeInOut(duration: 0.2)) { isEditing.toggle() }
        }
    }

    /// 페이지 머리에 붙는 주간 스트립. 좌우로 밀면 주가 넘어가고, 날짜를 누르면
    /// 본문이 그날로 바뀐다 — 하루 건너뛰려고 달력까지 나갔다 오지 않아도 된다.
    ///
    /// 스트립은 떠 있는 요소가 아니므로 불투명한 캔버스 위에 그리고 아래에
    /// 경계선 한 줄만 둔다(글라스는 쓰지 않는다).
    private var weekStrip: some View {
        GeometryReader { proxy in
            WeekPagerView(
                width: proxy.size.width,
                today: calendar.startOfDay(for: Date()),
                selectedDate: shownDate,
                weatherSymbol: { weatherStore.weather(for: $0)?.symbolName },
                visibleWeekStart: $visibleWeekStart,
                onSelect: select
            )
        }
        .frame(height: WeekStripView.height)
        .background(MoscoPalette.canvas)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(MoscoPalette.border)
                .frame(height: 0.5)
        }
    }

    /// 스트립에서 다른 날을 고른다.
    private func select(_ day: Date) {
        let start = calendar.startOfDay(for: day)
        guard start != shownDate else { return }
        // 고치던 항목은 그 날의 것이다 — 날짜가 바뀌면 입력창을 새로 만들기로
        // 되돌린다. 안 그러면 다른 날 화면에서 어제 항목을 고치고 있게 된다.
        editingTodo = nil
        shownDate = start
        // 달 경계를 걸친 주에서 옆 달 날짜를 눌렀을 때, 스트립이 그대로 있어야
        // 방금 누른 칸이 눈앞에 남는다. 같은 주면 아무 일도 안 일어난다.
        visibleWeekStart = WeekWindow.normalized(start)
    }

    /// 날짜와 그날 날씨를 한 줄로. 날씨는 예전에 주간 스트립의 날짜 칸에 붙어
    /// 있었는데, 그 스트립이 사라지면서 갈 곳을 잃었다 — 하루를 보는 화면이야말로
    /// 그날 날씨가 필요한 자리다.
    private var titleView: some View {
        HStack(spacing: 6) {
            Text(shownDate.koreanMonthDayWeekday)
                .font(.moscoBody().weight(.semibold))
                .foregroundStyle(MoscoPalette.textPrimary)

            if let weather = weatherStore.weather(for: shownDate) {
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
    ///
    /// 복사한 것이 여럿이면(최대 셋) 칩을 나란히 놓고 **누른 것만** 붙여넣는다.
    /// 한 번에 다 붙이는 버튼은 두지 않았다 — 셋을 복사해뒀다는 건 서로 다른 날에
    /// 흩뿌리려는 뜻이라, 한 날에 몰아 넣는 건 대개 실수다.
    @ViewBuilder
    private var pasteBar: some View {
        if !clipboard.items.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(clipboard.items) { copied in
                        pasteChip(copied)
                    }
                }
                .padding(.horizontal, Metrics.spacingMD)
            }
            // 캡슐이 스크롤 뷰 가장자리에서 잘리지 않게.
            .scrollClipDisabled()
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    /// 복사해둔 항목 하나. 두 버튼은 **형제**여야 한다 — 지우기를 붙여넣기 버튼의
    /// label 안에 넣었더니 바깥 버튼이 안쪽 버튼에 탭을 다 빼앗겨 아무 데를 눌러도
    /// 붙여넣기가 안 됐다. 버튼 안에 버튼을 넣지 않는다.
    private func pasteChip(_ copied: TodoClipboard.Snapshot) -> some View {
        HStack(spacing: 6) {
            Button {
                withAnimation(.easeOut(duration: 0.2)) {
                    clipboard.paste(copied, on: shownDate, in: modelContext)
                }
                Analytics.log(.todoDuplicated)
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "doc.on.clipboard")
                        .font(.system(size: 12, weight: .semibold))
                    Text(copied.title)
                        .font(.moscoCaption().weight(.semibold))
                        .lineLimit(1)
                }
                .foregroundStyle(MoscoPalette.accent)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // 복사해둔 걸 물릴 방법이 없으면, 안 쓸 항목이 이 줄을 계속 차지한 채 남는다.
            Button {
                withAnimation(.easeOut(duration: 0.2)) { clipboard.remove(copied) }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 15))
                    .foregroundStyle(MoscoPalette.textSecondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        // 제목이 길어도 칩 하나가 화면을 다 먹지 않게 — 넘치면 말줄임으로 끊긴다.
        .frame(maxWidth: 220)
        .moscoGlass(in: Capsule())
        .clipShape(Capsule())
    }

}

/// 하루치 할 일 목록 하나. 자기 날짜에 걸치는 항목만 @Query 결과에서 걸러 그린다.
private struct DayTodoList: View {
    let date: Date
    let isEditing: Bool
    let onSelect: (TodoItem) -> Void
    let onDelete: ([TodoItem]) -> Void

    @Query private var allTodos: [TodoItem]
    @Environment(TutorialCoordinator.self) private var tutorial: TutorialCoordinator?
    /// 위쪽 격자와 같은 캘린더만 보여야 한다 — 격자엔 없는 일정이 아래 리스트에만
    /// 나오면 어느 쪽이 맞는지 알 수 없다.
    @AppStorage(CalendarSelection.storageKey) private var hiddenCalendarIDs = ""
    /// 마지막으로 고른 모양. 오늘 할 일 탭과 **같은 값을 공유한다**.
    @AppStorage(DayViewMode.storageKey) private var viewModeRaw = DayViewMode.list.rawValue

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
        // **비었을 때는 List를 쓰지 않는다.** List 안에 넣으면 안내가 첫 행 자리,
        // 즉 화면 맨 위에 붙어서 그 아래로 빈 공간이 길게 남는다 — 아무것도 없다는
        // 말을 하면서 화면의 대부분을 비워두는 셈이다. 리스트를 통째로 걷어내면
        // ContentUnavailableView가 제 프레임 한가운데에 선다.
        if todosForDay.isEmpty {
            emptyState
        } else if DayViewMode.from(viewModeRaw) == .timeline {
            // 편집(순서 바꾸기)은 목록에서만 한다 — 시간축에서 끌어 옮기면
            // 그건 순서가 아니라 시각을 바꾸는 동작이라 뜻이 달라진다.
            DayTimelineView(
                todos: todosForDay,
                showsCalendarTag: showsCalendarTag,
                onSelect: onSelect,
                onDelete: { onDelete([$0]) },
                date: date
            )
        } else {
            list
        }
    }

    /// 설명은 붙이지 않는다 — 바로 아래에 입력창이 커서까지 깜빡이며 놓여 있어서,
    /// "아래에 적으면 이날 할 일이 돼요"는 눈에 보이는 것을 한 번 더 말하는 셈이다.
    private var emptyState: some View {
        ContentUnavailableView(
            "이날은 비어 있어요",
            systemImage: "checkmark.circle"
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // 목록이 없어도 빈 자리를 눌러 키보드를 내릴 수 있어야 한다 — 리스트가
        // 하던 일을 여기서도 그대로 한다.
        .contentShape(Rectangle())
        .onTapGesture { dismissKeyboard() }
    }

    private var list: some View {
        List {
            // 날짜를 넘기는 스와이프는 맨 위 주간 스트립에만 있다. 줄에는
            // 좌우 손짓이 없다 — 삭제는 꾹 눌러 나오는 메뉴가 맡는다.
            ForEach(todosForDay) { todo in
                TodoRow(
                    todo: todo,
                    occurrenceDate: date,
                    onTap: { onSelect(todo) },
                    onDelete: { onDelete([todo]) },
                    showsCalendarTag: showsCalendarTag
                )
                .tutorialTarget(.dayRow(todo.id))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: Metrics.listRowGap, leading: Metrics.spacingMD, bottom: Metrics.listRowGap, trailing: Metrics.spacingMD))
            }
            .onMove(perform: move)
            .onDelete { offsets in
                onDelete(offsets.map { todosForDay[$0] })
            }
        }
        .environment(\.editMode, .constant(isEditing ? .active : .inactive))
        // 안내가 겨누는 줄이 손가락에 밀려 화면 밖으로 나가지 않게.
        .scrollDisabled(tutorial?.locksScroll == true)
        .scrollContentBackground(.hidden)
        // List가 자체 스크롤/탭 제스처를 먼저 가져가버려서 .background에 올린
        // onTapGesture는 아예 안 불렸다. simultaneousGesture로 List의 제스처를
        // 막지 않으면서 같이 받는다. 스크롤 시작 시에도 바로 내려가게 처리.
        .scrollDismissesKeyboard(.immediately)
        .simultaneousGesture(TapGesture().onEnded { dismissKeyboard() })
    }

    private func dismissKeyboard() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil, from: nil, for: nil
        )
    }
}
