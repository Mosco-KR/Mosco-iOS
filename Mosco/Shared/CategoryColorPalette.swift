import SwiftUI

/// 위젯 타겟도 카테고리 색을 그려야 해서, hex 이니셜라이저는 앱 전용 팔레트가
/// 아니라 공유 소스에 둔다.
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

/// 카테고리를 만들 때 고르는 기본 16색. 채도 있는 트렌디한 톤으로, 서로
/// 구별이 잘 되도록 색상환을 고르게 훑는다. 색은 hex로 저장해서 Category가
/// SwiftUI를 몰라도 되게 한다(모델은 순수 데이터로 유지).
enum CategoryColorPalette {
    /// 앱 테마 색. 앱 쪽은 `MoscoPalette.accent`로 쓰지만 그건 앱 타깃에만 있어서,
    /// 위젯과 라이브 액티비티는 여기를 본다 — 잠금화면의 '오늘' 표시가 시스템 기본
    /// 파랑으로 나오던 게 이걸 안 두고 `Color.accentColor`를 쓴 탓이었다.
    ///
    /// 기본값은 `ThemeColor.defaultHex` 하나뿐이다. 예전엔 여기에도 같은 hex를
    /// 따로 적어뒀는데, 두 곳에 있으면 한쪽만 바뀌어 앱과 위젯 색이 갈라진다.
    ///
    /// **사용자가 고른 색을 따라간다** (2026-08-19). 위젯도 App Group에서 같은
    /// 값을 읽으므로 앱과 홈 화면의 강조색이 갈라지지 않는다. 못 읽으면 기본색이다.
    static var accent: Color {
        let stored = UserDefaults(suiteName: SharedModelContainer.appGroupID)?
            .string(forKey: ThemeColor.storageKey)
        return color(forHex: ThemeColor.readableHex(stored))
    }

    static let hexValues: [String] = [
        "F43F5E", // 로즈
        "FB923C", // 오렌지
        "FBBF24", // 앰버
        "EAB308", // 옐로
        "A3E635", // 라임
        "34D399", // 그린
        "10B981", // 에메랄드
        "2DD4BF", // 틸
        "22D3EE", // 시안
        "38BDF8", // 스카이
        "60A5FA", // 블루
        "818CF8", // 인디고
        "A78BFA", // 바이올렛
        "C084FC", // 퍼플
        "F472B6", // 핑크
        "94A3B8"  // 슬레이트(중립)
    ]

    static func color(forHex hex: String) -> Color {
        Color(hex: UInt(hex, radix: 16) ?? 0x94A3B8)
    }

    /// 새 카테고리를 만들 때 기본으로 내미는 색 — 이미 쓰인 색과 겹치지 않게
    /// 순환시켜서, 연달아 만들어도 색이 다양하게 나온다.
    static func nextDefault(avoiding usedHexValues: [String]) -> String {
        hexValues.first { !usedHexValues.contains($0) } ?? hexValues[usedHexValues.count % hexValues.count]
    }
}
