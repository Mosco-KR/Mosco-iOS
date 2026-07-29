import SwiftUI

extension Font {
    static func moscoLargeTitle() -> Font { .system(.largeTitle, design: .default).weight(.bold) }
    static func moscoTitle() -> Font { .system(.title2, design: .default).weight(.bold) }
    static func moscoHeadline() -> Font { .system(.headline, design: .default).weight(.semibold) }
    static func moscoBody() -> Font { .system(.body, design: .default) }
    static func moscoCaption() -> Font { .system(.caption, design: .default).weight(.medium) }
}
