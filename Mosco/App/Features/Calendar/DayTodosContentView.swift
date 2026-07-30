import SwiftUI
import SwiftData
import UIKit

/// 날짜를 선택했을 때 압축된 캘린더 아래에 인라인으로 붙는 리스트 + 입력창.
/// 모달이 아니라 같은 화면(CalendarScreen) 안에 있어서, 시트 리사이즈/키보드
/// 동기화 문제 자체가 없다 — 키보드 회피는 이 화면 하나만 신경 쓰면 된다.
/// 뒤로가기는 상단 월 헤더의 버튼이 맡으므로, 여기엔 별도 헤더가 없다.
struct DayTodosContentView: View {
    let date: Date

    @Query(sort: [SortDescriptor(\TodoItem.startTime)]) private var allTodos: [TodoItem]
    @Environment(\.modelContext) private var modelContext
    /// 기존 항목을 누르면 여기 채워지고, 하단 QuickAddView가 새로 만들기 대신
    /// 이 항목을 고치는 채팅형 입력창으로 바뀐다.
    @State private var editingTodo: TodoItem?

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
                ForEach(todosForDay) { todo in
                    TodoRow(todo: todo, occurrenceDate: date, onTap: { editingTodo = todo })
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 6, leading: Metrics.spacingMD, bottom: 6, trailing: Metrics.spacingMD))
                }
                .onDelete(perform: delete)
            }
        }
        .scrollContentBackground(.hidden)
        // List가 키보드에 반응해 content inset을 또 조정하면 컴포즈 바의 반응과
        // 겹쳐 이중으로 움직인다. List는 키보드를 무시하고, 컴포즈 바만 따라가게 한다.
        .ignoresSafeArea(.keyboard, edges: .bottom)
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
        .safeAreaInset(edge: .bottom) {
            QuickAddView(date: date, editingTodo: $editingTodo)
        }
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(todosForDay[index])
        }
    }
}
