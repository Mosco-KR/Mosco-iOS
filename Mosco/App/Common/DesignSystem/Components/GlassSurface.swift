import SwiftUI

/// 리퀴드 글래스(iOS 26+)를 적용하고, 그 미만 버전은 머티리얼로 대체한다.
/// 원칙: 화면에 "떠 있는" 요소(플로팅 액션 버튼, 채팅 입력창 등)에만 서지컬하게 쓰고,
/// 카드/리스트 같은 일반 표면에는 쓰지 않는다.
struct GlassSurface<S: Shape>: ViewModifier {
    enum Variant {
        case regular
        case clear
    }

    let shape: S
    var tint: Color?
    var variant: Variant = .regular

    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            let glass: Glass = variant == .clear ? .clear : .regular
            if let tint {
                content.glassEffect(glass.tint(tint).interactive(), in: shape)
            } else {
                content.glassEffect(glass, in: shape)
            }
        } else {
            content
                .background(.ultraThinMaterial, in: shape)
                .overlay(shape.stroke(Color.white.opacity(0.12), lineWidth: 1))
        }
    }
}

extension View {
    func moscoGlass<S: Shape>(
        in shape: S,
        tint: Color? = nil,
        variant: GlassSurface<S>.Variant = .regular
    ) -> some View {
        modifier(GlassSurface(shape: shape, tint: tint, variant: variant))
    }
}
