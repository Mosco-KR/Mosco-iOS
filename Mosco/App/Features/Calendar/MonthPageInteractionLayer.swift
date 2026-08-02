import SwiftUI

/// 달 페이지의 터치를 전부 받는 한 장의 레이어. 페이지 뒤에 깔리고, 앞의 격자는
/// `allowsHitTesting(false)`라 터치가 그대로 여기까지 내려온다.
///
/// 예전엔 칸마다 투명 `Button`을 뒀다 — 페이지당 42개, 게다가 막대마다 걸친 날짜
/// 수만큼 또 얹혔고, 각 버튼이 `RoundedRectangle` 배경과 `.animation` 수식어를
/// 하나씩 달고 있었다. 페이지 높이가 고정이라 좌표에서 날짜를 나눗셈 두 번으로
/// 구할 수 있으니(`MonthPageMetrics.position`), 그 뷰들이 전부 필요 없다.
///
/// 눌림 상태를 이 뷰 **안에** 가두는 것도 핵심이다. 예전엔 눌린 날짜를 부모
/// `@State`에 뒀는데, 그러면 칸을 누를 때마다 부모 body가 통째로 재평가돼 격자가
/// 전부 다시 만들어졌다 — 스와이프는 손가락이 칸을 누르며 시작해 드래그로 바뀌며
/// 취소되므로, 스와이프 한 번에 그 재구성이 두 번 일어났다.
///
/// 실제 터치 인식은 `CellTouchBridge`(UIKit)가 맡는다 — SwiftUI 제스처로는 한 손가락
/// 스와이프가 페이징을 못 하게 막는 문제가 있었다. 자세한 이유는 그쪽 주석 참고.
struct MonthPageInteractionLayer: View {
    let metrics: MonthPageMetrics
    let grid: MonthLayout
    let onSelect: (Date) -> Void

    @State private var pressed: GridPosition?

    var body: some View {
        CellTouchBridge(
            onPressChanged: { point in
                pressed = point.map { metrics.position(at: $0) }
            },
            onTap: { point in
                guard let date = date(at: point) else { return }
                onSelect(date)
            },
            isEnabled: true
        )
        .frame(width: metrics.size.width, height: metrics.size.height)
        .overlay(alignment: .topLeading) { highlight }
        .animation(.easeOut(duration: 0.12), value: pressed)
    }

    @ViewBuilder
    private var highlight: some View {
        if let pressed {
            let frame = metrics.frame(of: pressed)
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(MoscoPalette.accent.opacity(0.08))
                .frame(width: frame.width, height: frame.height)
                .offset(x: frame.minX, y: frame.minY)
                .allowsHitTesting(false)
        }
    }

    private func date(at point: CGPoint) -> Date? {
        let position = metrics.position(at: point)
        guard grid.weeks.indices.contains(position.week) else { return nil }
        let week = grid.weeks[position.week]
        guard week.dates.indices.contains(position.column) else { return nil }
        return week.dates[position.column]
    }
}
