import SwiftUI
import SwiftData

/// 캘린더를 만들고 고치는 화면.
///
/// 예전엔 설정 첫 화면의 한 섹션이었다. 캘린더와 카테고리가 각각 늘어나면서
/// 설정을 열면 그 목록이 화면의 절반을 차지했고, 정작 알림·날씨 같은 스위치는
/// 스크롤을 한참 내려야 나왔다. **설정 첫 화면은 무엇이 있는지 훑는 자리이고,
/// 하나하나 고치는 것은 들어가서 한다.**
struct CalendarListScreen: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TodoCalendar.sortOrder) private var calendars: [TodoCalendar]
    @State private var editing: EditorTarget?

    private enum EditorTarget: Identifiable {
        case new
        case existing(TodoCalendar)

        var id: String {
            switch self {
            case .new: "new"
            case .existing(let calendar): calendar.id.uuidString
            }
        }

        var calendar: TodoCalendar? {
            if case .existing(let calendar) = self { return calendar }
            return nil
        }
    }

    var body: some View {
        List {
            Section {
                ForEach(calendars) { calendar in
                    Button {
                        editing = .existing(calendar)
                    } label: {
                        SettingsColorRow(
                            color: CategoryColorPalette.color(forHex: calendar.colorHex),
                            name: calendar.name
                        )
                    }
                    .buttonStyle(.plain)
                    .deleteDisabled(calendar.isDefault)
                }
                .onDelete(perform: delete)
            } footer: {
                Text("일과 개인처럼 크게 나눌 때 써요. 기본 캘린더는 삭제할 수 없어요.")
            }

            Section {
                Button {
                    editing = .new
                } label: {
                    Label("새 캘린더 추가", systemImage: "plus.circle.fill")
                }
            }
        }
        .navigationTitle("캘린더")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $editing) { target in
            CalendarEditorSheet(
                existing: target.calendar,
                usedColorHexValues: calendars.map(\.colorHex),
                onSave: { draft in
                    if let editing = target.calendar {
                        editing.name = draft.name
                        editing.colorHex = draft.colorHex
                    } else {
                        modelContext.insert(
                            TodoCalendar(name: draft.name, colorHex: draft.colorHex, sortOrder: calendars.count)
                        )
                    }
                },
                onDelete: target.calendar.map { editing in
                    {
                        guard let fallback = calendars.first(where: \.isDefault) else { return }
                        TodoCalendar.delete(editing, reassigningTodosTo: fallback, in: modelContext)
                    }
                }
            )
        }
    }

    private func delete(at offsets: IndexSet) {
        guard let fallback = calendars.first(where: \.isDefault) else { return }
        for index in offsets {
            TodoCalendar.delete(calendars[index], reassigningTodosTo: fallback, in: modelContext)
        }
    }
}

/// 색 점 + 이름 + 화살표. 캘린더와 카테고리 목록이 같은 모양을 쓴다.
struct SettingsColorRow: View {
    let color: Color
    let name: String

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(color)
                .frame(width: 14, height: 14)
            Text(name)
                .foregroundStyle(MoscoPalette.textPrimary)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(MoscoPalette.textSecondary.opacity(0.5))
        }
        // 이게 없으면 글자와 화살표에만 터치가 잡히고 그 사이 빈 공간은 안 눌린다.
        .contentShape(Rectangle())
    }
}

/// 설정 첫 화면의 진입 행 — 아이콘 + 이름 + 개수.
///
/// 개수를 같이 보여주는 이유는 **들어가 보지 않고도 뭐가 있는지 알기 위해서**다.
/// 이름만 있으면 비어 있는지 열 개가 있는지 구분이 안 된다.
struct SettingsEntryRow: View {
    let systemImage: String
    let title: String
    let detail: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(MoscoPalette.accent)
                .frame(width: 22)
            Text(title)
                .foregroundStyle(MoscoPalette.textPrimary)
            Spacer()
            Text(detail)
                .font(.moscoCaption())
                .foregroundStyle(MoscoPalette.textSecondary)
        }
    }
}
