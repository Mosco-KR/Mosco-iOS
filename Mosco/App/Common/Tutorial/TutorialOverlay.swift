import SwiftUI

/// 튜토리얼이 도는 동안 앱 위를 덮는 한 장. 앱 창이 아니라 **그 위에 얹힌 별도의
/// 창**에서 그려진다(`TutorialOverlayWindow` 참고) — 그래야 탭 바까지 덮이고,
/// 안내의 버튼이 터치를 제대로 받는다.
///
/// 하는 일은 둘이다.
///
/// 1. **어둡게 덮되 한 곳만 뚫는다.** 지금 눌러야 할 것 하나만 밝으면 설명을
///    읽지 않아도 어디를 눌러야 하는지 알 수 있다. 구멍 안쪽의 터치만 아래 앱으로
///    내려가는 일은 창이 맡는다(`hitTest`).
/// 2. **한 번에 한 가지만 시킨다.** 말풍선은 구멍의 반대쪽 절반에 세워서,
///    지금 눌러야 할 것을 절대 가리지 않는다.
struct TutorialOverlay: View {
    @Bindable var tutorial: TutorialCoordinator

    /// 엉뚱한 곳을 눌렀을 때 말풍선을 한 번 튕겨준다 — 아무 반응이 없으면
    /// 사용자는 앱이 멈춘 줄 안다.
    @State private var nudge = false

    var body: some View {
        if let step = tutorial.step {
            GeometryReader { proxy in
                // 겨누는 자리는 마스크를 안 씌우는 단계에서도 계산한다 — 구멍을
                // 뚫지 않을 뿐, 말풍선을 그 **반대쪽**에 세우는 데는 그대로 쓰인다.
                // (안 그러면 마지막 단계에서 "이 줄을 꾹 누르세요"라고 말하는 말풍선이
                // 정작 그 줄을 덮고 앉는다.)
                let target = holeRect(in: proxy)
                let hole = step.masksBackground ? target : nil
                ZStack(alignment: .topLeading) {
                    if step.masksBackground {
                        // 창이 이미 구멍 밖의 터치를 다 먹고 있다. 이 판은 그 터치에
                        // **반응**하기 위한 것이다 — 아무 일도 안 일어나면 사용자는
                        // 앱이 멈춘 줄 안다.
                        Color.clear
                            .frame(width: proxy.size.width, height: proxy.size.height)
                            .contentShape(Rectangle())
                            .onTapGesture { bounce() }

                        dimming(hole: hole, size: proxy.size, radius: step.holeRadius)
                        if let hole {
                            spotlightRing(hole, radius: step.holeRadius)
                        }
                    }
                    guidance(step: step, hole: target, size: proxy.size)
                }
                .animation(.easeInOut(duration: 0.24), value: hole)
            }
            // 키보드가 올라와도 이 장은 화면 전체를 덮은 채로 있어야 한다.
            // (키보드 자체는 이 위에 뜨는 별도 창이라 가려지지 않는다.)
            .ignoresSafeArea()
        }
    }

    /// 전역 좌표로 재어둔 자리를 이 장의 좌표로 옮긴다.
    private func holeRect(in proxy: GeometryProxy) -> CGRect? {
        guard let rect = tutorial.spotlightRect() else { return nil }
        let origin = proxy.frame(in: .global).origin
        let local = rect.offsetBy(dx: -origin.x, dy: -origin.y)
        // 화면 밖으로 나가 있는 자리는 겨누지 않는다 — 아무 데도 안 밝은 화면보다
        // 구멍이 아예 없는 편이 낫다(그때는 말풍선만 뜬다).
        let bounds = CGRect(origin: .zero, size: proxy.size)
        guard local.intersects(bounds.insetBy(dx: -20, dy: -20)) else { return nil }
        return local
    }

    // MARK: - 어둡게 덮기

    /// 화면 전체를 채우고 구멍만 도려낸다(짝수-홀수 채우기). **그리기만 한다** —
    /// 터치를 가르는 일은 창이 `hitTest`에서 같은 사각형으로 처리한다.
    private func dimming(hole: CGRect?, size: CGSize, radius: CGFloat) -> some View {
        Path { path in
            path.addRect(CGRect(origin: .zero, size: size))
            if let hole {
                path.addRoundedRect(
                    in: hole,
                    cornerSize: CGSize(width: radius, height: radius),
                    style: .continuous
                )
            }
        }
        .fill(Color.black.opacity(0.62), style: FillStyle(eoFill: true))
        .allowsHitTesting(false)
    }

    /// 밝은 자리의 테두리. 도려낸 곳이 어디까지인지 눈으로 잡히게 한다.
    private func spotlightRing(_ hole: CGRect, radius: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
            .strokeBorder(Color.white.opacity(0.85), lineWidth: 2)
            .frame(width: hole.width, height: hole.height)
            .offset(x: hole.minX, y: hole.minY)
            .allowsHitTesting(false)
    }

    // MARK: - 말풍선과 카드

    @ViewBuilder
    private func guidance(step: TutorialStep, hole: CGRect?, size: CGSize) -> some View {
        if step.isCard {
            card(step)
                .frame(width: size.width, height: size.height)
        } else {
            // 구멍이 화면 아래쪽에 있으면 위에, 위쪽에 있으면 아래에 세운다.
            // 자리를 재서 맞추는 대신 **반대쪽 절반을 통째로 쓰는** 방식이라,
            // 말풍선이 길어져도 구멍을 덮는 일이 절대 없다.
            let placeAtTop = (hole?.midY ?? size.height) > size.height / 2
            VStack(spacing: 0) {
                if !placeAtTop { Spacer(minLength: 0) }
                bubble(step)
                if placeAtTop { Spacer(minLength: 0) }
            }
            .frame(width: size.width, height: size.height, alignment: .top)
        }
    }

    private func bubble(_ step: TutorialStep) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                progressDots(current: step.chapter)
                Spacer(minLength: 0)
                Button("건너뛰기") { tutorial.skip() }
                    .font(.moscoCaption())
                    .foregroundStyle(.white.opacity(0.6))
                    .buttonStyle(.plain)
            }

            // **지시가 곧 제목이다.** 설명을 먼저 읽고 지시를 찾아야 하는 구조에서는
            // 사람들이 첫 문장에서 멈춘다 — 할 일 한 줄을 제일 크게 둔다.
            instruction(for: step)
                .font(.system(size: 19, weight: .semibold))
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)

            // 그대로 따라 적을 것은 문장에서 떼어내 크게 보여준다.
            if let sample = sample(for: step) {
                Text(sample)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .background(MoscoPalette.accent, in: Capsule())
            }

            if let checklist = step.checklist {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(checklist.enumerated()), id: \.offset) { index, item in
                        numberedRow(index + 1, item)
                    }
                }
                .padding(.top, 2)
            }

            if let hint = step.hint {
                Text(hint)
                    .font(.moscoCaption())
                    .foregroundStyle(.white.opacity(0.55))
                    .fixedSize(horizontal: false, vertical: true)
            }

            // 한참 못 넘어가고 있을 때만 나타난다. 처음부터 보이면 "그냥 눌러버리면
            // 되는 것"이 돼서, 직접 해보게 하려던 이유가 사라진다.
            if tutorial.isStuck, let assistLabel = step.assistLabel {
                Button(action: { tutorial.assist() }) {
                    HStack(spacing: 5) {
                        Image(systemName: "hand.raised.fill")
                            .font(.system(size: 10, weight: .semibold))
                        Text(assistLabel)
                            .font(.moscoCaption().weight(.semibold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.white.opacity(0.18), in: Capsule())
                }
                .buttonStyle(.plain)
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .padding(Metrics.spacingMD)
        .frame(maxWidth: .infinity, alignment: .leading)
        // **불투명해야 한다.** 반투명하게 뒀더니 뒤에 있는 화면의 날짜와 버튼
        // 글자가 안내 문구 사이로 비쳐서, 정작 읽어야 할 지시가 안 읽혔다.
        // 마스크를 안 씌우는 마지막 단계에서는 뒤가 밝아 더 심하게 비친다.
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color(white: 0.07))
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .strokeBorder(.white.opacity(0.14), lineWidth: 0.5)
                )
                .shadow(color: .black.opacity(0.35), radius: 20, y: 8)
        )
        .padding(.horizontal, Metrics.spacingMD)
        // 노치와 홈 인디케이터를 피한다 — 이 장은 안전 영역을 무시하고 있어서
        // 여백을 직접 준다.
        .padding(.top, 64)
        .padding(.bottom, 48)
        .scaleEffect(nudge ? 1.03 : 1)
        .animation(.spring(response: 0.28, dampingFraction: 0.45), value: nudge)
        // 마스크를 안 씌우는 단계에서는 창이 이 자리만 터치를 받는다.
        .background {
            GeometryReader { proxy in
                let frame = proxy.frame(in: .global)
                Color.clear
                    .onAppear { tutorial.reportGuidanceFrame(frame) }
                    .onChange(of: frame) { _, updated in
                        tutorial.reportGuidanceFrame(updated)
                    }
            }
        }
    }

    /// 지금 화면 상태에 맞는 지시 한 줄.
    ///
    /// 보내기 단계의 화살표는 글자가 아니라 **실제 버튼 아이콘**을 문장 안에 넣는다 —
    /// "보내기 버튼"이라고 쓰는 것보다 눈으로 찾는 게 빠르다.
    ///
    /// 시간만 적어 제목이 비어버린 경우처럼 정해둔 문장이 눈앞의 화면과 어긋나는
    /// 순간에는 말을 바꾼다. 누를 수 없는 버튼을 누르라고 시키는 게 제일 나쁘다.
    private func instruction(for step: TutorialStep) -> Text {
        if step == .send {
            guard tutorial.composeHasTitle else {
                return Text("할 일 이름도 한 줄 적어주세요")
            }
            return Text("오른쪽 ")
                + Text(Image(systemName: "arrow.up.circle.fill"))
                + Text(" 를 누르세요")
        }
        return Text(step.title)
    }

    /// 지시 아래에 크게 붙는 예시. 제목이 비었을 땐 시간을 뺀 이름만 보여준다.
    private func sample(for step: TutorialStep) -> String? {
        if step == .send, !tutorial.composeHasTitle { return "러닝" }
        return step.sample
    }

    /// 순서가 있는 지시 한 줄. 번호를 붙여야 "둘 다 해야 한다"가 눈에 들어온다.
    private func numberedRow(_ number: Int, _ text: String) -> some View {
        HStack(alignment: .center, spacing: 9) {
            Text("\(number)")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 20, height: 20)
                .background(MoscoPalette.accent, in: Circle())
            Text(text)
                .font(.moscoBody())
                .foregroundStyle(.white.opacity(0.92))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// 몇 걸음 중 몇 번째인지. 숫자보다 점이 낫다 — "4단계나 남았네"가 아니라
    /// "거의 다 왔네"로 읽힌다.
    private func progressDots(current: Int?) -> some View {
        HStack(spacing: 5) {
            ForEach(1...TutorialStep.chapterCount, id: \.self) { index in
                Capsule()
                    .fill(.white.opacity(index == current ? 0.95 : 0.28))
                    .frame(width: index == current ? 16 : 6, height: 6)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: current)
    }

    /// 시작과 끝의 카드. 화면 한가운데 서고, 고를 것이 버튼으로 분명히 있다.
    private func card(_ step: TutorialStep) -> some View {
        VStack(spacing: 14) {
            Image(systemName: step == .welcome ? "hand.wave.fill" : "checkmark.seal.fill")
                .font(.system(size: 30))
                .foregroundStyle(MoscoPalette.accent)

            Text(step.title)
                .font(.moscoTitle())
                .foregroundStyle(MoscoPalette.textPrimary)
                .multilineTextAlignment(.center)

            // 카드에도 한 줄만 둔다. 시작하기 전에 읽을 게 많으면 그 자리에서
            // "나중에"를 고르게 된다.
            if let hint = step.hint {
                Text(hint)
                    .font(.moscoBody())
                    .foregroundStyle(MoscoPalette.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(spacing: 8) {
                Button(step == .welcome ? "좋아요, 해볼게요" : "시작하기") {
                    if step == .welcome { tutorial.accept() } else { tutorial.finish() }
                }
                .font(.moscoBody().weight(.semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(MoscoPalette.accent, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .buttonStyle(.plain)

                // 시작 카드에만 둔다. 끝맺음에는 고를 것이 하나뿐이다.
                if step == .welcome {
                    Button("혼자 둘러볼게요") { tutorial.skip() }
                        .font(.moscoBody())
                        .foregroundStyle(MoscoPalette.textSecondary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .buttonStyle(.plain)

                    // 고르기 전에 "되돌릴 수 있다"를 알아야 편하게 고른다.
                    Text("도중에 그만둬도 설정에서 다시 볼 수 있어요")
                        .font(.moscoCaption())
                        .foregroundStyle(MoscoPalette.textSecondary.opacity(0.7))
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.top, 4)
        }
        .padding(Metrics.spacingLG)
        .frame(maxWidth: 340)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(MoscoPalette.canvas)
        )
        .shadow(color: .black.opacity(0.25), radius: 30, y: 12)
        .padding(.horizontal, Metrics.spacingLG)
        .transition(.scale(scale: 0.94).combined(with: .opacity))
    }

    private func bounce() {
        guard !nudge else { return }
        nudge = true
        Task {
            try? await Task.sleep(for: .seconds(0.22))
            nudge = false
        }
    }
}
