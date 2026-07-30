import SwiftUI
import SwiftData
import UIKit

/// 전체 할 일을 날짜와 무관하게 우선순위(Must/Should/Could/Won't)별로 묶어서 보여준다.
/// 완료된 항목은 여기선 흐리게 두지 않고 아예 목록에서 치운다 — 이 화면은 앞으로 할
/// 일들을 보는 백로그라, 캘린더의 하루치 목록과 달리 끝난 건 남겨둘 이유가 없다.
struct PriorityListScreen: View {
    @Query(sort: \TodoItem.date) private var todos: [TodoItem]
    @Environment(\.modelContext) private var modelContext
    /// 기존 항목을 누르면 여기 채워지고, 하단 입력창이 새로 만들기 대신 그 항목을
    /// 고치는 채팅형 입력창으로 바뀐다(DayTodosContentView와 같은 패턴).
    @State private var editingTodo: TodoItem?
    /// 접어둔 우선순위 섹션들 — 헤더를 탭해서 접고 편다.
    @State private var collapsedPriorities: Set<Priority> = []
    /// 완료 섹션은 기본으로 접혀 있다 — 평소엔 안 보이지만, 잘못 체크했거나
    /// 되돌리고 싶을 때 펼쳐서 체크를 풀 수 있어야 한다(안 그러면 완료 즉시
    /// 목록에서 사라져서 되돌릴 방법이 없어진다).
    @State private var showsCompleted = false

    private var incompleteTodos: [TodoItem] {
        todos.filter { !$0.isCompleted }
    }

    private var completedTodos: [TodoItem] {
        todos.filter(\.isCompleted)
    }

    private var groupedByPriority: [Priority: [TodoItem]] {
        Dictionary(grouping: incompleteTodos, by: \.priority)
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(Priority.allCases) { priority in
                    let items = groupedByPriority[priority] ?? []
                    if !items.isEmpty {
                        Section {
                            if !collapsedPriorities.contains(priority) {
                                ForEach(items) { todo in
                                    TodoRow(todo: todo, showsDate: true, onTap: { editingTodo = todo })
                                        .listRowBackground(Color.clear)
                                        .listRowSeparator(.hidden)
                                        .listRowInsets(EdgeInsets(top: 6, leading: Metrics.spacingMD, bottom: 6, trailing: Metrics.spacingMD))
                                }
                                .onDelete { offsets in delete(items: items, at: offsets) }
                            }
                        } header: {
                            sectionHeader(for: priority, count: items.count)
                        }
                    }
                }

                if incompleteTodos.isEmpty {
                    ContentUnavailableView(
                        "할 일이 없어요",
                        systemImage: "checkmark.circle",
                        description: Text("아래에서 바로 추가해보세요")
                    )
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }

                if !completedTodos.isEmpty {
                    Section {
                        if showsCompleted {
                            ForEach(completedTodos) { todo in
                                TodoRow(todo: todo, showsDate: true, onTap: { editingTodo = todo })
                                    .listRowBackground(Color.clear)
                                    .listRowSeparator(.hidden)
                                    .listRowInsets(EdgeInsets(top: 6, leading: Metrics.spacingMD, bottom: 6, trailing: Metrics.spacingMD))
                            }
                            .onDelete { offsets in delete(items: completedTodos, at: offsets) }
                        }
                    } header: {
                        completedHeader
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(MoscoPalette.canvas.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .ignoresSafeArea(.keyboard, edges: .bottom)
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
                // "할 일" 탭에서 바로 만드는 항목은 날짜/시간 기본값이 없다 —
                // 캘린더 쪽(그 날짜의 리스트)에서 만들 때만 그 날짜가 기본이다.
                QuickAddView(date: nil, editingTodo: $editingTodo)
            }
        }
    }

    /// 탭하면 섹션이 접히고 펴진다 — 접힌 동안엔 개수만 남아 상태를 알 수 있다.
    private func sectionHeader(for priority: Priority, count: Int) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.25)) {
                if collapsedPriorities.contains(priority) {
                    collapsedPriorities.remove(priority)
                } else {
                    collapsedPriorities.insert(priority)
                }
            }
        } label: {
            HStack(spacing: 6) {
                Circle()
                    .fill(priority.color)
                    .frame(width: 7, height: 7)
                Text(priority.fullLabel)

                if collapsedPriorities.contains(priority) {
                    Text("\(count)")
                        .foregroundStyle(MoscoPalette.textSecondary.opacity(0.6))
                }

                Spacer()

                Image(systemName: "chevron.down")
                    .font(.system(size: 11, weight: .semibold))
                    .rotationEffect(.degrees(collapsedPriorities.contains(priority) ? -90 : 0))
            }
            .font(.moscoCaption())
            .foregroundStyle(MoscoPalette.textSecondary)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    /// 완료된 항목은 여기서만 다시 볼 수 있다 — 펼치면 체크를 눌러 되돌릴 수 있다.
    private var completedHeader: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.25)) {
                showsCompleted.toggle()
            }
        } label: {
            HStack(spacing: 6) {
                Text("완료됨")
                Text("\(completedTodos.count)")
                    .foregroundStyle(MoscoPalette.textSecondary.opacity(0.6))

                Spacer()

                Image(systemName: "chevron.down")
                    .font(.system(size: 11, weight: .semibold))
                    .rotationEffect(.degrees(showsCompleted ? 0 : -90))
            }
            .font(.moscoCaption())
            .foregroundStyle(MoscoPalette.textSecondary)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func delete(items: [TodoItem], at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(items[index])
        }
    }
}
