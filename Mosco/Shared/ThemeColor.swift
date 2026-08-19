import SwiftUI

/// 앱 강조색. 사용자가 설정에서 고르고, **앱과 위젯이 같은 값을 본다.**
///
/// 값은 hex 문자열로 App Group에 둔다. 위젯은 별도 프로세스라
/// `UserDefaults.standard`가 안 통하고, 색 객체는 그대로 저장할 수 없다.
///
/// ## 왜 아무 색이나 그대로 쓰지 않나
///
/// 시스템 색 고르기는 흰색도 아주 연한 노랑도 고를 수 있다. 그 색이 그대로
/// 버튼 글자와 아이콘에 들어가면 **흰 배경 위에 흰 글자**가 된다 — 앱이 고장 난
/// 것처럼 보이고, 심지어 설정 화면의 '기본으로 되돌리기' 버튼조차 안 보여서
/// 빠져나올 수 없다.
///
/// 그래서 고른 색을 그대로 쓰되, **너무 밝으면 읽을 수 있을 만큼만 어둡게** 눌러
/// 쓴다. 고른 색을 거부하지 않는 것이 중요하다 — 거부하면 왜 안 되는지 설명해야
/// 하고, 설명해도 사용자는 자기가 고른 색이 왜 안 되는지 납득하기 어렵다.
nonisolated enum ThemeColor {
    /// 처음부터 쓰던 바이올렛.
    static let defaultHex = "8B5CF6"
    static let storageKey = "themeAccentHex"

    /// 강조색이 배경(흰색) 위에서 가져야 하는 최소 대비.
    ///
    /// WCAG의 큰 글자 기준(3:1)을 쓴다. 버튼 글자와 아이콘이 이 색으로 그려지는데
    /// 본문 기준(4.5:1)까지 요구하면 쓸 수 있는 색이 너무 좁아져서, 사용자가 고른
    /// 색과 실제로 칠해지는 색이 눈에 띄게 달라진다.
    static let minimumContrast = 3.0

    /// 저장된 값을 화면이 쓸 색으로. 깨졌거나 없으면 기본색이다.
    static func color(fromHex hex: String?) -> Color {
        CategoryColorPalette.color(forHex: readableHex(hex))
    }

    /// 저장할 수 있는 형태로 다듬는다 — 6자리 대문자 hex.
    static func normalize(_ hex: String) -> String? {
        let cleaned = hex
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "#", with: "")
            .uppercased()
        guard cleaned.count == 6, cleaned.allSatisfy(\.isHexDigit) else { return nil }
        return cleaned
    }

    /// 읽을 수 있을 만큼 어두운 hex. 이미 충분히 어두우면 그대로 돌려준다.
    static func readableHex(_ hex: String?) -> String {
        guard let hex, let normalized = normalize(hex) else { return defaultHex }
        var rgb = components(of: normalized)

        // 흰 배경 위에서 대비가 찰 때까지 조금씩 어둡게. 한 번에 크게 누르면
        // 고른 색과 너무 달라져서 "내가 고른 게 아닌데"가 된다.
        var guardCount = 0
        while contrastWithWhite(rgb) < minimumContrast && guardCount < 40 {
            rgb = (rgb.r * 0.92, rgb.g * 0.92, rgb.b * 0.92)
            guardCount += 1
        }
        return hexString(rgb)
    }

    /// 고른 색이 그대로 쓰이는가 — 설정 화면이 "조금 어둡게 조정했어요"를 말할지
    /// 정하는 데 쓴다. 말없이 바꿔놓으면 색을 잘못 고른 줄 안다.
    static func isAdjusted(_ hex: String) -> Bool {
        guard let normalized = normalize(hex) else { return false }
        return readableHex(normalized) != normalized
    }

    /// 기본색인가 — '되돌리기'를 보여줄지 정한다.
    static func isDefault(_ hex: String?) -> Bool {
        guard let hex, let normalized = normalize(hex) else { return true }
        return normalized == defaultHex
    }

    // MARK: - 대비 계산 (WCAG 상대 휘도)

    private static func components(of hex: String) -> (r: Double, g: Double, b: Double) {
        let value = UInt64(hex, radix: 16) ?? 0
        return (
            Double((value >> 16) & 0xFF) / 255,
            Double((value >> 8) & 0xFF) / 255,
            Double(value & 0xFF) / 255
        )
    }

    private static func hexString(_ rgb: (r: Double, g: Double, b: Double)) -> String {
        func byte(_ v: Double) -> Int { Int((v * 255).rounded().clamped(to: 0...255)) }
        return String(format: "%02X%02X%02X", byte(rgb.r), byte(rgb.g), byte(rgb.b))
    }

    /// 흰색과의 대비비. WCAG 정의를 그대로 쓴다.
    static func contrastWithWhite(_ rgb: (r: Double, g: Double, b: Double)) -> Double {
        1.05 / (luminance(rgb) + 0.05)
    }

    private static func luminance(_ rgb: (r: Double, g: Double, b: Double)) -> Double {
        func channel(_ v: Double) -> Double {
            v <= 0.03928 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * channel(rgb.r) + 0.7152 * channel(rgb.g) + 0.0722 * channel(rgb.b)
    }
}

private extension Double {
    func clamped(to range: ClosedRange<Double>) -> Double {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}
