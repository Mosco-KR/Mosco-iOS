import SwiftUI
import SwiftData
import UIKit

/// 오늘 할 일만 모아서 카테고리별로 묶어 보여준다. 날짜 없는 백로그 항목도
/// "언제든 해도 되는 일"로 취급해 여기 포함한다 — 날짜가 정해진 다른 날짜의
/// 할 일은 캘린더 탭에서 그 날짜를 눌러 따로 본다.
/// 완료된 항목은 여기선 흐리게 두지 않고 아예 목록에서 치운다 — 이 화면은 오늘
/// 처리할 일들을 보는 곳이라, 끝난 건 접어둔 섹션에서만 다시 볼 수 있으면 된다.
struct TodayTodoScreen: View {
    @Query(sort: \TodoCategory.sortOrder) private var categories: [TodoCategory]
    @Query private var allTodos: [TodoItem]
    @Environment(\.modelContext) private var modelContext
    /// 기존 항목을 누르면 여기 채워지고, 하단 입력창이 새로 만들기 대신 그 항목을
    /// 고치는 채팅형 입력창으로 바뀐다(DayTodosContentView와 같은 패턴).
    @State private var editingTodo: TodoItem?
    /// 접어둔 카테고리 섹션들(nil = 미분류) — 헤더를 탭해서 접고 편다.
    @State private var collapsedCategoryKeys: Set<UUID?> = []
    /// 완료 섹션은 기본으로 접혀 있다 — 평소엔 안 보이지만, 잘못 체크했거나
    /// 되돌리고 싶을 때 펼쳐서 체크를 풀 수 있어야 한다(안 그러면 완료 즉시
    /// 목록에서 사라져서 되돌릴 방법이 없어진다).
    @State private var showsCompleted = false

    private let calendar = Calendar.current
    private var today: Date { calendar.startOfDay(for: .now) }

    /// 반복 인스턴스는 저장소에 없고 규칙으로 계산되므로 #Predicate로는 못 거른다.
    /// 개인용 앱 규모에선 전체를 메모리에서 거르는 게 단순하고 충분히 빠르다.
    /// 날짜 없는 백로그 항목도 "오늘 해도 되는 일"로 포함시킨다.
    private var todosForToday: [TodoItem] {
        allTodos.filter { $0.date == nil || $0.occurs(on: today) }
    }

    private func isDone(_ todo: TodoItem) -> Bool {
        todo.isCompleted(on: today)
    }

    private var incompleteTodos: [TodoItem] {
        todosForToday.filter { !isDone($0) }
    }

    private var completedTodos: [TodoItem] {
        todosForToday.filter(isDone)
    }

    /// 사용자가 만든 카테고리 순서대로 먼저, 그다음 미분류(nil) 묶음.
    private var groupedByCategory: [(category: TodoCategory?, items: [TodoItem])] {
        var buckets: [UUID?: [TodoItem]] = [:]
        for todo in incompleteTodos {
            buckets[todo.category?.id, default: []].append(todo)
        }
        var result: [(TodoCategory?, [TodoItem])] = categories.compactMap { category in
            guard let items = buckets[category.id] else { return nil }
            return (category, items)
        }
        if let uncategorized = buckets[nil] {
            result.append((nil, uncategorized))
        }
        return result
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(groupedByCategory, id: \.category?.id) { group in
                    Section {
                        if !collapsedCategoryKeys.contains(group.category?.id) {
                            ForEach(group.items) { todo in
                                TodoRow(todo: todo, occurrenceDate: today, onTap: { editingTodo = todo })
                                    .listRowBackground(Color.clear)
                                    .listRowSeparator(.hidden)
                                    .listRowInsets(EdgeInsets(top: 6, leading: Metrics.spacingMD, bottom: 6, trailing: Metrics.spacingMD))
                            }
                            .onDelete { offsets in delete(items: group.items, at: offsets) }
                        }
                    } header: {
                        sectionHeader(for: group.category, count: group.items.count)
                    }
                }

                if incompleteTodos.isEmpty {
                    ContentUnavailableView(
                        "오늘 할 일이 없어요",
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
                                TodoRow(todo: todo, occurrenceDate: today, onTap: { editingTodo = todo })
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
                // "오늘 할 일" 탭에서 바로 만드는 항목은 날짜/시간 기본값이 없다 —
                // 캘린더 쪽(그 날짜의 리스트)에서 만들 때만 그 날짜가 기본이다.
                QuickAddView(date: nil, editingTodo: $editingTodo)
            }
        }
    }

    /// 탭하면 섹션이 접히고 펴진다 — 접힌 동안엔 개수만 남아 상태를 알 수 있다.
    private func sectionHeader(for category: TodoCategory?, count: Int) -> some View {
        let key = category?.id
        return Button {
            withAnimation(.easeInOut(duration: 0.25)) {
                if collapsedCategoryKeys.contains(key) {
                    collapsedCategoryKeys.remove(key)
                } else {
                    collapsedCategoryKeys.insert(key)
                }
            }
        } label: {
            HStack(spacing: 6) {
                Circle()
                    .fill(category?.color ?? MoscoPalette.textSecondary)
                    .frame(width: 7, height: 7)
                Text(category?.name ?? "미분류")

                if collapsedCategoryKeys.contains(key) {
                    Text("\(count)")
                        .foregroundStyle(MoscoPalette.textSecondary.opacity(0.6))
                }

                Spacer()

                Image(systemName: "chevron.down")
                    .font(.system(size: 11, weight: .semibold))
                    .rotationEffect(.degrees(collapsedCategoryKeys.contains(key) ? -90 : 0))
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
