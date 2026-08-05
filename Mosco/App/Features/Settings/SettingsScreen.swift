import SwiftUI
import SwiftData
import UIKit

/// 카테고리를 만들고 나면 관리(수정/삭제)할 곳이 필요하다 — QuickAddView의
/// 팝업에서 길게 눌러 고치는 경로와 별개로, 여기서 한눈에 모아보고 정리한다.
struct SettingsScreen: View {
    @Query(sort: \TodoCategory.sortOrder) private var categories: [TodoCategory]
    @Query(sort: \TodoCalendar.sortOrder) private var calendars: [TodoCalendar]
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(WeatherStore.self) private var weatherStore
    @Environment(TodoNotificationScheduler.self) private var notificationScheduler
    @Environment(TutorialManager.self) private var tutorialManager
    /// 카테고리·캘린더의 "새로 만들기"와 "고치기"를 전부 하나의 상태로 합쳤다.
    ///
    /// 같은 계층에 `.sheet`를 두 개 붙이면 뒤에 붙은 것만 살아난다(카테고리를 눌러도
    /// 시트가 안 뜨던 원인). 캘린더 섹션을 추가할 때 그 시트를 `Section`에 따로
    /// 붙여봤다가 같은 문제를 다시 만났다 — 시트는 하나만 두고 대상으로 가른다.
    @State private var editorTarget: EditorTarget?
    /// 데이터 초기화는 두 단계로 확인받는다.
    @State private var showsResetFirstConfirm = false
    @State private var showsResetSecondConfirm = false
    @AppStorage(CalendarSelection.storageKey) private var hiddenCalendarIDs = ""

    private enum EditorTarget: Identifiable {
        case newCategory
        case existingCategory(TodoCategory)
        case newCalendar
        case existingCalendar(TodoCalendar)

        var id: String {
            switch self {
            case .newCategory: "new-category"
            case .existingCategory(let category): "category-\(category.id.uuidString)"
            case .newCalendar: "new-calendar"
            case .existingCalendar(let calendar): "calendar-\(calendar.id.uuidString)"
            }
        }

        var category: TodoCategory? {
            if case .existingCategory(let category) = self { return category }
            return nil
        }

        var calendar: TodoCalendar? {
            if case .existingCalendar(let calendar) = self { return calendar }
            return nil
        }

        var isCalendar: Bool {
            switch self {
            case .newCalendar, .existingCalendar: true
            case .newCategory, .existingCategory: false
            }
        }
    }

    var body: some View {
        NavigationStack {
            List {
                calendarSection

                Section {
                    ForEach(categories) { category in
                        Button {
                            editorTarget = .existingCategory(category)
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
                            // 이게 없으면 글자와 화살표에만 터치가 잡히고 그 사이
                            // 빈 공간은 안 눌린다 — 행 전체를 눌러야 자연스럽다.
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .deleteDisabled(category.isDefault)
                    }
                    .onDelete(perform: delete)
                } header: {
                    Text("카테고리")
                } footer: {
                    Text("색으로 구분하고, 알림 받을 시점을 정해요.")
                }

                Section {
                    Button {
                        editorTarget = .newCategory
                    } label: {
                        Label("새 카테고리 추가", systemImage: "plus.circle.fill")
                    }
                }

                notificationSection
                weatherSection
                guideSection
                resetSection
            }
            .navigationTitle("설정")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("완료") { dismiss() }
                }
            }
            .sheet(item: $editorTarget) { target in
                if target.isCalendar {
                    calendarEditor(for: target)
                } else {
                    categoryEditor(for: target)
                }
            }
        }
    }

    private func categoryEditor(for target: EditorTarget) -> some View {
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
                    Analytics.log(.categoryCreated(count: categories.count + 1))
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

    private func calendarEditor(for target: EditorTarget) -> some View {
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
                    Analytics.log(.calendarCreated(count: calendars.count + 1))
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

    /// 캘린더 묶음 관리. 카테고리 섹션과 같은 패턴이라 조작 방법을 새로 배울 게 없다.
    @ViewBuilder
    private var calendarSection: some View {
        Section {
            ForEach(calendars) { calendar in
                Button {
                    editorTarget = .existingCalendar(calendar)
                } label: {
                    HStack(spacing: 10) {
                        Circle()
                            .fill(CategoryColorPalette.color(forHex: calendar.colorHex))
                            .frame(width: 14, height: 14)
                        Text(calendar.name)
                            .foregroundStyle(MoscoPalette.textPrimary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(MoscoPalette.textSecondary.opacity(0.5))
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .deleteDisabled(calendar.isDefault)
            }
            .onDelete(perform: deleteCalendars)

            Button {
                editorTarget = .newCalendar
            } label: {
                Label("새 캘린더 추가", systemImage: "plus.circle.fill")
            }
        } header: {
            Text("캘린더")
        } footer: {
            Text("일과 개인처럼 크게 나눠서 볼 수 있어요.")
        }
    }

    /// 앱 전체 알림 스위치. 카테고리별 설정 위에 있는 상위 스위치라, 꺼져 있으면
    /// 카테고리에서 켜둔 것도 안 온다는 걸 안내로 분명히 한다.
    @ViewBuilder
    private var notificationSection: some View {
        Section {
            // 권한이 없으면 켜지지 않게 막는다 — 켜지긴 했는데 알림은 안 오는
            // 상태가 제일 헷갈린다. 아직 안 물어봤으면 이때 물어보고, 거부돼
            // 있으면 토글은 꺼진 채로 두고 설정으로 보낸다.
            Toggle("알림 받기", isOn: Binding(
                get: { notificationScheduler.isEnabled },
                set: { isOn in
                    guard isOn else {
                        notificationScheduler.isEnabled = false
                        return
                    }
                    Task {
                        let granted = await notificationScheduler.requestAuthorization()
                        notificationScheduler.isEnabled = granted
                    }
                }
            ))

            if notificationScheduler.authorizationStatus == .denied {
                Button("설정에서 알림 허용하기") {
                    openSystemSettings()
                }
            }
        } header: {
            Text("알림")
        } footer: {
            if notificationScheduler.authorizationStatus == .denied {
                Text("기기 설정에서 알림이 꺼져 있어요.")
            } else if notificationScheduler.isEnabled {
                Text("어떤 카테고리를 언제 받을지는 위에서 정해요.")
            } else {
                Text("꺼두면 어떤 알림도 오지 않아요.")
            }
        }
    }

    /// 날씨 표시 토글 + 못 보여주는 이유별 안내. 이유를 안 보여주면 사용자는
    /// 토글을 켰는데 아무 일도 안 일어나는 걸 버그로 여기게 된다.
    @ViewBuilder
    private var weatherSection: some View {
        Section {
            Toggle("날씨 표시", isOn: Binding(
                get: { weatherStore.isEnabled },
                set: { weatherStore.isEnabled = $0 }
            ))

            if weatherStore.isEnabled, weatherStore.unavailableReason == .locationDenied {
                Button("설정에서 위치 허용하기") {
                    openSystemSettings()
                }
            }
        } header: {
            Text("날씨")
        } footer: {
            weatherFooter
        }
    }

    @ViewBuilder
    private var weatherFooter: some View {
        switch weatherStore.unavailableReason {
        case .locationDenied:
            Text("위치 권한이 없어 가져올 수 없어요.")
        case .serviceFailed:
            Text("가져오지 못했어요. 잠시 후 다시 시도할게요.")
        case .disabledByUser, .none:
            Text("주간 달력과 '오늘' 버튼에 함께 보여줘요.")
        }
    }

    /// 튜토리얼을 건너뛴 사람도, 새로 생긴 기능을 못 본 사람도 여기서 다시 볼 수 있다.
    @ViewBuilder
    private var guideSection: some View {
        Section {
            Button("튜토리얼 다시 보기") {
                dismiss()
                tutorialManager.restart()
            }
        } header: {
            Text("가이드")
        } footer: {
            Text("기본 기능 안내를 처음부터 다시 해볼 수 있어요.")
        }
    }

    /// 모든 데이터를 지우는 버튼. 되돌릴 수 없으므로 **두 번** 묻는다 — 한 번은
    /// "정말?", 두 번째는 "정말 확실해?". 잘못 눌러서 날아가는 게 제일 나쁘다.
    @ViewBuilder
    private var resetSection: some View {
        Section {
            Button("모든 데이터 삭제", role: .destructive) {
                showsResetFirstConfirm = true
            }
        } header: {
            Text("데이터")
        } footer: {
            Text("한 번 삭제하면 되돌릴 수 없어요.")
        }
        .confirmationDialog(
            "모든 데이터를 삭제할까요?",
            isPresented: $showsResetFirstConfirm,
            titleVisibility: .visible
        ) {
            Button("계속", role: .destructive) { showsResetSecondConfirm = true }
            Button("취소", role: .cancel) {}
        } message: {
            Text("할 일, 카테고리, 캘린더가 모두 사라져요.")
        }
        .confirmationDialog(
            "정말 삭제할까요?",
            isPresented: $showsResetSecondConfirm,
            titleVisibility: .visible
        ) {
            Button("전부 삭제", role: .destructive) { resetAllData() }
            Button("취소", role: .cancel) {}
        } message: {
            Text("되돌릴 수 없어요. 동기화 중이라면 다른 기기에서도 사라져요.")
        }
    }

    /// 세 모델을 전부 지운다. 기본 카테고리·캘린더는 다음 실행 때가 아니라 지금
    /// 바로 다시 만들어준다 — 새 할 일을 넣을 곳이 없는 상태로 남기지 않으려는 것이다.
    private func resetAllData() {
        for todo in (try? modelContext.fetch(FetchDescriptor<TodoItem>())) ?? [] {
            modelContext.delete(todo)
        }
        for category in (try? modelContext.fetch(FetchDescriptor<TodoCategory>())) ?? [] {
            modelContext.delete(category)
        }
        for calendar in (try? modelContext.fetch(FetchDescriptor<TodoCalendar>())) ?? [] {
            modelContext.delete(calendar)
        }

        modelContext.insert(TodoCategory(name: "할 일", colorHex: Self.seedColorHex, sortOrder: 0, isDefault: true))
        modelContext.insert(TodoCalendar(name: "기본", colorHex: Self.seedColorHex, sortOrder: 0, isDefault: true))

        // 숨김 목록에는 이제 없는 id만 남으므로 함께 비운다.
        hiddenCalendarIDs = ""
        dismiss()
    }

    /// RootTabView의 시드와 같은 색 — 앱 액센트.
    private static let seedColorHex = "8B5CF6"

    private func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    private func deleteCalendars(at offsets: IndexSet) {
        guard let fallback = calendars.first(where: \.isDefault) else { return }
        for index in offsets {
            TodoCalendar.delete(calendars[index], reassigningTodosTo: fallback, in: modelContext)
        }
    }

    private func delete(at offsets: IndexSet) {
        guard let defaultCategory = categories.first(where: \.isDefault) else { return }
        for index in offsets {
            TodoCategory.delete(categories[index], reassigningTodosTo: defaultCategory, in: modelContext)
        }
    }
}
