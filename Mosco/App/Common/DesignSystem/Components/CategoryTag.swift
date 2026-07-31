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
        .background(color.opacity(0.1), in: Capsule())
    }
}
