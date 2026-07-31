import SwiftUI

extension TodoCategory {
    var color: Color {
        CategoryColorPalette.color(forHex: colorHex)
    }
}
