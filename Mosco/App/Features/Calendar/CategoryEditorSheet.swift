import SwiftUI
import SwiftData

/// 카테고리를 새로 만들거나(existing == nil) 기존 걸 고치는 시트. 이름 +
/// 16색 팔레트에서 색 고르기, 기존 카테고리면 삭제까지 한 화면에서 처리한다.
struct CategoryEditorSheet: View {
    let existing: TodoCategory?
    let onSave: (String, String) -> Void
    let onDelete: (() -> Void)?

    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var colorHex: String

    /// usedColorHexValues: 이미 다른 카테고리가 쓰고 있는 색들 — 새로 만들 때
    /// 기본으로 내미는 색이 이미 쓰인 색과 안 겹치게 고르는 데 쓴다.
    init(
        existing: TodoCategory?,
        usedColorHexValues: [String],
        onSave: @escaping (String, String) -> Void,
        onDelete: (() -> Void)? = nil
    ) {
        self.existing = existing
        self.onSave = onSave
        self.onDelete = onDelete
        _name = State(initialValue: existing?.name ?? "")
        _colorHex = State(initialValue: existing?.colorHex ?? CategoryColorPalette.nextDefault(avoiding: usedColorHexValues))
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("이름") {
                    TextField("카테고리 이름", text: $name)
                }

                Section("색상") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 16) {
                        ForEach(CategoryColorPalette.hexValues, id: \.self) { hex in
                            let color = CategoryColorPalette.color(forHex: hex)
                            let isSelected = colorHex == hex

                            Circle()
                                .fill(color)
                                .frame(width: 34, height: 34)
                                .overlay(
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundStyle(.white)
                                        .opacity(isSelected ? 1 : 0)
                                )
                                // 검은 테두리 대신 앱 액센트 색 링을 바깥으로 살짝 띄워서,
                                // 선택된 색 자체는 안 가리면서도 브랜드 톤이 이어지게 한다.
                                .overlay(
                                    Circle()
                                        .stroke(MoscoPalette.accent, lineWidth: isSelected ? 2.5 : 0)
                                        .padding(-4)
                                )
                                .scaleEffect(isSelected ? 1.08 : 1)
                                .shadow(color: isSelected ? color.opacity(0.45) : .clear, radius: 6, y: 2)
                                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
                                .onTapGesture { colorHex = hex }
                        }
                    }
                    .padding(.vertical, 8)
                }

                if existing?.isDefault == true {
                    Section {
                        Text("기본 카테고리는 삭제할 수 없어요. 이름과 색은 자유롭게 바꿀 수 있어요.")
                            .font(.moscoCaption())
                            .foregroundStyle(MoscoPalette.textSecondary)
                    }
                } else if let onDelete {
                    Section {
                        Button("카테고리 삭제", role: .destructive) {
                            onDelete()
                            dismiss()
                        }
                    }
                }
            }
            .navigationTitle(existing == nil ? "새 카테고리" : "카테고리 수정")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("저장") {
                        onSave(name.trimmingCharacters(in: .whitespacesAndNewlines), colorHex)
                        dismiss()
                    }
                    .disabled(!canSave)
                }
            }
        }
    }
}
