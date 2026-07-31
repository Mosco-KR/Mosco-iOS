import SwiftUI
import SwiftData

/// 카테고리를 만들고 나면 관리(수정/삭제)할 곳이 필요하다 — QuickAddView의
/// 팝업에서 길게 눌러 고치는 경로와 별개로, 여기서 한눈에 모아보고 정리한다.
struct SettingsScreen: View {
    @Query(sort: \TodoCategory.sortOrder) private var categories: [TodoCategory]
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var categoryBeingEdited: TodoCategory?
    @State private var showsNewCategorySheet = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(categories) { category in
                        Button {
                            categoryBeingEdited = category
                        } label: {
                            HStack(spacing: 10) {
                                Circle()
                                    .fill(category.color)
                                    .frame(width: 14, height: 14)
                                Text(category.name)
                                    .foregroundStyle(MoscoPalette.textPrimary)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(MoscoPalette.textSecondary.opacity(0.5))
                            }
                        }
                        .buttonStyle(.plain)
                        .deleteDisabled(category.isDefault)
                    }
                    .onDelete(perform: delete)
                } header: {
                    Text("카테고리")
                } footer: {
                    Text("눌러서 이름·색을 고치고, 왼쪽으로 밀어서 삭제할 수 있어요. 기본 카테고리는 삭제할 수 없고, 지운 카테고리의 할 일은 기본 카테고리로 옮겨져요.")
                }

                Section {
                    Button {
                        showsNewCategorySheet = true
                    } label: {
                        Label("새 카테고리 추가", systemImage: "plus.circle.fill")
                    }
                }
            }
            .navigationTitle("설정")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("완료") { dismiss() }
                }
            }
            .sheet(isPresented: $showsNewCategorySheet) {
                CategoryEditorSheet(
                    existing: nil,
                    usedColorHexValues: categories.map(\.colorHex),
                    onSave: { name, colorHex in
                        modelContext.insert(TodoCategory(name: name, colorHex: colorHex, sortOrder: categories.count))
                    }
                )
            }
            .sheet(item: $categoryBeingEdited) { editing in
                CategoryEditorSheet(
                    existing: editing,
                    usedColorHexValues: categories.map(\.colorHex),
                    onSave: { name, colorHex in
                        editing.name = name
                        editing.colorHex = colorHex
                    },
                    onDelete: {
                        guard let defaultCategory = categories.first(where: \.isDefault) else { return }
                        TodoCategory.delete(editing, reassigningTodosTo: defaultCategory, in: modelContext)
                    }
                )
            }
        }
    }

    private func delete(at offsets: IndexSet) {
        guard let defaultCategory = categories.first(where: \.isDefault) else { return }
        for index in offsets {
            TodoCategory.delete(categories[index], reassigningTodosTo: defaultCategory, in: modelContext)
        }
    }
}
