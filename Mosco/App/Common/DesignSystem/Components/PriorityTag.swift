import SwiftUI

struct PriorityTag: View {
    let priority: Priority

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(priority.color)
                .frame(width: 5, height: 5)
            Text(priority.label)
                .font(.moscoCaption())
        }
        .foregroundStyle(priority.color)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(priority.color.opacity(0.1), in: Capsule())
    }
}
