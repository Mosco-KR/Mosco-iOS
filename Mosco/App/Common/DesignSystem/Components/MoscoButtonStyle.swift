import SwiftUI

struct MoscoPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        let shape = RoundedRectangle(cornerRadius: Metrics.buttonRadius, style: .continuous)

        configuration.label
            .font(.moscoHeadline())
            .foregroundStyle(.white)
            .padding(.vertical, 15)
            .frame(maxWidth: .infinity)
            .modifier(PrimaryActionSurface(shape: shape))
            .opacity(configuration.isPressed ? 0.85 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

/// 떠 있는 주요 액션(플로팅 CTA 등)에만 리퀴드 글라스를 적용하고,
/// iOS 26 미만이거나 일반 표면에서는 플랫한 색상으로 대체한다.
private struct PrimaryActionSurface<S: Shape>: ViewModifier {
    let shape: S

    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.glassEffect(.regular.tint(MoscoPalette.accent).interactive(), in: shape)
        } else {
            content.background(MoscoPalette.accent, in: shape)
        }
    }
}

extension ButtonStyle where Self == MoscoPrimaryButtonStyle {
    static var moscoPrimary: MoscoPrimaryButtonStyle { MoscoPrimaryButtonStyle() }
}
