import SwiftData
import SwiftUI

/// 메모 한 장을 쓰는 화면. **빈 종이 하나**가 전부다.
///
/// 제목 칸을 따로 두지 않는다 — 메모장에서 제목을 먼저 묻는 것만큼 적는 걸 막는
/// 일이 없다. 첫 줄이 곧 제목이고, 목록에서 그렇게 읽힌다(`MemoNote.title`).
///
/// **저장 단추도 없다.** 치는 대로 저장되고, 뒤로 나가면 끝이다. 메모는 되돌릴
/// 거리가 거의 없는 글이라 '완료'를 누르게 하면 그걸 안 누른 날 글을 잃는다
/// (할 일의 메모 시트도 같은 이유로 닫으면 저장한다).
struct MemoEditor: View {
    @Bindable var note: MemoNote

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isFocused: Bool

    var body: some View {
        TextEditor(text: $note.body)
            .font(.moscoBody())
            .lineSpacing(3)
            .scrollContentBackground(.hidden)
            .padding(.horizontal, Metrics.spacingMD - 5)
            .padding(.top, Metrics.spacingSM)
            .background(MoscoPalette.canvas.ignoresSafeArea())
            .focused($isFocused)
            .overlay(alignment: .topLeading) {
                if note.body.isEmpty {
                    Text("여기에 자유롭게 적어보세요")
                        .font(.moscoBody())
                        .foregroundStyle(MoscoPalette.textSecondary.opacity(0.6))
                        .padding(.horizontal, Metrics.spacingMD)
                        .padding(.top, Metrics.spacingSM + 8)
                        .allowsHitTesting(false)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(note.updatedAt.memoEditorLabel)
                        .font(.moscoCaption())
                        .foregroundStyle(MoscoPalette.textSecondary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        note.isPinned.toggle()
                    } label: {
                        Image(systemName: note.isPinned ? "pin.fill" : "pin")
                    }
                    .accessibilityLabel(note.isPinned ? String(localized: "고정 해제") : String(localized: "맨 위에 고정"))
                }
            }
            // 새 메모는 빈 채로 열리므로 커서가 와 있어야 한다 — 한 번 더 눌러야
            // 키보드가 뜨면, 적으려고 들어온 화면에서 한 걸음을 더 밟는 셈이다.
            .task {
                guard note.isEmpty else { return }
                try? await Task.sleep(nanoseconds: 300_000_000)
                isFocused = true
            }
            .onChange(of: note.body) { _, _ in
                note.updatedAt = .now
            }
            // **빈 채로 나가면 지운다.** 새 메모를 먼저 만들고 여는 구조라,
            // 안 지우면 아무것도 안 적고 나올 때마다 빈 장이 쌓인다.
            .onDisappear {
                guard MemoList.shouldDiscard(note) else { return }
                modelContext.delete(note)
            }
    }
}
