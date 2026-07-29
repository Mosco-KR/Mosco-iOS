import SwiftUI

/// 플랫한 표면 카드. 블러/그라데이션 없이 옅은 배경색 + 헤어라인 보더로만 구분한다.
struct SurfaceCard<Content: View>: View {
    var cornerRadius: CGFloat = Metrics.cardRadius
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(Metrics.spacingLG)
            .background(MoscoPalette.surface, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(MoscoPalette.border.opacity(0.5), lineWidth: 1)
            )
    }
}
