import SwiftUI

/// 데모/스타일가이드용 우선순위 표시. 실제 도메인 모델(MoscoModels)의 Priority가
/// 생기면 그쪽 enum을 받아 색상만 매핑하는 형태로 대체될 자리.
enum DemoPriority: String, CaseIterable, Identifiable {
    case must, should, could, wont

    var id: String { rawValue }

    var color: Color {
        switch self {
        case .must: MoscoPalette.must
        case .should: MoscoPalette.should
        case .could: MoscoPalette.could
        case .wont: MoscoPalette.wont
        }
    }

    var label: String {
        switch self {
        case .must: "꼭"
        case .should: "해야"
        case .could: "여유되면"
        case .wont: "나중에"
        }
    }

    var hex: String {
        switch self {
        case .must: "#D9484E"
        case .should: "#C98A2E"
        case .could: "#3182F6"
        case .wont: "#8B95A1"
        }
    }
}

struct PriorityTag: View {
    let priority: DemoPriority

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
