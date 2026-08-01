import SwiftUI

/// 튜토리얼 카드 하나를 그린다. 필수 단계(날짜 선택 · 시간 자동 인식 · 할 일
/// 추가 · 삭제)는 배경을 안 가리고 살짝 떠 있는 안내문만 보여줘서,
/// 사용자가 실제 달력/입력창/목록을 그대로 조작할 수 있게 한다. 나머지 단계는
/// 배경을 살짝 어둡게 깔고 가운데 카드로 설명 + "다음"/"건너뛰기"를 준다.
struct TutorialOverlayView: View {
    @Environment(TutorialManager.self) private var manager

    var body: some View {
        if manager.isActive {
            GeometryReader { geometry in
                ZStack {
                    if !manager.step.isEssential {
                        Color.black.opacity(0.35)
                            .ignoresSafeArea()
                            .transition(.opacity)
                    }

                    content(for: manager.step, safeAreaTop: geometry.safeAreaInsets.top)
                }
                // allowsHitTesting(false)는 부모가 걸면 자식이 다시 켤 수 없는
                // 단방향 게이트다 — 그래서 카드에 버튼이 있는 비필수 단계는 아예
                // 안 걸어서(기본값=터치 받음) 버튼이 눌리게 하고, 버튼이 없는
                // 필수 단계(배너)만 통째로 꺼서 뒤의 달력/입력창이 눌리게 한다.
                .allowsHitTesting(!manager.step.isEssential)
            }
            .transition(.opacity)
            .animation(.easeInOut(duration: 0.25), value: manager.step)
        }
    }

    @ViewBuilder
    private func content(for step: TutorialManager.Step, safeAreaTop: CGFloat) -> some View {
        switch step {
        case .welcome:
            centeredCard(
                icon: "hand.wave.fill",
                title: "Mosco에 오신 걸 환영해요",
                message: "달력과 할 일을 한 곳에서 관리해요. 짧은 튜토리얼로 핵심 기능을 직접 눌러보면서 익혀볼게요.",
                primaryLabel: "시작하기",
                onPrimary: manager.advance,
                onSkip: manager.skipAll
            )
        case .selectDate:
            topBanner(
                title: "날짜를 눌러보세요",
                message: "달력에서 아무 날짜나 탭하면 그날의 할 일 목록이 펼쳐져요.",
                topInset: safeAreaTop
            )
        case .timeDetection:
            bottomBanner(
                title: "시간이 담긴 할 일을 적어보세요",
                message: "예를 들어 \"오후 3시 회의\"처럼 시간을 넣어 적어보세요. 시간을 자동으로 알아채고 추천 칩을 보여줘요. 칩을 탭하면 바로 적용돼요."
            )
        case .addTodo:
            bottomBanner(
                title: "이제 전송해보세요",
                message: "입력창 오른쪽의 전송 버튼을 누르면 할 일이 저장돼요."
            )
        case .deleteTodo:
            topBanner(
                title: "방금 만든 할 일을 지워볼까요",
                message: "목록에서 할 일을 왼쪽으로 밀면 삭제 버튼이 나와요. 눌러서 지워보세요.",
                topInset: safeAreaTop
            )
        case .autoCategory:
            centeredCard(
                icon: "sparkles",
                title: "카테고리 자동 추천",
                message: "제목을 다 적으면 잠깐 멈추는 사이에 어울리는 카테고리를 알아서 추천해줘요. 카테고리 점의 색이 바뀌면 추천이 반영된 거예요.",
                primaryLabel: "다음",
                onPrimary: manager.advance,
                onSkip: manager.skipAll
            )
        case .manualCategory:
            centeredCard(
                icon: "circle.grid.2x2.fill",
                title: "직접 고르거나 새로 만들기",
                message: "입력창 오른쪽의 동그란 버튼을 누르면 만들어둔 카테고리 중에서 고를 수 있어요. + 버튼으로는 이름과 색을 정해 새 카테고리를 바로 만들 수 있어요.",
                primaryLabel: "다음",
                onPrimary: manager.advance,
                onSkip: manager.skipAll
            )
        case .scheduleDetail:
            centeredCard(
                icon: "clock.fill",
                title: "시간과 반복 설정",
                message: "왼쪽 날짜 칩을 누르면 시작·종료 시간, 종료일, 반복 규칙까지 자세히 정할 수 있어요.",
                primaryLabel: "다음",
                onPrimary: manager.advance,
                onSkip: manager.skipAll
            )
        case .completeTodo:
            centeredCard(
                icon: "checkmark.circle.fill",
                title: "완료 체크",
                message: "할 일 왼쪽의 동그라미를 누르면 완료로 표시돼요. 다시 누르면 되돌릴 수 있어요.",
                primaryLabel: "다음",
                onPrimary: manager.advance,
                onSkip: manager.skipAll
            )
        case .todoTab:
            centeredCard(
                icon: "list.bullet",
                title: "오늘 할 일 탭",
                message: "하단의 \"오늘 할 일\" 탭에서 오늘 처리할 일들을 카테고리별로 모아볼 수 있어요.",
                primaryLabel: "다음",
                onPrimary: manager.advance,
                onSkip: manager.skipAll
            )
        case .finish:
            centeredCard(
                icon: "party.popper.fill",
                title: "준비 완료!",
                message: "핵심 기능을 모두 둘러봤어요. 이제 자유롭게 Mosco를 사용해보세요.",
                primaryLabel: "시작하기",
                onPrimary: manager.finish,
                onSkip: nil
            )
        }
    }

    // MARK: - 레이아웃 조각

    private func topBanner(title: String, message: String, topInset: CGFloat) -> some View {
        VStack {
            bannerBody(title: title, message: message)
                .padding(.horizontal, Metrics.spacingMD)
                .padding(.top, topInset + Metrics.spacingSM)
            Spacer()
        }
    }

    private func bottomBanner(title: String, message: String) -> some View {
        VStack {
            Spacer()
            bannerBody(title: title, message: message)
                .padding(.horizontal, Metrics.spacingMD)
                // 컴포즈 바(입력창)를 가리지 않도록 그 위쪽에 띄운다.
                .padding(.bottom, 96)
        }
    }

    private func bannerBody(title: String, message: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: "hand.tap.fill")
                    .foregroundStyle(MoscoPalette.accent)
                Text(title)
                    .font(.moscoBody().weight(.semibold))
            }
            Text(message)
                .font(.moscoCaption())
                .foregroundStyle(MoscoPalette.textSecondary)
        }
        .padding(Metrics.spacingMD)
        .frame(maxWidth: .infinity, alignment: .leading)
        .moscoGlass(in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: .black.opacity(0.12), radius: 12, y: 4)
    }

    private func centeredCard(
        icon: String,
        title: String,
        message: String,
        primaryLabel: String,
        onPrimary: @escaping () -> Void,
        onSkip: (() -> Void)?
    ) -> some View {
        VStack(spacing: Metrics.spacingMD) {
            Image(systemName: icon)
                .font(.system(size: 34))
                .foregroundStyle(MoscoPalette.accent)

            Text(title)
                .font(.moscoTitle())
                .multilineTextAlignment(.center)

            Text(message)
                .font(.moscoBody())
                .foregroundStyle(MoscoPalette.textSecondary)
                .multilineTextAlignment(.center)

            Button(action: onPrimary) {
                Text(primaryLabel)
                    .font(.moscoBody().weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(MoscoPalette.accent, in: Capsule())
            }
            .buttonStyle(.plain)

            if let onSkip {
                Button("건너뛰기", action: onSkip)
                    .font(.moscoCaption())
                    .foregroundStyle(MoscoPalette.textSecondary)
            }
        }
        .padding(Metrics.spacingLG)
        .frame(maxWidth: 340)
        .moscoGlass(in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: .black.opacity(0.18), radius: 20, y: 8)
        .padding(.horizontal, Metrics.spacingLG)
    }
}
