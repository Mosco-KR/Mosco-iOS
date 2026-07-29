import SwiftUI

/// 우선순위/시간 등 짧은 메타데이터를 표시하는 캡슐형 칩.
/// 아이콘 없이 톤온톤 배경 + 텍스트만으로 절제된 느낌을 유지한다.
struct TagChip: View {
    let label: String
    let tint: Color

    var body: some View {
        Text(label)
            .font(.moscoCaption())
            .foregroundStyle(tint)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(tint.opacity(0.12), in: Capsule())
    }
}
