import SwiftUI

/// 가로로 채우다 폭이 모자라면 다음 줄로 넘기는 배치.
///
/// `HStack`으로는 이 일을 할 수 없다 — 한 줄에 다 넣으려 들기 때문에, 칩이 서넛만
/// 붙어도 마지막 것이 잘리거나 글자가 줄어들어 읽을 수 없게 된다. 할 일 셀의 태그
/// 줄이 정확히 그랬다: 카테고리·캘린더·기간·디데이·반복이 다 붙는 항목은 뒤쪽이
/// 사라졌고, 사라진 게 무엇인지는 열어봐야 알 수 있었다.
///
/// 줄 수는 제한하지 않는다. 넘치면 감추는 게 아니라 **줄을 늘려서 전부 보여주는**
/// 것이 이 배치의 목적이고, 태그는 종류가 정해져 있어 아무리 붙어도 두어 줄이다.
struct WrappingHStack: Layout {
    /// 같은 줄에서 칩 사이 간격.
    var spacing: CGFloat = 6
    /// 줄과 줄 사이 간격.
    var lineSpacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let limit = proposal.width ?? .infinity
        let lines = lines(within: limit, subviews: subviews)
        let width = lines.map(\.width).max() ?? 0
        let height = lines.map(\.height).reduce(0, +)
            + lineSpacing * CGFloat(max(lines.count - 1, 0))
        // 폭 제안이 있으면 그 안에 맞춘다 — 한 줄짜리일 때 제안 폭을 그대로
        // 돌려주면 태그 줄이 셀 폭을 다 먹어 정렬이 어긋난다.
        return CGSize(width: min(width, limit), height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for line in lines(within: bounds.width, subviews: subviews) {
            var x = bounds.minX
            for index in line.indices {
                let size = subviews[index].sizeThatFits(.unspecified)
                // 한 줄 안에서는 세로 가운데로 — 캡슐 칩과 아이콘은 높이가 달라서,
                // 위쪽에 맞추면 아이콘만 붕 떠 보인다.
                subviews[index].place(
                    at: CGPoint(x: x, y: y + (line.height - size.height) / 2),
                    proposal: ProposedViewSize(size)
                )
                x += size.width + spacing
            }
            y += line.height + lineSpacing
        }
    }

    private struct Line {
        var indices: [Int] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    /// 주어진 폭 안에서 칩을 줄로 나눈다. 한 칩이 혼자서도 폭을 넘으면 그 줄에
    /// 혼자 남겨둔다 — 다음 줄로 밀어봐야 거기서도 넘치고, 빈 줄만 하나 생긴다.
    private func lines(within limit: CGFloat, subviews: Subviews) -> [Line] {
        var lines: [Line] = []
        var current = Line()

        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            let extended = current.indices.isEmpty
                ? size.width
                : current.width + spacing + size.width

            if !current.indices.isEmpty, extended > limit {
                lines.append(current)
                current = Line(indices: [index], width: size.width, height: size.height)
            } else {
                current.indices.append(index)
                current.width = extended
                current.height = max(current.height, size.height)
            }
        }

        if !current.indices.isEmpty { lines.append(current) }
        return lines
    }
}
