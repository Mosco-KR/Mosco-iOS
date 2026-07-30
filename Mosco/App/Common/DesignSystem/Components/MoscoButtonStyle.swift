import SwiftUI

struct MoscoPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        let shape = RoundedRectangle(cornerRadius: Metrics.buttonRadius, style: .continuous)

        configuration.label
            .font(.moscoHeadline())
            .foregroundStyle(.white)
            .padding(.vertical, 15)
            .frame(maxWidth: .infinity)
            .moscoGlass(in: shape, tint: MoscoPalette.accent)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == MoscoPrimaryButtonStyle {
    static var moscoPrimary: MoscoPrimaryButtonStyle { MoscoPrimaryButtonStyle() }
}
