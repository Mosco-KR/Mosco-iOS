import SwiftUI
import SwiftData
import UIKit

/// 카테고리를 만들고 나면 관리(수정/삭제)할 곳이 필요하다 — QuickAddView의
/// 팝업에서 길게 눌러 고치는 경로와 별개로, 여기서 한눈에 모아보고 정리한다.
struct SettingsScreen: View {
    @Query(sort: \TodoCategory.sortOrder) private var categories: [TodoCategory]
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(WeatherStore.self) private var weatherStore
    @Environment(TodoNotificationScheduler.self) private var notificationScheduler
    /// 새로 만들기와 고치기를 하나의 상태로 합쳤다 — 같은 뷰에 .sheet를 두 개
    /// 체이닝하면 뒤에 붙은 것만 살아나서, 카테고리를 눌러도 시트가 안 떴다.
    @State private var editorTarget: EditorTarget?

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
            switch self {
            case .new: nil
            case .existing(let category): category
            }
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(categories) { category in
                        Button {
                            editorTarget = .existing(category)
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
                    Text("눌러서 이름·색을 고치고, 왼쪽으로 밀어서 삭제할 수 있어요. 기본 카테고리는 삭제할 수 없고, 지운 카테고리의 할 일은 기본 카테고리로 옮겨져요.")
                }

                Section {
                    Button {
                        editorTarget = .new
                    } label: {
                        Label("새 카테고리 추가", systemImage: "plus.circle.fill")
                    }
                }

                notificationSection
                weatherSection
            }
            .navigationTitle("설정")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("완료") { dismiss() }
                }
            }
            .sheet(item: $editorTarget) { target in
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
                Text("기기 설정에서 이 앱의 알림이 꺼져 있어요. 설정에서 켜야 알림을 받을 수 있어요.")
            } else if notificationScheduler.isEnabled {
                Text("알림을 받을 카테고리와 시점은 위에서 카테고리별로 정할 수 있어요.")
            } else {
                Text("카테고리별로 켜둔 알림도 이 스위치가 꺼져 있으면 오지 않아요.")
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
                Button("설정에서 위치 권한 허용하기") {
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
            Text("위치 권한이 없어 날씨를 가져올 수 없어요. 설정 > 개인정보 보호 및 보안 > 위치 서비스에서 허용해주세요.")
        case .serviceFailed:
            Text("날씨 정보를 가져오지 못했어요. 잠시 후 다시 시도해볼게요.")
        case .disabledByUser, .none:
            Text("압축된 주간 달력과 '오늘' 버튼에 그날의 날씨를 함께 보여줘요.")
        }
    }

    private func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    private func delete(at offsets: IndexSet) {
        guard let defaultCategory = categories.first(where: \.isDefault) else { return }
        for index in offsets {
            TodoCategory.delete(categories[index], reassigningTodosTo: defaultCategory, in: modelContext)
        }
    }
}
