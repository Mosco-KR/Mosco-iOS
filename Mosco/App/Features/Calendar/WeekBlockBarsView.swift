import SwiftUI

/// 한 주(週) 동안 겹치는 블록들을, 미리 배정된 안정적인 행(row)에 맞춰 그린다.
/// 여러 날에 걸치면 실제로 이어진 막대로 그리고, 이번 주 시작 전부터 이어지거나
/// 다음 주로 이어지면 그쪽 모서리는 각지게 그려서 "계속 이어진다"는 느낌을 준다.
/// row는 호출부(BlockLayout.position)에서 전체 블록을 한 번에 보고 배정한 것이라,
/// 같은 일정은 주가 바뀌어도 항상 같은 줄에 그려진다.
///
/// `totalRows`는 이 페이지(월) 전체에서 실제로 쓰이는 행 수 그대로다 — 예전처럼
/// 2줄로 자르지 않고 전부 그린다. 바깥(MonthGridView)에서 이 값 기준으로 높이를
/// 잡고, 너무 많으면 스크롤 가능한 영역으로 감싼다.
struct WeekBlockBarsView: View {
    let weekStart: Date
    let weekDates: [Date]
    let positionedBlocks: [PositionedBlock]
    /// 이번 달에 속하는 칸인지(7개, weekDates와 대응) — 이전/다음 달로 흐려진
    /// 칸에는 막대를 그리지 않는다. 안 그러면 월 경계를 넘는 일정이 캐러셀의
    /// 이전 페이지(흐린 꼬리)와 다음 페이지(진짜 시작) 양쪽에 동시에 보여서
    /// 스와이프 중 같은 일정이 두 번 보이는 것처럼 어색해진다.
    let inMonth: [Bool]
    let totalRows: Int

    private let calendar = Calendar.current

    private struct Segment: Identifiable {
        let id: String
        let title: String
        let priority: Priority
        let isCompleted: Bool
        let row: Int
        let startColumn: Int
        let endColumn: Int
        let continuesBefore: Bool
        let continuesAfter: Bool
    }

    private var segments: [Segment] {
        guard let weekEnd = weekDates.last else { return [] }
        let inMonthColumns = inMonth.indices.filter { inMonth[$0] }
        guard let firstInMonth = inMonthColumns.first, let lastInMonth = inMonthColumns.last else { return [] }

        let raw: [Segment] = positionedBlocks.compactMap { positioned in
            let block = positioned.block
            let overlapStart = max(block.start, weekStart)
            let overlapEnd = min(block.end, weekEnd)
            guard overlapStart <= overlapEnd else { return nil }
            guard
                let rawStartColumn = weekDates.firstIndex(where: { calendar.isDate($0, inSameDayAs: overlapStart) }),
                let rawEndColumn = weekDates.firstIndex(where: { calendar.isDate($0, inSameDayAs: overlapEnd) })
            else { return nil }

            let startColumn = max(rawStartColumn, firstInMonth)
            let endColumn = min(rawEndColumn, lastInMonth)
            guard startColumn <= endColumn else { return nil }

            return Segment(
                id: block.id,
                title: block.title,
                priority: block.priority,
                isCompleted: block.isCompleted,
                row: positioned.row,
                startColumn: startColumn,
                endColumn: endColumn,
                continuesBefore: block.start < weekStart && startColumn == rawStartColumn,
                continuesAfter: block.end > weekEnd && endColumn == rawEndColumn
            )
        }

        // 전역 행 번호는 순서 유지용으로만 쓰고, 이 주(週) 안에서는 실제로 쓰는
        // 행만 0부터 촘촘하게 다시 매긴다 — 안 그러면 다른 주에서 깊은 행을 차지한
        // 긴 반복 일정 때문에, 이 주는 보이지도 않는 행들 자리까지 예약해서
        // 세로로 텅 빈 공간이 생긴다.
        let rowMap = Dictionary(
            uniqueKeysWithValues: Set(raw.map(\.row)).sorted().enumerated().map { ($0.element, $0.offset) }
        )
        return raw.map { segment in
            Segment(
                id: segment.id,
                title: segment.title,
                priority: segment.priority,
                isCompleted: segment.isCompleted,
                row: rowMap[segment.row] ?? segment.row,
                startColumn: segment.startColumn,
                endColumn: segment.endColumn,
                continuesBefore: segment.continuesBefore,
                continuesAfter: segment.continuesAfter
            )
        }
    }

    var body: some View {
        GeometryReader { geometry in
            let columnWidth = geometry.size.width / 7

            // row별로 자리를 항상 예약해서(빈 행은 투명), 다른 주와 세로 위치가
            // 어긋나지 않게 한다. 같은 행이라도 날짜가 안 겹치는 블록 여러 개가
            // 나란히 있을 수 있으므로, 행마다 전부 그린다 — 예전엔 first(where:)로
            // 하나만 그려서 나머지가 통째로 안 보이는 버그가 있었다.
            VStack(spacing: 2) {
                ForEach(0..<totalRows, id: \.self) { row in
                    ZStack(alignment: .leading) {
                        Color.clear

                        ForEach(segments.filter { $0.row == row }) { segment in
                            barView(segment: segment, columnWidth: columnWidth)
                                .offset(x: columnWidth * CGFloat(segment.startColumn))
                        }
                    }
                    .frame(height: 14)
                }
            }
        }
    }

    private func barView(segment: Segment, columnWidth: CGFloat) -> some View {
        let spanWidth = columnWidth * CGFloat(segment.endColumn - segment.startColumn + 1)

        return Text(segment.title)
            .font(.system(size: 9, weight: .medium))
            .strikethrough(segment.isCompleted)
            .foregroundStyle(.white)
            .lineLimit(1)
            .padding(.horizontal, 4)
            .frame(width: max(spanWidth - 2, 0), height: 14, alignment: .leading)
            .background(
                UnevenRoundedRectangle(
                    topLeadingRadius: segment.continuesBefore ? 0 : 4,
                    bottomLeadingRadius: segment.continuesBefore ? 0 : 4,
                    bottomTrailingRadius: segment.continuesAfter ? 0 : 4,
                    topTrailingRadius: segment.continuesAfter ? 0 : 4
                )
                .fill(segment.priority.color)
            )
            // 완료된 항목은 TodoRow와 같은 방식(톤 낮춤)으로 구분한다.
            .opacity(segment.isCompleted ? 0.45 : 1)
    }
}
