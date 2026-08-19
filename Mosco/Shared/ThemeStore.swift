import Foundation
import Observation
import SwiftUI
import WidgetKit

/// 사용자가 고른 강조색을 들고 있는 곳.
///
/// **App Group에 저장한다.** 위젯은 별도 프로세스라 `UserDefaults.standard`를
/// 못 읽는다 — 앱에서 색을 바꿨는데 홈 화면 위젯만 예전 색으로 남으면 그게 더
/// 어색하다.
@Observable
@MainActor
final class ThemeStore {
    static let shared = ThemeStore()

    /// 사용자가 고른 값 그대로. 화면에 칠할 때는 `accent`를 쓴다.
    private(set) var selectedHex: String

    private let defaults: UserDefaults

    private init() {
        defaults = UserDefaults(suiteName: SharedModelContainer.appGroupID) ?? .standard
        selectedHex = defaults.string(forKey: ThemeColor.storageKey) ?? ThemeColor.defaultHex
    }

    /// 실제로 화면에 칠하는 색 — 너무 밝으면 읽을 수 있을 만큼 눌러서 나온다.
    var accent: Color { ThemeColor.color(fromHex: selectedHex) }

    /// 고른 색이 그대로 쓰이는지. 아니면 설정 화면이 그 사실을 말한다.
    var isAdjusted: Bool { ThemeColor.isAdjusted(selectedHex) }

    var isDefault: Bool { ThemeColor.isDefault(selectedHex) }

    func select(_ color: Color) {
        guard let hex = ThemeColor.normalize(color.hexString) else { return }
        apply(hex)
    }

    /// 처음 색으로.
    func resetToDefault() {
        apply(ThemeColor.defaultHex)
    }

    private func apply(_ hex: String) {
        guard hex != selectedHex else { return }
        selectedHex = hex
        defaults.set(hex, forKey: ThemeColor.storageKey)
        // 위젯은 자정에만 스스로 다시 그린다 — 색을 바꿨는데 홈 화면이 하루 종일
        // 예전 색이면 안 바뀐 걸로 보인다.
        WidgetCenter.shared.reloadAllTimelines()
    }
}

extension Color {
    /// SwiftUI Color에서 6자리 hex를 뽑는다. ColorPicker가 주는 값을 저장하려면
    /// 필요하다 — Color 자체는 저장할 수 없다.
    var hexString: String {
        #if canImport(UIKit)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(self).getRed(&r, green: &g, blue: &b, alpha: &a)
        return String(
            format: "%02X%02X%02X",
            Int((r * 255).rounded()), Int((g * 255).rounded()), Int((b * 255).rounded())
        )
        #else
        return ThemeColor.defaultHex
        #endif
    }
}
