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
    /// 배열을 통째로 비교하지 않고 이 번호만 본다(MonthGridView와 같은 이유).
    let blocksRevision: Int
    /// 이번 달에 속하는 칸인지(7개, weekDates와 대응) — 이전/다음 달 칸에도 막대는
    /// 똑같이 그리되(달 경계에서 일정이 뚝 끊겨 보이면 오히려 불편하다), 날짜 숫자가
    /// 흐린 것과 같은 톤으로 막대도 흐리게 해서 이번 달이 아니라는 건 유지한다.
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
            && lhs.blocksRevision == rhs.blocksRevision
            && lhs.totalRows == rhs.totalRows
    }

    private let calendar = Calendar.current
    /// 지금 누르고 있는 블록 — 블록 하나가 여러 날짜 칸(버튼)으로 나뉘어 있어서,
    /// 어느 칸을 눌렀든 블록 전체가 같이 눌린 것처럼 보이게 하려면 공유해야 한다.
    @State private var pressedBlockID: String?

    private struct Segment: Identifiable {
        let id: String
        let title: String
        let categoryColorHex: String?
        let isCompleted: Bool
        let isRepeating: Bool
        let row: Int
        let startColumn: Int
        let endColumn: Int
        let continuesBefore: Bool
        let continuesAfter: Bool
        /// 걸쳐 있는 칸이 전부 이번 달 밖이면 true — 흐린 날짜 숫자와 톤을 맞춘다.
        let isDimmed: Bool
    }

    private var segments: [Segment] {
        guard let weekEnd = weekDates.last else { return [] }

        let raw: [Segment] = positionedBlocks.compactMap { positioned in
            let block = positioned.block
            let overlapStart = max(block.start, weekStart)
            let overlapEnd = min(block.end, weekEnd)
            guard overlapStart <= overlapEnd else { return nil }
            guard
                let startColumn = weekDates.firstIndex(where: { calendar.isDate($0, inSameDayAs: overlapStart) }),
                let endColumn = weekDates.firstIndex(where: { calendar.isDate($0, inSameDayAs: overlapEnd) })
            else { return nil }

            return Segment(
                id: block.id,
                title: block.title,
                categoryColorHex: block.categoryColorHex,
                isCompleted: block.isCompleted,
                isRepeating: block.isRepeating,
                row: positioned.row,
                startColumn: startColumn,
                endColumn: endColumn,
                continuesBefore: block.start < weekStart,
                continuesAfter: block.end > weekEnd,
                // 이번 달 칸에 한 칸이라도 걸쳐 있으면 진하게 — 달 경계를 넘는
                // 일정이 중간에 톤이 바뀌며 잘려 보이지 않게 한다.
                isDimmed: !(startColumn...endColumn).contains { inMonth[$0] }
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
                categoryColorHex: segment.categoryColorHex,
                isCompleted: segment.isCompleted,
                isRepeating: segment.isRepeating,
                row: rowMap[segment.row] ?? segment.row,
                startColumn: segment.startColumn,
                endColumn: segment.endColumn,
                continuesBefore: segment.continuesBefore,
                continuesAfter: segment.continuesAfter,
                isDimmed: segment.isDimmed
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
            //
            // 블록이 없는 빈 자리는 여기서 아무 것도 그리지 않는다 — 일부러다.
            // 탭은 MonthGridView가 숫자 줄부터 이 영역 끝까지 통째로 깔아둔
            // 배경 버튼이 받는다. 블록(barView)만 자기 자리에 직접 버튼을 얹어서,
            // 블록을 정확히 누르면 그 블록의 날짜로 가는 동작이 배경 버튼보다
            // 우선하게 한다.
            VStack(alignment: .leading, spacing: 2) {
                ForEach(0..<totalRows, id: \.self) { row in
                    ZStack(alignment: .leading) {
                        ForEach(segments.filter { $0.row == row }) { segment in
                            barView(segment: segment, columnWidth: columnWidth)
                                .offset(x: columnWidth * CGFloat(segment.startColumn))
                        }
                    }
                    // 높이: MonthGridView.blockRowHeight(32)와 짝 맞는 값 — VStack
                    // spacing(2)까지 합쳐 총 높이가 정확히 rows*32-2가 되도록:
                    // 30n + 2(n-1) = 32n-2.
                    //
                    // 너비를 .infinity로 강제하는 게 중요하다 — .offset은 렌더 시점
                    // 변환이라 레이아웃 크기에 안 잡히므로, 그냥 두면 ZStack 너비가
                    // "그 줄에서 가장 넓은 블록"만큼만 된다. 그러면 2일짜리 블록이
                    // 있는 줄만 넓어지고 1일짜리뿐인 줄은 좁아져서, 부모 VStack
                    // 정렬에 따라 좁은 줄이 통째로 반 칸씩 오른쪽으로 밀린다.
                    .frame(height: 30)
                    .frame(maxWidth: .infinity, alignment: .leading)
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
        let color = segment.categoryColorHex.map(CategoryColorPalette.color(forHex:)) ?? MoscoPalette.textSecondary

        return HStack(spacing: 5) {
            if !segment.continuesBefore {
                // 인용문처럼 맨 앞에 세우는 카테고리 색 바. 반복 일정은 이 바를
                // 소문자 i 모양(점 + 막대)으로 바꿔 한 번짜리(|)와 구분한다 —
                // 별도 아이콘을 덧붙이면 가뜩이나 좁은 막대에서 제목 자리가 준다.
                VStack(spacing: 1.5) {
                    if segment.isRepeating {
                        Circle()
                            .fill(color)
                            .frame(width: 2.5, height: 2.5)
                    }
                    Capsule().fill(color)
                }
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
        // 여러 날에 걸친 블록은 손가락이 닿은 "그 날"로 가야 한다 — 예전엔 탭
        // 위치(x)를 열 너비로 나눠 계산했지만, 지금은 아예 걸쳐 있는 날짜 수만큼
        // 칸을 나눠 각 칸에 그 날짜를 아는 버튼을 얹는다. 위치 계산이 사라져
        // 정확할 뿐 아니라, 날짜 칸과 똑같이 Button의 눌림 상태를 그대로 받아
        // 누르는 동안 피드백을 줄 수 있다.
        .overlay {
            HStack(spacing: 0) {
                ForEach(segment.startColumn...segment.endColumn, id: \.self) { column in
                    Button {
                        onSelect(weekDates[column])
                    } label: {
                        Color.clear
                    }
                    .buttonStyle(BlockPressStyle(onPressingChanged: { isPressed in
                        pressedBlockID = isPressed ? segment.id : (pressedBlockID == segment.id ? nil : pressedBlockID)
                    }))
                }
            }
        }
        // 완료된 항목은 TodoRow와 같은 방식(톤 낮춤)으로 구분한다. 이번 달 밖의
        // 칸에만 있는 블록도 흐린 날짜 숫자(DayCell의 0.4)와 같은 톤으로 낮춘다.
        .opacity(segment.isCompleted ? 0.45 : (segment.isDimmed ? 0.4 : 1))
        // 날짜 칸과 같은 언어의 눌림 피드백 — 다만 블록은 가로로 긴 막대라
        // 숫자(0.88)만큼 줄이면 과하게 출렁여서, 살짝만 눌리는 정도로 잡는다.
        .scaleEffect(pressedBlockID == segment.id ? 0.96 : 1)
        .opacity(pressedBlockID == segment.id ? 0.7 : 1)
        .animation(.easeOut(duration: 0.12), value: pressedBlockID == segment.id)
    }
}

/// 블록 위에 얹는 투명 버튼 전용 스타일 — 블록 자체가 이미 유리/색을 갖고 있어서
/// 여기선 배경을 더 깔지 않고, 눌림 상태만 바깥으로 알려준다(실제 축소·페이드는
/// barView가 블록 전체에 한 번에 적용한다 — 여러 날짜 칸으로 나뉜 버튼 중
/// 하나만 따로 움직이면 블록이 찢어져 보인다).
private struct BlockPressStyle: ButtonStyle {
    var onPressingChanged: (Bool) -> Void = { _ in }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .contentShape(Rectangle())
            .onChange(of: configuration.isPressed) { _, newValue in
                onPressingChanged(newValue)
            }
    }
}
