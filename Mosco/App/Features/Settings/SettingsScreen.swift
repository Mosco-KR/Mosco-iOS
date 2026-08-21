import SwiftUI
import SwiftData
import UIKit

/// 카테고리를 만들고 나면 관리(수정/삭제)할 곳이 필요하다 — QuickAddView의
/// 팝업에서 길게 눌러 고치는 경로와 별개로, 여기서 한눈에 모아보고 정리한다.
struct SettingsScreen: View {
    @Query(sort: \TodoCategory.sortOrder) private var categories: [TodoCategory]
    @Query(sort: \TodoCalendar.sortOrder) private var calendars: [TodoCalendar]
    @Environment(\.modelContext) private var modelContext
    /// 강조색은 앱과 위젯이 같은 값을 본다.
    private var theme: ThemeStore { .shared }
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(WeatherStore.self) private var weatherStore
    @Environment(TodoNotificationScheduler.self) private var notificationScheduler
    @Environment(TodoLiveActivityController.self) private var liveActivityController
    @Environment(CloudSyncStore.self) private var cloudSyncStore
    @Environment(TutorialCoordinator.self) private var tutorial: TutorialCoordinator?
    /// 카테고리·캘린더의 "새로 만들기"와 "고치기"를 전부 하나의 상태로 합쳤다.
    ///
    /// 같은 계층에 `.sheet`를 두 개 붙이면 뒤에 붙은 것만 살아난다(카테고리를 눌러도
    /// 시트가 안 뜨던 원인). 캘린더 섹션을 추가할 때 그 시트를 `Section`에 따로
    /// 붙여봤다가 같은 문제를 다시 만났다 — 시트는 하나만 두고 대상으로 가른다.
    /// 데이터 초기화는 두 단계로 확인받는다.
    @State private var showsResetFirstConfirm = false
    @State private var showsResetSecondConfirm = false
    @AppStorage(CalendarSelection.storageKey) private var hiddenCalendarIDs = ""


    var body: some View {
        NavigationStack {
            List {
                Section {
                    NavigationLink {
                        CalendarListScreen()
                    } label: {
                        SettingsEntryRow(
                            systemImage: "square.stack.3d.up",
                            title: "캘린더",
                            detail: "\(calendars.count)개"
                        )
                    }

                    NavigationLink {
                        CategoryListScreen()
                    } label: {
                        SettingsEntryRow(
                            systemImage: "tag",
                            title: "카테고리",
                            detail: "\(categories.count)개"
                        )
                    }
                } header: {
                    Text("분류")
                }

                themeSection
                tutorialSection
                notificationSection
                // 맥에는 라이브 액티비티가 없어서 스위치도 없다. 켤 수 없는 것을
                // 켜라고 두면 설정 목록이 거짓말을 한다.
                if TodoLiveActivityController.isSupported { liveActivitySection }
                weatherSection
                syncSection
                reviewSection
                resetSection
            }
            // 설정 앱에서 권한을 바꾸고 돌아왔을 수 있다 — 이 화면이 뜰 때마다 맞춘다.
            .task { await notificationScheduler.refreshAuthorizationStatus() }
            .navigationTitle("설정")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("완료") { dismiss() }
                }
            }
        }
    }



    /// 안내를 다시 보는 문.
    ///
    /// **처음에 건너뛴 사람에게 남은 유일한 길이다.** 첫 실행에 한 번 물어보고
    /// 마는 안내는, 그때 마음이 급했던 사람에게는 없는 것과 같다.
    ///
    /// 설정 시트를 먼저 닫고 시작한다 — 안내는 실제 화면 위에서 도는 것이라,
    /// 이 시트가 덮고 있으면 첫 지시부터 가려진다.
    @ViewBuilder
    private var tutorialSection: some View {
        Section {
            Button {
                dismiss()
                Task {
                    // 시트가 완전히 내려간 뒤에 시작한다.
                    try? await Task.sleep(for: .seconds(0.45))
                    tutorial?.startFromSettings()
                }
            } label: {
                Label("사용법 다시 보기", systemImage: "sparkles")
            }
        } header: {
            Text("도움말")
        } footer: {
            Text("할 일을 적고, 끝내고, 정리하는 흐름을 1분 만에 따라가 봐요.")
        }
    }

    /// 앱 전체 알림 스위치.
    ///
    /// **설명은 안 붙인다.** 스위치 옆의 이름이 이미 하는 일을 말하고 있어서,
    /// "꺼두면 알림이 오지 않아요" 같은 문장은 읽는 사람에게 아무것도 더 주지
    /// 않는다. 남기는 건 **눈에 안 보이는 사정**뿐이다 — 기기 설정에서 막혀
    /// 있다는 것처럼, 화면만 봐서는 알 수 없는 것.
    /// 사용자가 켜뒀는데 권한이 막고 있는 경우에만 안내를 띄운다.
    /// 스스로 끈 것은 의도한 상태라 아무 말도 하지 않는다.
    private var isNotificationBlocked: Bool {
        PermissionGate.isBlockedByPermission(
            userPreference: notificationScheduler.isEnabled,
            permission: notificationScheduler.permission
        )
    }

    private var isLiveActivityBlocked: Bool {
        PermissionGate.isBlockedByPermission(
            userPreference: liveActivityController.isEnabled,
            permission: liveActivityController.permission
        )
    }

    private var isWeatherBlocked: Bool {
        PermissionGate.isBlockedByPermission(
            userPreference: weatherStore.isEnabled,
            permission: weatherStore.permission
        )
    }

    /// 앱 테마 색 고르기.
    ///
    /// **고른 색을 거부하지 않는다.** 시스템 색 고르기는 흰색도 고를 수 있는데,
    /// "그 색은 안 됩니다"로 막으면 왜 안 되는지 설명해야 하고 설명해도 납득이
    /// 어렵다. 대신 읽을 수 있을 만큼만 눌러 쓰고, 눌렀다는 사실을 말한다 —
    /// 말없이 바꿔놓으면 색을 잘못 고른 줄 안다.
    @ViewBuilder
    private var themeSection: some View {
        Section {
            // **고르면 바로 바뀐다.** 한 번 '적용' 버튼을 두는 방식으로 바꿔봤다가
            // 되돌렸다 — 목록 한가운데에 버튼 두 개가 갑자기 생겼다 사라지는 것이
            // 설정 화면에서 낯설었다. 색은 되돌리기 쉬운 설정이라 확인 절차의
            // 값어치보다 그 낯섦이 컸다.
            ColorPicker(
                "색 고르기",
                selection: Binding(
                    get: { theme.accent },
                    set: { theme.select($0) }
                ),
                supportsOpacity: false
            )

            if !theme.isDefault {
                Button("처음 색으로") {
                    theme.resetToDefault()
                }
            }
        } header: {
            Text("테마 색")
        } footer: {
            // 부연은 한 문장 (`DesignSystem/README.md` 문구 원칙 3).
            if theme.isAdjusted {
                Text("고른 색이 밝아서 글자가 안 보일까 봐 조금 어둡게 했어요.")
            } else {
                Text("버튼과 달력의 오늘 표시, 위젯까지 이 색으로 바뀌어요.")
            }
        }
    }

    @ViewBuilder
    private var notificationSection: some View {
        Section {
            // **저장된 값이 아니라 실제로 동작하는지를 보여준다.** 기기 설정에서
            // 알림을 끄고 돌아오면 스위치도 꺼져 보여야 한다 — 켜져 있는데 알림은
            // 안 오는 상태가 사용자 입장에서 원인을 짐작할 방법이 없다.
            // 판정은 `PermissionGate`에 있다(테스트로 덮인다).
            Toggle("알림 받기", isOn: Binding(
                get: { notificationScheduler.isEffectivelyOn },
                set: { isOn in
                    guard isOn else {
                        notificationScheduler.isEnabled = false
                        return
                    }
                    switch PermissionGate.intent(for: notificationScheduler.permission) {
                    case .enableDirectly:
                        notificationScheduler.isEnabled = true
                    case .requestPermission:
                        Task {
                            let granted = await notificationScheduler.requestAuthorization()
                            notificationScheduler.isEnabled = granted
                        }
                    case .openSystemSettings:
                        // 한 번 거부된 권한은 앱이 다시 물을 수 없다. 여기서 요청을
                        // 시도하면 아무 일도 안 일어나고 스위치가 고장 난 것처럼 보인다.
                        openSystemSettings()
                    }
                }
            ))

            if isNotificationBlocked {
                Button("설정에서 알림 허용하기") {
                    openSystemSettings()
                }
            }
        } header: {
            Text("알림")
        } footer: {
            if isNotificationBlocked {
                Text("기기 설정에서 알림이 꺼져 있어요. 허용하면 켜둔 대로 다시 옵니다.")
            }
        }
    }

    /// 잠금화면·다이나믹 아일랜드 스위치.
    ///
    /// 시스템 설정에도 라이브 액티비티 항목이 있지만 그건 앱 전체를 끄는 것이고,
    /// 여기서는 **이 기능만** 끈다 — 알림은 받고 싶은데 잠금화면이 붐비는 건 싫은
    /// 경우가 실제로 있다. 끄면 떠 있던 것도 즉시 걷힌다.
    @ViewBuilder
    private var liveActivitySection: some View {
        Section {
            Toggle("잠금화면에 남은 시간 표시", isOn: Binding(
                get: { liveActivityController.isEffectivelyOn },
                set: { isOn in
                    guard isOn else {
                        liveActivityController.isEnabled = false
                        return
                    }
                    // 라이브 액티비티는 앱이 물어볼 수 있는 창이 없다 —
                    // 시스템 설정에서만 켠다. 그래서 요청 대신 바로 보낸다.
                    switch PermissionGate.intent(for: liveActivityController.permission) {
                    case .enableDirectly, .requestPermission:
                        liveActivityController.isEnabled = true
                    case .openSystemSettings:
                        openSystemSettings()
                    }
                }
            ))

            if isLiveActivityBlocked {
                Button("설정에서 라이브 액티비티 허용하기") {
                    openSystemSettings()
                }
            }
        } header: {
            Text("라이브 액티비티")
        } footer: {
            // 어디서 쓰는 기능인지 말해주지 않으면, 켜두고도 아무 일이 안 일어나는
            // 스위치가 된다 — 이건 켠다고 저절로 뜨는 기능이 아니다.
            if isLiveActivityBlocked {
                Text("기기 설정에서 라이브 액티비티가 꺼져 있어요.")
            } else {
                Text("목록에서 할 일을 길게 눌러 띄워요. 시작까지 8시간 안 남은 할 일에만 쓸 수 있어요.")
            }
        }
    }

    /// 날씨 표시 토글 + 못 보여주는 이유별 안내. 이유를 안 보여주면 사용자는
    /// 토글을 켰는데 아무 일도 안 일어나는 걸 버그로 여기게 된다.
    @ViewBuilder
    private var weatherSection: some View {
        Section {
            Toggle("날씨 표시", isOn: Binding(
                get: { weatherStore.isEffectivelyOn },
                set: { isOn in
                    guard isOn else {
                        weatherStore.isEnabled = false
                        return
                    }
                    switch PermissionGate.intent(for: weatherStore.permission) {
                    case .enableDirectly, .requestPermission:
                        // 아직 안 물어본 경우, 켜면 `loadIfNeeded()`가 위치 권한 창을 띄운다.
                        weatherStore.isEnabled = true
                    case .openSystemSettings:
                        openSystemSettings()
                    }
                }
            ))

            if isWeatherBlocked {
                Button("설정에서 위치 허용하기") {
                    openSystemSettings()
                }
            }

            weatherAttributionLink
        } header: {
            Text("날씨")
        } footer: {
            weatherFooter
        }
    }

    /// Apple 날씨 데이터 출처 표기.
    ///
    /// WeatherKit을 쓰면 Apple 상표( Weather)와 법적 고지 링크를 **화면에 반드시
    /// 표시해야 한다**(App Store 가이드라인 5.2.5). 없으면 리젝된다 — 실제로 1.0(3)이
    /// 이것 때문에 반려됐다.
    ///
    /// 날씨 토글을 꺼도 계속 보여준다. 심사자가 토글이 꺼진 상태로 볼 수도 있는데,
    /// 그때 출처가 사라지면 "표기가 없다"는 같은 결론으로 돌아간다.
    private var weatherAttributionLink: some View {
        Link(destination: Self.weatherAttributionURL) {
            HStack(spacing: 6) {
                // verbatim으로 넣는다 — 는 사설 영역 문자라, 지역화 문자열로
                // 다루면 다른 걸로 치환되거나 깨질 수 있다.
                Text(verbatim: "\u{F8FF} Weather")
                    .foregroundStyle(MoscoPalette.textPrimary)
                Spacer(minLength: 0)
                Text("데이터 출처")
                    .font(.footnote)
                    .foregroundStyle(MoscoPalette.textSecondary)
                Image(systemName: "arrow.up.right")
                    .font(.footnote)
                    .foregroundStyle(MoscoPalette.textSecondary)
            }
        }
    }

    /// Apple이 지정한 날씨 데이터 법적 고지 주소.
    private static let weatherAttributionURL = URL(
        string: "https://weatherkit.apple.com/legal-attribution.html"
    )!

    /// 못 가져온 이유만 남긴다. 잘 되고 있을 때는 달력에 날씨가 이미 떠 있어서
    /// 어디에 나오는지 설명할 이유가 없다.
    @ViewBuilder
    private var weatherFooter: some View {
        switch weatherStore.unavailableReason {
        case .locationDenied:
            Text("위치 권한이 없어 가져올 수 없어요.")
        case .serviceFailed:
            Text("가져오지 못했어요. 잠시 후 다시 시도할게요.")
        case .disabledByUser, .none:
            EmptyView()
        }
    }

    /// iCloud 동기화가 되고 있는지 그대로 보여준다.
    ///
    /// 켜고 끄는 토글이 아니라 **상태 표시**다 — 동기화는 앱이 정하는 게 아니라
    /// 계정과 저장소 사정으로 정해진다. 여기서 사용자가 알아야 하는 건 "이 기기의
    /// 할 일이 백업되고 있는가" 하나이고, 안 되고 있다면 앱을 지웠을 때 무슨 일이
    /// 벌어지는지까지 미리 알려주는 게 맞다.
    @ViewBuilder
    private var syncSection: some View {
        Section {
            HStack(spacing: 6) {
                Text("iCloud 동기화")
                    .foregroundStyle(MoscoPalette.textPrimary)
                Spacer(minLength: 0)
                Image(systemName: syncSymbol)
                    .font(.footnote)
                Text(syncLabel)
                    .font(.footnote)
            }
            .foregroundStyle(cloudSyncStore.state.isSyncing ? MoscoPalette.accent : MoscoPalette.textSecondary)

            // 계정이 없을 때만 설정 앱으로 보낸다 — 나머지 경우는 사용자가
            // 기기에서 할 수 있는 게 없어서, 보내봐야 헛걸음이 된다.
            if cloudSyncStore.state == .noAccount {
                Button("설정에서 iCloud 로그인하기") {
                    openSystemSettings()
                }
            }
        } header: {
            Text("백업")
        } footer: {
            syncFooter
        }
        .task { await cloudSyncStore.refresh() }
    }

    private var syncSymbol: String {
        cloudSyncStore.state.isSyncing ? "checkmark.icloud.fill" : "exclamationmark.icloud"
    }

    private var syncLabel: String {
        switch cloudSyncStore.state {
        case .active: "켜짐"
        case .noAccount: "iCloud 로그인 필요"
        case .restricted: "사용할 수 없음"
        case .localOnly: "이 기기에만 저장 중"
        case .unknown: "확인 중"
        }
    }

    /// 잘 되고 있을 때는 아무 말도 하지 않는다 — 옆의 "켜짐"이 이미 답이다.
    /// **안 되고 있을 때만** 말한다. 그때는 앱을 지우면 데이터가 사라진다는,
    /// 화면 어디에도 안 적힌 결과를 알려야 한다.
    @ViewBuilder
    private var syncFooter: some View {
        switch cloudSyncStore.state {
        case .active:
            EmptyView()
        case .noAccount:
            Text("iCloud에 로그인하지 않아 이 기기에만 저장돼요. 앱을 지우면 함께 사라집니다.")
        case .restricted:
            Text("기기 설정이 iCloud 사용을 막고 있어요. 이 기기에만 저장되며, 앱을 지우면 함께 사라집니다.")
        case .localOnly:
            Text("iCloud 저장소를 열지 못해 이 기기에만 저장하고 있어요. 앱을 지우면 함께 사라집니다.")
        case .unknown:
            EmptyView()
        }
    }

    /// 앱스토어 리뷰 작성 화면으로 가는 문.
    ///
    /// 시스템 리뷰창은 연 3회 한도가 있는 데다 **실제로 떴는지조차 알 수 없어서**,
    /// 그것 하나에 기대면 평가를 남기고 싶은 사람에게도 길이 없다. 여기는 한도를
    /// 쓰지 않고 언제 눌러도 열린다 — 두 경로가 서로의 구멍을 메운다.
    ///
    /// `Link` 대신 버튼인 건 눌린 것을 기록하기 위해서다. 시스템 창은 결과를
    /// 알려주지 않으니, 이 앱에서 리뷰 의사를 확실히 셀 수 있는 자리는 여기뿐이다.
    @ViewBuilder
    private var reviewSection: some View {
        Section {
            Button {
                openURL(ReviewPrompt.writeReviewURL)
            } label: {
                HStack(spacing: 0) {
                    Label("앱 평가하기", systemImage: "star")
                        .foregroundStyle(MoscoPalette.textPrimary)
                    Spacer(minLength: 0)
                    Image(systemName: "arrow.up.right")
                        .font(.footnote)
                        .foregroundStyle(MoscoPalette.textSecondary)
                }
                // 글자와 화살표 사이 빈 공간도 눌리게.
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        } header: {
            Text("응원하기")
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


}
