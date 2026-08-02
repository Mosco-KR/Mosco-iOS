import SwiftUI

/// 튜토리얼 오버레이. 지금 눌러야 할 자리 **하나만 뚫어놓고** 나머지를 덮는다.
///
/// 예전엔 배경을 아예 안 가리거나(필수 단계) 통째로 어둡게만 했는데(설명 단계),
/// 둘 다 문제였다. 안 가리면 엉뚱한 걸 눌러 흐름에서 벗어나고, 통째로 가리면
/// 아무것도 못 누른다. 지금은 조명한 자리만 통과시키고 나머지 터치는 이 뷰가
/// 흡수한다 — 사용자가 할 수 있는 건 지금 해야 하는 그 동작 하나뿐이다.
///
/// 글도 한 번에 하나만 준다. 예전엔 세 문장을 같은 색으로 붙여놨더니 "그래서 뭘
/// 누르라는 거지"가 안 읽혔다. 지금은 **굵은 한 줄이 지시**, 그 아래 흐린 한 줄이
/// 부연이고, 부연은 없어도 되는 단계엔 아예 안 넣는다.
struct TutorialOverlayView: View {
    @Environment(TutorialManager.self) private var manager
    /// 각 대상의 화면 좌표. 아직 안 그려진 대상은 없을 수 있다.
    let rects: [TutorialTarget: CGRect]
    let screenSize: CGSize

    /// 조명 구멍 둘레 여백.
    private let holePadding: CGFloat = 8
    private let holeCornerRadius: CGFloat = 16

    var body: some View {
        if manager.isActive {
            ZStack {
                if manager.step.isCard {
                    Color.black.opacity(0.55).ignoresSafeArea()
                    card
                } else if let hole {
                    scrim(around: hole)
                    highlight(hole)
                    instruction(near: hole)
                } else {
                    // 대상 좌표를 아직 못 받았다(목록이 막 그려지는 중 등).
                    // **여기서 화면을 덮으면 안 된다** — 조명할 자리를 못 찾은 채
                    // 가림막만 깔리면 아무것도 못 눌러 사용자가 갇힌다.
                    // 안내만 띄우고 조작은 그대로 열어둔다.
                    instructionBody
                        .frame(maxHeight: .infinity, alignment: .bottom)
                        // 입력창과 탭바 위로 올려둔다 — 120pt면 입력창에 걸쳐서
                        // 안내와 입력창이 겹쳐 보였다.
                        .padding(.bottom, 170)
                        .allowsHitTesting(false)
                }
            }
            .animation(.easeInOut(duration: 0.25), value: manager.step)
            // 키보드를 따라 오버레이가 밀려 올라가면 조명 구멍이 대상에서 벗어난다.
            .ignoresSafeArea(.keyboard, edges: .bottom)
        }
    }

    private var hole: CGRect? {
        // 탭바를 가리키던 단계는 뺐다 — 시스템이 그리는 뷰라 앵커를 못 붙이고,
        // 화면 크기로 자리를 추정하면 iOS 버전·기기마다 어긋난다. 탭 세 개는
        // 하단에 늘 보이니 굳이 손잡고 안내할 것도 아니다.
        guard let target = manager.step.target else { return nil }
        guard var rect = rects[target] else { return nil }

        // 눌러야 할 것이 조명 밖에 남지 않도록, 그 단계에서 함께 뜨는 것까지 묶는다.
        switch target {
        case .composeField:
            // 입력창 위에 뜨는 시간 추천 칩.
            if let suggestion = rects[.timeSuggestion] { rect = rect.union(suggestion) }
        case .categoryButton:
            // 버튼을 누르면 그 위로 올라오는 카테고리 목록 팝업.
            if let popup = rects[.categoryPopup] { rect = rect.union(popup) }
        case .firstTodoRow:
            // 스와이프 삭제 버튼은 셀 **바깥**(행의 오른쪽 끝)에서 나타난다.
            // 셀 크기만 밝히면 정작 눌러야 할 삭제 버튼이 어두운 쪽에 남는다.
            rect = CGRect(x: 0, y: rect.minY, width: screenSize.width, height: rect.height)
        default:
            break
        }

        return rect.insetBy(dx: -holePadding, dy: -holePadding)
    }

    // MARK: - 가림막

    /// 구멍 바깥을 네 조각으로 덮는다. 각 조각이 터치를 흡수하므로 조명한 자리
    /// 말고는 아무것도 눌리지 않는다 — 마스크로 구멍만 뚫으면 그림은 되지만
    /// 터치는 그대로 통과해서 다른 버튼이 눌린다.
    private func scrim(around hole: CGRect) -> some View {
        GeometryReader { proxy in
            let full = proxy.frame(in: .local)
            ZStack(alignment: .topLeading) {
                block(x: 0, y: 0, w: full.width, h: max(hole.minY, 0))
                block(x: 0, y: hole.maxY, w: full.width, h: max(full.height - hole.maxY, 0))
                block(x: 0, y: hole.minY, w: max(hole.minX, 0), h: hole.height)
                block(x: hole.maxX, y: hole.minY, w: max(full.width - hole.maxX, 0), h: hole.height)
            }
        }
        .ignoresSafeArea()
    }

    private func block(x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat) -> some View {
        Color.black.opacity(0.55)
            .frame(width: w, height: h)
            .offset(x: x, y: y)
            .contentShape(Rectangle())
            // 흡수만 하고 아무 일도 안 한다 — "여긴 지금 누를 곳이 아니다".
            .onTapGesture {
                // 안내 단계는 읽고 아무 데나 누르면 넘어간다.
                manager.userDidAcknowledgeHint()
            }
            // 손가락을 끄는 단계에서는 아예 터치를 안 받는다. 이 뷰가 살아 있으면
            // 탭뿐 아니라 드래그도 함께 먹어서, 정작 밀어야 할 대상이 안 밀린다.
            .allowsHitTesting(manager.step.blocksInteraction)
    }

    /// 구멍 둘레의 테두리와 손짓 표시.
    private func highlight(_ hole: CGRect) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: holeCornerRadius, style: .continuous)
                .strokeBorder(MoscoPalette.accent, lineWidth: 2.5)
                .frame(width: hole.width, height: hole.height)
                .position(x: hole.midX, y: hole.midY)

            if let gesture = manager.step.gesture {
                gestureHint(gesture, in: hole)
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    /// 탭이면 퍼지는 원, 스와이프면 좌우로 오가는 화살표.
    @ViewBuilder
    private func gestureHint(_ gesture: TutorialGestureHint, in hole: CGRect) -> some View {
        switch gesture {
        case .tap:
            TapPulse()
                .position(x: hole.midX, y: hole.midY)
        case .swipeHorizontal:
            SwipeArrow(directions: [.left, .right])
                .position(x: hole.midX, y: hole.midY)
        case .longPress:
            HoldPulse()
                .position(x: hole.midX, y: hole.midY)
        case .swipeLeft:
            SwipeArrow(directions: [.left])
                // 스와이프 삭제는 오른쪽 끝에서 왼쪽으로 — 손짓도 그 자리에 둔다.
                .position(x: hole.maxX - 44, y: hole.midY)
        case .pointAt:
            PointingArrow()
                // 대상 바로 위에서 아래를 가리킨다.
                .position(x: hole.midX, y: hole.minY - 22)
        }
    }

    // MARK: - 지시문

    /// 구멍을 가리지 않는 쪽에 붙인다 — 위가 넉넉하면 위, 아니면 아래.
    ///
    /// 다만 구멍 바로 옆에 두는 것보다 **화면 끝에 닿지 않는 것**이 우선이다.
    /// 달력 격자처럼 구멍이 화면을 거의 다 차지하면 "구멍 아래"가 곧 화면 맨
    /// 밑이라, 안내가 탭바에 딱 붙어 잘린 것처럼 보였다. 위아래로 띠를 남겨두고
    /// 그 안쪽으로 잡아당긴다.
    private func instruction(near hole: CGRect) -> some View {
        GeometryReader { proxy in
            let height = proxy.size.height
            let placeAbove = hole.minY > height * 0.45
            // 아래쪽 띠가 더 넓은 건 탭바와 홈 인디케이터가 거기 있기 때문이다.
            let topBand: CGFloat = 76
            let bottomBand: CGFloat = 148
            // 안내 카드의 대략적인 높이(두 줄 기준). 끝에 닿지 않을 만큼만
            // 잡으면 되므로 정확할 필요는 없다.
            let cardHeight: CGFloat = 96

            let below = min(hole.maxY + 20, height - bottomBand - cardHeight)
            let above = min(height - hole.minY + 20, height - topBand - cardHeight)

            VStack(spacing: 0) {
                if !placeAbove { Spacer().frame(height: max(topBand, below)) }
                instructionBody
                if placeAbove { Spacer().frame(height: max(bottomBand, above)) }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: placeAbove ? .bottom : .top)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    private var instructionBody: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text("\(stepNumber)/\(actionStepCount)")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white.opacity(0.6))
                // 지시는 굵고 밝게 — 화면에서 가장 강한 글자여야 한다.
                Text(copy.action)
                    .font(.system(size: 19, weight: .bold))
                    .foregroundStyle(.white)
            }

            if let detail = copy.detail {
                Text(detail)
                    .font(.moscoCaption())
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Metrics.spacingMD)
        .background(.black.opacity(0.75), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .padding(.horizontal, Metrics.spacingMD)
    }

    /// 조작 단계 중 몇 번째인지 — 끝이 보여야 끝까지 간다.
    private var stepNumber: Int {
        // 카드(시작·장 전환·끝)는 세지 않는다 — 사용자가 세는 건 "내가 해야 할 일"이다.
        let actionSteps = TutorialManager.Step.allCases.filter { !$0.isCard }
        return (actionSteps.firstIndex(of: manager.step) ?? 0) + 1
    }

    private var actionStepCount: Int {
        TutorialManager.Step.allCases.filter { !$0.isCard }.count
    }

    private var copy: (action: String, detail: String?) {
        switch manager.step {
        case .welcome, .finish:
            ("", nil)
        case .selectDate:
            ("날짜를 눌러보세요", nil)
        case .writeWithTime:
            ("\"오후 3시 회의\"라고 적어보세요", "다 적으면 위에 시간 칩이 떠요")
        case .categoryHint:
            ("카테고리는 자동으로 정해져요", "제목을 보고 골라줘요. 직접 고르려면 이 버튼을 눌러요.\n아무 데나 누르면 넘어가요.")
        case .sendTodo:
            ("전송 버튼을 눌러보세요", nil)
        case .completeTodo:
            ("동그라미를 눌러 완료해보세요", nil)
        case .longPressTodo:
            ("할 일을 꾹 눌러보세요", "메모·디데이처럼 화면에 안 보이는 기능이 여기 있어요")
        case .deleteTodo:
            ("메뉴를 닫고, 왼쪽으로 밀어 지워보세요", nil)
        case .swipeWeek:
            ("달력을 옆으로 밀어보세요", "주 단위로 넘어가요")
        }
    }

    // MARK: - 카드(시작 · 장 전환 · 끝)

    private var cardCopy: (icon: String, title: String, message: String, button: String) {
        switch manager.step {
        case .finish:
            (
                "checkmark.seal.fill",
                "다 익히셨어요",
                "이 안내는 설정에서 다시 볼 수 있어요.",
                "완료"
            )
        default:
            (
                "hand.wave.fill",
                "Mosco에 오신 걸 환영해요",
                "밝게 표시된 곳을 따라 누르면 돼요.",
                "시작하기"
            )
        }
    }

    private var card: some View {
        VStack(spacing: Metrics.spacingMD) {
            Image(systemName: cardCopy.icon)
                .font(.system(size: 34))
                .foregroundStyle(MoscoPalette.accent)

            Text(cardCopy.title)
                .font(.moscoTitle())
                .multilineTextAlignment(.center)

            Text(cardCopy.message)
                .font(.moscoBody())
                .foregroundStyle(MoscoPalette.textSecondary)
                .multilineTextAlignment(.center)

            Button {
                manager.step == .finish ? manager.finish() : manager.advance()
            } label: {
                Text(cardCopy.button)
                    .font(.moscoBody().weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(MoscoPalette.accent, in: Capsule())
            }
            .buttonStyle(.plain)

            // 빠져나갈 문은 시작할 때만 보여준다. 도중에 계속 보이면 어려워서가
            // 아니라 그냥 눈에 띄어서 누르게 된다.
            if manager.step == .welcome {
                Button("건너뛰기", action: manager.skipAll)
                    .font(.moscoCaption())
                    .foregroundStyle(MoscoPalette.textSecondary)
            }
        }
        .padding(Metrics.spacingLG)
        .frame(maxWidth: 340)
        .background(MoscoPalette.canvas, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: .black.opacity(0.18), radius: 20, y: 8)
        .padding(.horizontal, Metrics.spacingLG)
    }
}

// MARK: - 손짓 표시

/// 꾹 눌러야 하는 자리에서 차오르는 원. 퍼져나가는 `TapPulse`와 달리 **채워지는**
/// 움직임이라 "누르고 있으라"는 뜻이 읽힌다.
private struct HoldPulse: View {
    @State private var progress: CGFloat = 0

    var body: some View {
        ZStack {
            Circle()
                .stroke(MoscoPalette.accent.opacity(0.3), lineWidth: 3)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(MoscoPalette.accent, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .frame(width: 44, height: 44)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: false)) {
                progress = 1
            }
        }
    }
}

/// 눌러야 하는 자리에서 퍼져나가는 원.
private struct TapPulse: View {
    @State private var expanded = false

    var body: some View {
        Circle()
            .stroke(MoscoPalette.accent, lineWidth: 2)
            .frame(width: 44, height: 44)
            .scaleEffect(expanded ? 1.5 : 0.8)
            .opacity(expanded ? 0 : 0.9)
            .onAppear {
                withAnimation(.easeOut(duration: 1.2).repeatForever(autoreverses: false)) {
                    expanded = true
                }
            }
    }
}

/// 아래를 가리키는 화살표 — 조작 없이 "여기를 보세요"만 말한다.
private struct PointingArrow: View {
    @State private var bobbing = false

    var body: some View {
        Image(systemName: "arrow.down")
            .font(.system(size: 24, weight: .bold))
            .foregroundStyle(MoscoPalette.accent)
            .offset(y: bobbing ? 6 : -4)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true)) {
                    bobbing = true
                }
            }
    }
}

/// 미는 손짓 — 화살표가 실제로 그 방향으로 오간다. 한 방향만 주면 그쪽으로만
/// 움직여서 "어느 쪽으로 밀라는 건지"가 분명해진다.
private struct SwipeArrow: View {
    enum Direction { case left, right }

    let directions: [Direction]
    @State private var shifted = false

    var body: some View {
        HStack(spacing: 6) {
            if directions.contains(.left) {
                Image(systemName: "chevron.left")
            }
            Image(systemName: "hand.point.up.left.fill")
            if directions.contains(.right) {
                Image(systemName: "chevron.right")
            }
        }
        .font(.system(size: 22, weight: .bold))
        .foregroundStyle(MoscoPalette.accent)
        .offset(x: offset)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                shifted = true
            }
        }
    }

    private var offset: CGFloat {
        // 왼쪽으로만 밀어야 하면 오른쪽에서 왼쪽으로 흐르게.
        if directions == [.left] { return shifted ? -22 : 12 }
        return shifted ? 26 : -26
    }
}
