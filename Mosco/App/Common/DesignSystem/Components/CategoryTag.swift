import SwiftUI

/// nil이면 아직 분류되지 않은 할 일 — 중립 회색으로 "미분류"를 보여준다.
struct CategoryTag: View {
    let category: TodoCategory?

    private var color: Color {
        category?.color ?? MoscoPalette.textSecondary
    }

    private var label: String {
        category?.name ?? "미분류"
    }

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(color)
                .frame(width: 5, height: 5)
            Text(label)
                .font(.moscoCaption())
        }
        .foregroundStyle(color)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        // TagChip과 같은 알파를 쓴다 — 한 줄에 나란히 서는 칩끼리 배경 농도가
        // 다르면 같은 종류로 안 읽힌다.
        .background(color.opacity(0.12), in: Capsule())
    }
}
