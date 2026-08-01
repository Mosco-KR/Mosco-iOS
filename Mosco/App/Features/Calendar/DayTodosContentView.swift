import SwiftUI
import SwiftData
import UIKit

/// 날짜를 선택했을 때 압축된 캘린더 아래에 인라인으로 붙는 리스트 + 입력창.
/// 모달이 아니라 같은 화면(CalendarScreen) 안에 있어서, 시트 리사이즈/키보드
/// 동기화 문제 자체가 없다 — 키보드 회피는 이 화면 하나만 신경 쓰면 된다.
/// 뒤로가기는 상단 월 헤더의 버튼이 맡으므로, 여긴 별도 헤더가 없다.
///
/// 좌우로 밀면 하루씩 이동한다. 어제·오늘·내일 세 페이지를 항상 나란히 깔아두고
/// 드래그만큼 같이 움직이다 손을 떼면 한 페이지로 스냅하는데(MonthCarouselView와
/// 같은 방식), 그래야 미는 동안 옆 날짜가 실제로 따라 들어와서 빈 공간이 안 생긴다.
/// 입력창은 캐러셀 바깥에 한 번만 둔다 — 페이지마다 두면 밀 때 같이 흘러가버린다.
struct DayTodosContentView: View {
    let date: Date
    /// 스와이프로 날짜가 바뀌면 호출된다(+1 = 다음 날). 실제 선택 상태는
    /// CalendarScreen이 갖고 있어서, 압축된 주간 스트립의 표시도 같이 따라간다.
    var onDateChange: ((Int) -> Void)? = nil

    @Environment(\.modelContext) private var modelContext
    @Environment(TutorialManager.self) private var tutorialManager
    /// 기존 항목을 누르면 여기 채워지고, 하단 QuickAddView가 새로 만들기 대신
    /// 이 항목을 고치는 채팅형 입력창으로 바뀐다.
    @State private var editingTodo: TodoItem?
    @State private var dragTranslation: CGFloat = 0

    private let calendar = Calendar.current

    var body: some View {
        VStack(spacing: 0) {
            GeometryReader { geometry in
                let width = geometry.size.width

                // 각 페이지에 그 날짜를 identity로 준다 — 안 주면 날짜가 바뀔 때
                // SwiftUI가 같은 자리의 뷰를 재사용하면서 date만 갈아끼우고, 그러면
                // 반복 일정의 완료 상태(occurrenceDate 기준)가 바뀐 것처럼 보여
                // TodoRow의 완료 스프링이 실행된다 — 체크를 누른 것처럼 깜빡였다.
                // 날짜를 id로 주면 페이지가 한 칸 밀릴 때 새로 그리는 대신 자리만
                // 옮겨서, 완료 표시가 처음부터 제 상태로 그려진다.
                HStack(spacing: 0) {
                    dayList(for: adjacentDate(-1)).frame(width: width).id(adjacentDate(-1))
                    dayList(for: date).frame(width: width).id(date)
                    dayList(for: adjacentDate(1)).frame(width: width).id(adjacentDate(1))
                }
                .offset(x: -width + dragTranslation)
                .background(
                    HorizontalPagingGesture(
                        // 수정 중엔 입력창이 그 항목에 묶여 있어서, 날짜가 바뀌면
                        // 편집 대상과 보이는 목록이 어긋난다 — 그동안은 잠근다.
                        isEnabled: editingTodo == nil,
                        onChanged: { dragTranslation = $0 },
                        onEnded: { dx in
                            let threshold = width * 0.22
                            if dx < -threshold {
                                commit(direction: 1, width: width)
                            } else if dx > threshold {
                                commit(direction: -1, width: width)
                            } else {
                                withAnimation(.interactiveSpring(response: 0.25, dampingFraction: 0.9)) {
                                    dragTranslation = 0
                                }
                            }
                        }
                    )
                )
            }
        }
        // List가 키보드에 반응해 content inset을 또 조정하면 컴포즈 바의 반응과
        // 겹쳐 이중으로 움직인다. List는 키보드를 무시하고, 컴포즈 바만 따라가게 한다.
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .safeAreaInset(edge: .bottom) {
            QuickAddView(date: date, editingTodo: $editingTodo)
        }
    }

    /// 하루치 목록 한 페이지. @Query를 쓰는 대신 부모가 가진 컨텍스트에서 그때그때
    /// 읽는 편이 세 페이지를 동시에 두기에 단순하다 — DayTodoList가 자기 날짜만
    /// @Query로 거른다.
    private func dayList(for pageDate: Date) -> some View {
        DayTodoList(
            date: pageDate,
            onSelect: { todo in
                // 옆 페이지(어제/내일)를 눌러 수정에 들어가면 입력창의 날짜와
                // 목록이 어긋나므로, 지금 보고 있는 날짜에서만 수정을 받는다.
                guard calendar.isDate(pageDate, inSameDayAs: date) else { return }
                editingTodo = todo
            },
            onDelete: { todos in
                for todo in todos { modelContext.delete(todo) }
                tutorialManager.userDidDeleteTodo()
            }
        )
    }

    private func adjacentDate(_ delta: Int) -> Date {
        calendar.date(byAdding: .day, value: delta, to: date) ?? date
    }

    /// 한 페이지 분량으로 딱 스냅한 뒤 날짜를 바꾸고 오프셋을 원위치로 —
    /// 이음매 없이 이어지게 한다(MonthCarouselView와 같은 방식).
    private func commit(direction: Int, width: CGFloat) {
        withAnimation(.interactiveSpring(response: 0.28, dampingFraction: 0.92)) {
            dragTranslation = direction > 0 ? -width : width
        } completion: {
            // 오프셋 되돌리기와 날짜 교체는 반드시 애니메이션 없이, 한 트랜잭션에서
            // 같이 일어나야 한다. 슬라이드가 끝난 시점의 화면과 날짜를 바꾼 뒤의
            // 화면은 원래 똑같아서 사용자는 아무 변화도 못 느껴야 하는데,
            // CalendarScreen이 selectedDate에 스프링 애니메이션을 걸어둔 탓에 이
            // 교체가 애니메이션을 타면서 이전 날짜 내용이 한 번 비쳐 깜빡였다.
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                dragTranslation = 0
                onDateChange?(direction)
            }
        }
    }
}

/// 하루치 할 일 목록 하나. 자기 날짜에 걸치는 항목만 @Query 결과에서 걸러 그린다.
private struct DayTodoList: View {
    let date: Date
    let onSelect: (TodoItem) -> Void
    let onDelete: ([TodoItem]) -> Void

    @Query(sort: [SortDescriptor(\TodoItem.startTime)]) private var allTodos: [TodoItem]

    /// 반복 인스턴스는 저장소에 없고 규칙으로 계산되므로 #Predicate로는 못 거른다.
    /// 개인용 앱 규모에선 전체를 메모리에서 거르는 게 단순하고 충분히 빠르다 —
    /// 원본 기간과 겹치는 날은 물론, 반복이 그날에 걸치는 항목까지 함께 잡힌다.
    private var todosForDay: [TodoItem] {
        allTodos.filter { $0.occurs(on: date) }
    }

    var body: some View {
        List {
            if todosForDay.isEmpty {
                ContentUnavailableView(
                    "이 날은 할 일이 없어요",
                    systemImage: "checkmark.circle",
                    description: Text("아래에서 바로 추가해보세요")
                )
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            } else {
                // 스와이프 삭제는 뺐다 — 리스트를 좌우로 밀어 날짜를 넘기는
                // 동작과 방향이 같아 서로 먹혔다. 삭제는 각 행의 메뉴에서 한다.
                ForEach(todosForDay) { todo in
                    TodoRow(
                        todo: todo,
                        occurrenceDate: date,
                        onTap: { onSelect(todo) },
                        onDelete: { onDelete([todo]) }
                    )
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 6, leading: Metrics.spacingMD, bottom: 6, trailing: Metrics.spacingMD))
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
