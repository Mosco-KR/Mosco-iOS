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
struct WeekBlockBarsView: View, Equatable {
    let weekStart: Date
    let weekDates: [Date]
    let positionedBlocks: [PositionedBlock]
    /// 이번 달에 속하는 칸인지(7개, weekDates와 대응) — 이전/다음 달로 흐려진
    /// 칸에는 막대를 그리지 않는다. 안 그러면 월 경계를 넘는 일정이 캐러셀의
    /// 이전 페이지(흐린 꼬리)와 다음 페이지(진짜 시작) 양쪽에 동시에 보여서
    /// 스와이프 중 같은 일정이 두 번 보이는 것처럼 어색해진다.
    let inMonth: [Bool]
    let totalRows: Int
    /// 블록을 탭하면 그 블록이 시작하는 날짜로 선택 진입한다 — DayCell을 탭한
    /// 것과 같은 콜백을 그대로 재사용해서, 드래그 중 탭 억제 등도 자동으로 따라온다.
    let onSelect: (Date) -> Void

    // 날짜 선택으로 다른 주(週)만 압축/복원돼도 MonthGridView 전체가 다시 그려지는데,
    // 클로저(onSelect)는 비교할 수 없으니 나머지 값만 보고 "바뀐 게 없으면 다시 안
    // 그린다" — 안 그러면 매번 이 주의 세그먼트를 다시 계산하게 된다.
    static func == (lhs: WeekBlockBarsView, rhs: WeekBlockBarsView) -> Bool {
        lhs.weekStart == rhs.weekStart
            && lhs.weekDates == rhs.weekDates
            && lhs.positionedBlocks == rhs.positionedBlocks
            && lhs.inMonth == rhs.inMonth
            && lhs.totalRows == rhs.totalRows
    }

    private let calendar = Calendar.current

    private struct Segment: Identifiable {
        let id: String
        let title: String
        let category: TodoCategory?
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
                category: block.category,
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
                category: segment.category,
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
                                // 블록이 여러 날에 걸쳐 있으면 시작일이 아니라
                                // 실제로 손가락이 닿은 칸의 날짜로 가야 한다 —
                                // 그래서 탭 위치(x)를 열 너비로 나눠 어느 날짜
                                // 칸인지 계산한다.
                                .gesture(
                                    SpatialTapGesture()
                                        .onEnded { value in
                                            let offsetColumns = Int(value.location.x / columnWidth)
                                            let column = min(
                                                max(segment.startColumn + offsetColumns, segment.startColumn),
                                                segment.endColumn
                                            )
                                            onSelect(weekDates[column])
                                        }
                                )
                        }
                    }
                    // MonthGridView.blockRowHeight(32)와 짝 맞는 값 — VStack spacing(2)까지
                    // 합쳐 총 높이가 정확히 rows*32-2가 되도록: 30n + 2(n-1) = 32n-2.
                    .frame(height: 30)
                }
            }
        }
    }

    /// 이 앱의 캘린더 블록 — 배경을 통째로 색으로 칠하는 대신, 인용문처럼 맨
    /// 앞에만 카테고리 색 세로 바를 두고 나머지는 진짜 리퀴드 글래스(moscoGlass)로
    /// 처리한다. 색이 "칠해진" 느낌 대신 유리 위에 "살짝 비치는" 느낌을 노려서,
    /// 저채도 배경 위에서도 싸구려로 안 보이게 한다. 제목이 길면 말줄임표로
    /// 자르는 대신 두 줄까지 그대로 보여준다. 이어지는 블록의 중간/끝 조각
    /// (continuesBefore)엔 이미 앞 주에서 색 바를 보여줬으니 다시 그리지 않는다.
    private func barView(segment: Segment, columnWidth: CGFloat) -> some View {
        let spanWidth = columnWidth * CGFloat(segment.endColumn - segment.startColumn + 1)
        let shape = UnevenRoundedRectangle(
            topLeadingRadius: segment.continuesBefore ? 0 : 7,
            bottomLeadingRadius: segment.continuesBefore ? 0 : 7,
            bottomTrailingRadius: segment.continuesAfter ? 0 : 7,
            topTrailingRadius: segment.continuesAfter ? 0 : 7
        )
        let color = segment.category?.color ?? MoscoPalette.textSecondary

        return HStack(spacing: 5) {
            if !segment.continuesBefore {
                Capsule()
                    .fill(color)
                    .frame(width: 2.5)
                    .padding(.vertical, 4)
            }
            Text(segment.title)
                .font(.system(size: 9, weight: .semibold))
                .strikethrough(segment.isCompleted)
                .foregroundStyle(MoscoPalette.textPrimary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .frame(width: max(spanWidth - 2, 0), height: 30, alignment: .leading)
        // moscoGlass는 배경만 유리로 깔 뿐 색을 안 입혀서, 그 "밑"에 아주 옅은
        // 카테고리 톤을 먼저 깔아둔다 — 유리를 통해 은은하게 비치는 정도로만.
        .background(color.opacity(0.12))
        .moscoGlass(in: shape)
        .overlay(shape.strokeBorder(color.opacity(0.28), lineWidth: 0.75))
        .clipShape(shape)
        // 완료된 항목은 TodoRow와 같은 방식(톤 낮춤)으로 구분한다.
        .opacity(segment.isCompleted ? 0.45 : 1)
    }
}
