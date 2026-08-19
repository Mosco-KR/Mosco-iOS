import SwiftUI
import SwiftData

/// 카테고리를 만들고 고치는 화면. 색과 알림이 카테고리 단위로 붙는다.
///
/// 설정 첫 화면에서 갈라져 나온 이유는 `CalendarListScreen`과 같다.
struct CategoryListScreen: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TodoCategory.sortOrder) private var categories: [TodoCategory]
    @State private var editing: EditorTarget?

    private enum EditorTarget: Identifiable {
        case new
        case existing(TodoCategory)

        var id: String {
            switch self {
            case .new: "new"
            case .existing(let category): category.id.uuidString
            }
        }

        var category: TodoCategory? {
            if case .existing(let category) = self { return category }
            return nil
        }
    }

    var body: some View {
        List {
            Section {
                ForEach(categories) { category in
                    Button {
                        editing = .existing(category)
                    } label: {
                        SettingsColorRow(color: category.color, name: category.name)
                    }
                    .buttonStyle(.plain)
                    .deleteDisabled(category.isDefault)
                }
                .onDelete(perform: delete)
            } footer: {
                Text("할 일에 자동으로 붙는 묶음이에요. 카테고리마다 색과 알림을 따로 정해요.")
            }

            Section {
                Button {
                    editing = .new
                } label: {
                    Label("새 카테고리 추가", systemImage: "plus.circle.fill")
                }
            }
        }
        .navigationTitle("카테고리")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $editing) { target in
            CategoryEditorSheet(
                existing: target.category,
                usedColorHexValues: categories.map(\.colorHex),
                onSave: { draft in
                    if let editing = target.category {
                        editing.name = draft.name
                        editing.colorHex = draft.colorHex
                        editing.notifiesBeforeStart = draft.notifiesBeforeStart
                        editing.notificationLeadMinutes = draft.notificationLeadMinutes
                    } else {
                        let category = TodoCategory(
                            name: draft.name,
                            colorHex: draft.colorHex,
                            sortOrder: categories.count
                        )
                        category.notifiesBeforeStart = draft.notifiesBeforeStart
                        category.notificationLeadMinutes = draft.notificationLeadMinutes
                        modelContext.insert(category)
                    }
                },
                onDelete: target.category.map { editing in
                    {
                        guard let defaultCategory = categories.first(where: \.isDefault) else { return }
                        TodoCategory.delete(editing, reassigningTodosTo: defaultCategory, in: modelContext)
                    }
                }
            )
        }
    }

    private func delete(at offsets: IndexSet) {
        guard let defaultCategory = categories.first(where: \.isDefault) else { return }
        for index in offsets {
            TodoCategory.delete(categories[index], reassigningTodosTo: defaultCategory, in: modelContext)
        }
    }
}
