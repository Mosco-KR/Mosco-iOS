import SwiftUI
import UIKit

extension Color {
    init(hex: UInt, alpha: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: alpha
        )
    }
}

/// MoSCoW 우선순위 4단계와 앱 전반의 배경/텍스트 톤 팔레트.
/// 채도를 낮춘 톤(Toss/Apple 계열)으로, 색은 강조가 아니라 상태 구분용으로만 쓴다.
enum MoscoPalette {
    static let must = Color(hex: 0xEF4444)
    static let should = Color(hex: 0xF59E0B)
    static let could = Color(hex: 0x3B82F6)
    static let wont = Color(hex: 0x94A3B8)

    /// 브랜드 액센트. 우선순위 색과 분리해 버튼 등 액션에만 사용 — 파란색은
    /// "could" 우선순위와도 겹치고 흔한 기본값이라, 좀 더 트렌디한 바이올렛으로.
    static let accent = Color(hex: 0x8B5CF6)

    /// 카드가 있는 화면(리스트, 설정류)의 배경. 카드와 대비되도록 톤을 낮춘다.
    static let background = Color(uiColor: .systemGroupedBackground)
    /// 카드 없이 꽉 채우는 화면(캘린더 등)의 배경. 탭바/화면 전체와 톤이 어긋나지 않도록 플레인 배경 사용.
    static let canvas = Color(uiColor: .systemBackground)
    static let surface = Color(uiColor: .secondarySystemBackground)
    static let border = Color(uiColor: .separator)
    static let textPrimary = Color.primary
    static let textSecondary = Color.secondary
}
