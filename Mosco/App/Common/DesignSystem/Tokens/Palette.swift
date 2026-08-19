import SwiftUI
import UIKit

/// 앱 전반의 배경/텍스트 톤 팔레트.
/// 채도를 낮춘 톤(Toss/Apple 계열)으로, 색은 강조가 아니라 상태 구분용으로만 쓴다.
enum MoscoPalette {
    /// 주의를 끌어야 하는 곳의 빨강 — 공휴일 이름, "하루에 하기엔 많아 보여요" 배너.
    /// 이름은 MoSCoW 우선순위에서 왔지만 그 기능은 카테고리로 대체됐다.
    /// `should`/`could`/`wont`는 쓰는 곳이 없어져서 걷어냈다.
    static let must = Color(hex: 0xEF4444)

    /// 브랜드 액센트. 버튼 등 액션에만 쓴다.
    ///
    /// **사용자가 설정에서 바꿀 수 있다** (2026-08-19). 그래서 상수가 아니라
    /// 매번 읽는 값이다 — 상수로 두면 색을 바꿔도 이미 그려진 화면이 안 따라온다.
    /// 기본값은 처음부터 쓰던 바이올렛이고, 너무 밝은 색을 고르면 읽을 수 있을
    /// 만큼 눌러서 나온다 (`ThemeColor`).
    @MainActor
    static var accent: Color { ThemeStore.shared.accent }

    /// 카드가 있는 화면(리스트, 설정류)의 배경. 카드와 대비되도록 톤을 낮춘다.
    static let background = Color(uiColor: .systemGroupedBackground)
    /// 카드 없이 꽉 채우는 화면(캘린더 등)의 배경. 탭바/화면 전체와 톤이 어긋나지 않도록 플레인 배경 사용.
    static let canvas = Color(uiColor: .systemBackground)
    static let surface = Color(uiColor: .secondarySystemBackground)
    static let border = Color(uiColor: .separator)
    static let textPrimary = Color.primary
    static let textSecondary = Color.secondary
}
