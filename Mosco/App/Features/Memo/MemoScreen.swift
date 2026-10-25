import SwiftData
import SwiftUI

/// '메모' 탭 — 그냥 메모장이다.
///
/// **할 일이 아니다.** 체크박스도, 날짜 칩도, 카테고리도 없다. 한 장에 글이 있고,
/// 첫 줄이 제목이고, 누르면 전체 화면으로 열려 거기서 고친다. 적어두고 싶은 것에
/// 할 일의 껍데기(체크·날짜·분류)는 전부 군더더기였다.
///
/// 날짜를 안 정한 **할 일**은 여기 오지 않는다 — 그건 지금까지처럼 할 일 탭의
/// '날짜 없음' 칸이 맡는다. 두 탭은 서로 다른 것을 담는다.
struct MemoScreen: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var notes: [MemoNote]
    @State private var query = ""
    @State private var openNote: MemoNote?

    private var visible: [MemoNote] {
        MemoList.sorted(MemoList.search(query, in: notes))
    }

    var body: some View {
        NavigationStack {
            content
                .background(MoscoPalette.canvas.ignoresSafeArea())
                .navigationTitle("메모")
                .navigationBarTitleDisplayMode(.large)
                .searchable(text: $query, prompt: "메모에서 찾기")
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(action: newNote) {
                            Image(systemName: "square.and.pencil")
                        }
                        .accessibilityLabel("새 메모")
                    }
                }
                .navigationDestination(item: $openNote) { note in
                    MemoEditor(note: note)
                }
                .logScreen(.memos)
        }
    }

    @ViewBuilder
    private var content: some View {
        if visible.isEmpty {
            emptyState
        } else {
            List {
                ForEach(visible) { note in
                    Button { openNote = note } label: { row(note) }
                        .buttonStyle(.plain)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(
                            EdgeInsets(top: 2, leading: Metrics.spacingMD, bottom: 2, trailing: Metrics.spacingMD)
                        )
                        .contextMenu {
                            Button {
                                note.isPinned.toggle()
                                note.updatedAt = .now
                            } label: {
                                Label(
                                    note.isPinned ? String(localized: "고정 해제") : String(localized: "맨 위에 고정"),
                                    systemImage: note.isPinned ? "pin.slash" : "pin"
                                )
                            }
                            Button(role: .destructive) {
                                modelContext.delete(note)
                            } label: {
                                Label("삭제", systemImage: "trash")
                            }
                        }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .scrollDismissesKeyboard(.immediately)
        }
    }

    /// 한 장. **제목 한 줄과 미리보기 한 줄**이 전부다 — 메모장은 훑어서 찾는
    /// 화면이라, 한 장이 커질수록 한 번에 보이는 장수가 준다.
    private func row(_ note: MemoNote) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 6) {
                if note.isPinned {
                    Image(systemName: "pin.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(MoscoPalette.textSecondary)
                }
                Text(note.title.isEmpty ? String(localized: "새 메모") : note.title)
                    .font(.moscoBody().weight(.medium))
                    .foregroundStyle(MoscoPalette.textPrimary)
                    .lineLimit(1)
            }

            HStack(spacing: 6) {
                Text(note.updatedAt.memoListLabel)
                    .foregroundStyle(MoscoPalette.textSecondary)
                if !note.preview.isEmpty {
                    Text(note.preview)
                        .foregroundStyle(MoscoPalette.textSecondary.opacity(0.75))
                        .lineLimit(1)
                }
            }
            .font(.moscoCaption())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 11)
        .contentShape(Rectangle())
        .overlay(alignment: .bottom) {
            // 카드가 아니라 **줄**이다. 메모장은 장수가 많아지는 화면이라,
            // 장마다 카드를 세우면 여백만으로 화면이 금세 찬다.
            Rectangle()
                .fill(MoscoPalette.border.opacity(0.5))
                .frame(height: 0.5)
        }
    }

    private var emptyState: some View {
        VStack(spacing: Metrics.spacingSM) {
            Spacer()
            Text(query.isEmpty ? String(localized: "적어둔 메모가 없어요") : String(localized: "찾는 메모가 없어요"))
                .font(.moscoBody())
                .foregroundStyle(MoscoPalette.textSecondary)
            if query.isEmpty {
                Text("오른쪽 위에서 새 메모를 시작해요")
                    .font(.moscoCaption())
                    .foregroundStyle(MoscoPalette.textSecondary.opacity(0.7))
            }
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    /// **빈 메모를 먼저 만들고 편집기를 연다.** 제목부터 묻지 않으려는 것이다 —
    /// 아무것도 안 적고 나오면 나가면서 지운다(`MemoEditor`).
    private func newNote() {
        let note = MemoNote()
        modelContext.insert(note)
        openNote = note
    }
}
