import SwiftUI
import SwiftData

/// 시트에서 편집한 값 묶음. 필드가 늘 때마다 onSave의 인자가 하나씩 붙어
/// 순서로 구분해야 하는 걸 막는다.
struct CategoryDraft {
    let name: String
    let colorHex: String
    let notifiesBeforeStart: Bool
    let notificationLeadMinutes: Int
}

/// 카테고리를 새로 만들거나(existing == nil) 기존 걸 고치는 시트. 이름 +
/// 16색 팔레트에서 색 고르기, 알림 설정, 기존 카테고리면 삭제까지 한 화면에서 처리한다.
struct CategoryEditorSheet: View {
    let existing: TodoCategory?
    let onSave: (CategoryDraft) -> Void
    let onDelete: (() -> Void)?

    @Environment(\.dismiss) private var dismiss
    @Environment(TodoNotificationScheduler.self) private var notificationScheduler
    @State private var name: String
    @State private var colorHex: String
    @State private var notifies: Bool
    @State private var leadMinutes: Int
    /// 알림을 켰는데 시스템 권한이 거부돼 있으면 안내를 띄운다.
    @State private var showsDeniedNotice = false

    /// 흔히 쓰는 리드타임만 추린다 — 분 단위 자유 입력은 고를 게 너무 많아진다.
    private static let leadOptions = [0, 5, 10, 15, 30, 60, 120]

    /// usedColorHexValues: 이미 다른 카테고리가 쓰고 있는 색들 — 새로 만들 때
    /// 기본으로 내미는 색이 이미 쓰인 색과 안 겹치게 고르는 데 쓴다.
    init(
        existing: TodoCategory?,
        usedColorHexValues: [String],
        onSave: @escaping (CategoryDraft) -> Void,
        onDelete: (() -> Void)? = nil
    ) {
        self.existing = existing
        self.onSave = onSave
        self.onDelete = onDelete
        _name = State(initialValue: existing?.name ?? "")
        _colorHex = State(initialValue: existing?.colorHex ?? CategoryColorPalette.nextDefault(avoiding: usedColorHexValues))
        _notifies = State(initialValue: existing?.notifiesBeforeStart ?? true)
        _leadMinutes = State(initialValue: existing?.notificationLeadMinutes ?? 10)
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

                // 앱 전체 알림이 꺼져 있으면 이 섹션 자체를 감춘다 — 어차피
                // 안 오는 설정을 만지게 두면 켜놨는데 왜 안 오냐는 오해만 생긴다.
                if notificationScheduler.isEnabled {
                    Section {
                        Toggle("시작 전 알림", isOn: $notifies)

                        if notifies {
                            Picker("알림 시점", selection: $leadMinutes) {
                                ForEach(Self.leadOptions, id: \.self) { minutes in
                                    Text(leadLabel(minutes)).tag(minutes)
                                }
                            }
                        }
                    } header: {
                        Text("알림")
                    } footer: {
                        Text("이 카테고리의 할 일 중 시작 시간이 있는 것만 알려드려요.")
                    }
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
                        onSave(
                            CategoryDraft(
                                name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                                colorHex: colorHex,
                                notifiesBeforeStart: notifies,
                                notificationLeadMinutes: leadMinutes
                            )
                        )
                        dismiss()
                    }
                    .disabled(!canSave)
                }
            }
            .task { await notificationScheduler.refreshAuthorizationStatus() }
        }
    }

    private func leadLabel(_ minutes: Int) -> String {
        switch minutes {
        case 0: "시작 시간에"
        case ..<60: "\(minutes)분 전"
        default: "\(minutes / 60)시간 전"
        }
    }
}
