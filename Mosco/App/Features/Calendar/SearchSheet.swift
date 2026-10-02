import SwiftData
import SwiftUI

/// 달력 머리의 돋보기로 여는 검색. 예전엔 오늘 탭 머리에 있었다.
///
/// 제목과 메모를 함께, 날짜와 무관하게 **전체**를 훑는다(`TodayPage.search`) —
/// 앞날의 할 일에 닿는 가장 빠른 길이다. 결과의 수정 버튼을 누르면 그 할 일이 있는
/// 날의 페이지로 간다. 날짜 없는 할 일은 오늘 페이지 아래에 있으므로 오늘로 간다.
struct SearchSheet: View {
    /// 결과를 골랐을 때 열 날짜. 시트가 닫힌 뒤 달력이 그 날 페이지를 연다.
    let onOpen: (Date) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var allTodos: [TodoItem]
    @AppStorage(CalendarSelection.storageKey) private var hiddenCalendarIDs = ""
    @State private var query = ""

    /// 숨긴 캘린더의 할 일은 검색에도 안 나온다 — 달력에서 안 보이는 것이 검색에서만
    /// 튀어나오면 어디서 온 건지 헷갈린다.
    private var results: [TodoItem] {
        let hidden = CalendarSelection.hidden(from: hiddenCalendarIDs)
        return TodayPage.search(query, in: allTodos.filter { CalendarSelection.matches($0, hidden: hidden) })
    }

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("검색")
                .navigationBarTitleDisplayMode(.inline)
                .searchable(
                    text: $query,
                    placement: .navigationBarDrawer(displayMode: .always),
                    prompt: "할 일과 메모에서 찾기"
                )
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("완료") { dismiss() }
                    }
                }
        }
    }

    @ViewBuilder
    private var content: some View {
        if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            // 제목에 질문을 쓰지 않는다(문구 원칙 2) — 무엇을 하는 화면인지 이름으로.
            ContentUnavailableView(
                "할 일 찾기",
                systemImage: "magnifyingglass",
                description: Text("제목이나 메모에 적은 말로 찾아요")
            )
        } else if results.isEmpty {
            ContentUnavailableView.search(text: query)
        } else {
            List {
                ForEach(results) { todo in
                    // 여러 날짜가 섞이므로 날짜를 함께 보여준다. 몸통을 누르면 완료,
                    // 수정 버튼을 누르면 그날 페이지로 — 다른 화면과 손짓이 같다.
                    TodoRow(
                        todo: todo,
                        showsDate: true,
                        onTap: {
                            onOpen(todo.date ?? Calendar.current.startOfDay(for: .now))
                            dismiss()
                        },
                        onDelete: { modelContext.delete(todo) },
                        memoDisplay: .compact
                    )
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: Metrics.listRowGap, leading: Metrics.spacingMD, bottom: Metrics.listRowGap, trailing: Metrics.spacingMD))
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .scrollDismissesKeyboard(.immediately)
        }
    }
}
