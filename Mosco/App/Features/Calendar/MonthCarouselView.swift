import SwiftUI

/// 이전/현재/다음 달을 좌우로 나란히 두고 드래그만큼 따라 움직이다, 손을 떼면
/// 한 페이지 분량으로 딱 스냅한다. 스냅이 끝나면 displayedMonth를 갱신하고
/// 오프셋을 원위치로 되돌려 이음매 없이 이어지게 한다.
///
/// 세로 스크롤은 이 뷰 바깥(CalendarScreen)의 단일 ScrollView가 맡는다 —
/// 페이지 안에 스크롤을 넣으면 UIScrollView가 가로 드래그까지 가로채서
/// 달 넘기기 인식이 나빠지고, 페이지별 스크롤 위치가 따로 놀게 된다.
struct MonthCarouselView: View {
    /// 페이지(한 달) 너비. 바깥 ScrollView 안에서는 GeometryReader를 쓸 수
    /// 없어서 호출부가 계산해 넘긴다.
    let width: CGFloat
    let displayedMonth: Date
    let positionedBlocks: [PositionedBlock]
    /// 지금 선택된 날짜(빈 동그라미 표시용) — "현재" 페이지에만 전달한다.
    let selectedDate: Date?
    /// nil이 아니면 "현재" 페이지가 이 주(週) 행만 남기고 접힌다 — 압축 중엔
    /// 달 넘기기 스와이프도 의미가 없으니 함께 비활성화한다.
    let selectedRowIndex: Int?
    let onSelect: (Date) -> Void
    let onMonthChange: (Int) -> Void

    @State private var dragTranslation: CGFloat = 0
    /// 실제로 "밀었다"고 판단되는 순간부터 true. 짧은 탭이 스와이프 도중
    /// 날짜 선택으로 잘못 처리되는 것을 막는 용도(값 자체는 애니메이션에 안 씀).
    @State private var isDragging = false
    private let calendar = Calendar.current
    private let tapSuppressionThreshold: CGFloat = 8

    private var isCompact: Bool { selectedRowIndex != nil }

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            page(for: adjacentMonth(-1), role: nil)
            page(for: displayedMonth, role: "current")
            page(for: adjacentMonth(1), role: nil)
        }
        .offset(x: -width + dragTranslation)
        .frame(width: width, alignment: .topLeading)
        .clipped()
        // SwiftUI DragGesture(+simultaneousGesture)로는 버튼/블록 위에서 시작한
        // 터치가 세로 스크롤을 막고, 빈 영역에서 시작한 터치는 가로 페이징을
        // 못 가져가는 비대칭이 있었다 — 방향이 갈리는 순간 진 쪽 인식기를 UIKit
        // 레벨에서 직접 취소해야 하므로 이 다리를 통해 처리한다.
        .background(
            DirectionalCarouselGesture(
                isEnabled: !isCompact,
                onChanged: { dx in
                    dragTranslation = dx
                    if !isDragging && abs(dx) > tapSuppressionThreshold {
                        isDragging = true
                    }
                },
                onEnded: { dx in
                    let threshold = width * 0.18
                    if dx < -threshold {
                        commit(direction: 1)
                    } else if dx > threshold {
                        commit(direction: -1)
                    } else {
                        withAnimation(.interactiveSpring(response: 0.25, dampingFraction: 0.9)) {
                            dragTranslation = 0
                        }
                        releaseDragLock()
                    }
                }
            )
        )
    }

    private func page(for month: Date, role: String?) -> some View {
        MonthGridView(
            month: month,
            positionedBlocks: positionedBlocks,
            selectedDate: role == "current" ? selectedDate : nil,
            selectedRowIndex: role == "current" ? selectedRowIndex : nil,
            onSelect: handleSelect
        )
        .equatable()
        .frame(width: width)
    }

    /// 스와이프 도중이면 날짜 탭을 무시한다.
    private func handleSelect(_ day: Date) {
        guard !isDragging else { return }
        onSelect(day)
    }

    private func adjacentMonth(_ delta: Int) -> Date {
        calendar.date(byAdding: .month, value: delta, to: displayedMonth) ?? displayedMonth
    }

    private func commit(direction: Int) {
        // 느슨한 러버밴드 대신 딱 걸리는 스냅 느낌: 응답을 짧고 감쇠를 크게.
        withAnimation(.interactiveSpring(response: 0.28, dampingFraction: 0.92)) {
            dragTranslation = direction > 0 ? -width : width
        } completion: {
            dragTranslation = 0
            onMonthChange(direction)
            releaseDragLock()
        }
    }

    /// 제스처가 끝난 직후 남아있을 수 있는 탭 이벤트까지 잠깐 더 억제한 뒤 해제한다.
    private func releaseDragLock() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            isDragging = false
        }
    }
}
