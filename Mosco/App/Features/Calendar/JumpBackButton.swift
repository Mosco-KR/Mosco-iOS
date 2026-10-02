import SwiftUI

/// 보던 자리에서 오늘(또는 이번 달)로 돌아오는 떠 있는 버튼.
///
/// **필요할 때만 떠오른다.** 이미 오늘을 보고 있으면 돌아갈 곳이 없으니 없다 —
/// 머리에 늘 박혀 있던 '오늘' 버튼은 달력의 오늘 동그라미와 같은 말을 두 번 했다.
/// 떠 있는 요소라 글라스를 쓴다(디자인 규범: 글라스는 떠 있는 것에만).
struct JumpBackButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: "arrow.uturn.backward")
                    .font(.system(size: 13, weight: .bold))
                Text(title)
                    .font(.moscoBody().weight(.semibold))
            }
            .foregroundStyle(MoscoPalette.accent)
            .padding(.horizontal, 16)
            .frame(height: 44)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .moscoGlass(in: Capsule())
        .shadow(color: .black.opacity(0.12), radius: 12, y: 4)
        .accessibilityLabel("\(title)로 돌아가기")
    }
}

extension View {
    /// 오른쪽 아래, 입력창 바로 위에 떠오르고 가라앉는 돌아가기 버튼.
    func jumpBack(_ title: String, isShown: Bool, action: @escaping () -> Void) -> some View {
        overlay(alignment: .bottomTrailing) {
            ZStack {
                if isShown {
                    JumpBackButton(title: title, action: action)
                        .transition(.scale(scale: 0.8, anchor: .bottomTrailing).combined(with: .opacity))
                }
            }
            .padding(.trailing, Metrics.spacingMD)
            .padding(.bottom, Metrics.spacingSM)
            .animation(.spring(response: 0.32, dampingFraction: 0.82), value: isShown)
        }
    }
}
