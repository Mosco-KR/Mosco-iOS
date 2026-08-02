import SwiftUI

/// 캘린더를 새로 만들거나(existing == nil) 기존 걸 고치는 시트.
///
/// `CategoryEditorSheet`와 같은 모양이지만 알림 설정이 없다 — 알림은 카테고리
/// 단위로 정하는 것이고, 캘린더는 "무엇을 보고 있는가"만 가른다.
struct CalendarEditorSheet: View {
    struct Draft {
        let name: String
        let colorHex: String
    }

    let existing: TodoCalendar?
    let onSave: (Draft) -> Void
    let onDelete: (() -> Void)?

    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var colorHex: String

    /// usedColorHexValues: 이미 다른 캘린더가 쓰는 색 — 새로 만들 때 겹치지 않는
    /// 색을 기본으로 내민다.
    init(
        existing: TodoCalendar?,
        usedColorHexValues: [String],
        onSave: @escaping (Draft) -> Void,
        onDelete: (() -> Void)? = nil
    ) {
        self.existing = existing
        self.onSave = onSave
        self.onDelete = onDelete
        _name = State(initialValue: existing?.name ?? "")
        _colorHex = State(
            initialValue: existing?.colorHex ?? CategoryColorPalette.nextDefault(avoiding: usedColorHexValues)
        )
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("이름") {
                    TextField("캘린더 이름", text: $name)
                }

                Section {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 16) {
                        ForEach(CategoryColorPalette.hexValues, id: \.self) { hex in
                            colorSwatch(hex)
                        }
                    }
                    .padding(.vertical, 8)
                } header: {
                    Text("색상")
                } footer: {
                    Text("이 색은 위쪽 선택기에서만 써요. 달력의 할 일 막대는 카테고리 색을 따라가요.")
                }

                if existing?.isDefault == true {
                    Section {
                        Text("기본 캘린더는 삭제할 수 없어요. 이름과 색은 바꿀 수 있어요.")
                            .font(.moscoCaption())
                            .foregroundStyle(MoscoPalette.textSecondary)
                    }
                } else if let onDelete {
                    Section {
                        Button("캘린더 삭제", role: .destructive) {
                            onDelete()
                            dismiss()
                        }
                    }
                }
            }
            .navigationTitle(existing == nil ? "새 캘린더" : "캘린더 수정")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("저장") {
                        onSave(
                            Draft(
                                name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                                colorHex: colorHex
                            )
                        )
                        dismiss()
                    }
                    .disabled(!canSave)
                }
            }
        }
    }

    private func colorSwatch(_ hex: String) -> some View {
        let color = CategoryColorPalette.color(forHex: hex)
        let isSelected = colorHex == hex

        return Circle()
            .fill(color)
            .frame(width: 34, height: 34)
            .overlay(
                Image(systemName: "checkmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white)
                    .opacity(isSelected ? 1 : 0)
            )
            .overlay(
                Circle()
                    .stroke(MoscoPalette.accent, lineWidth: isSelected ? 2.5 : 0)
                    .padding(-4)
            )
            .scaleEffect(isSelected ? 1.08 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
            .onTapGesture { colorHex = hex }
    }
}
