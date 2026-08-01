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
    let blocksRevision: Int
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
    /// 지금 화면에 올려둔 5개월 창의 한가운데. `displayedMonth`와 별개로 두는 게
    /// 핵심이다 — 달을 넘길 때마다 이 값을 따라 옮기면 결국 매번 새 페이지를
    /// 만들게 되므로, 스냅 애니메이션이 끝난 뒤에만 옮긴다.
    @State private var windowCenter: Date?
    private let calendar = Calendar.current
    private let tapSuppressionThreshold: CGFloat = 8
    /// 가운데 기준 앞뒤로 몇 달치를 미리 올려둘지. 2면 총 5페이지.
    private let prefetchRadius = 2

    private var isCompact: Bool { selectedRowIndex != nil }

    private var currentMonthStart: Date {
        calendar.dateInterval(of: .month, for: displayedMonth)?.start ?? displayedMonth
    }

    private var center: Date { windowCenter ?? currentMonthStart }

    /// 미리 올려둘 달들("그 달의 1일"로 정규화). 이 값이 각 페이지의 identity다 —
    /// 위치 기준으로 잡으면 달이 하나 밀릴 때 모든 칸이 "내용이 바뀐 것"으로
    /// 판정돼 페이지를 전부 다시 그린다. 달을 id로 주면 겹치는 달은 자리만
    /// 옮겨 재사용된다.
    private var monthPages: [Date] {
        (-prefetchRadius...prefetchRadius).map { offset in
            let month = calendar.date(byAdding: .month, value: offset, to: center) ?? center
            return calendar.dateInterval(of: .month, for: month)?.start ?? month
        }
    }

    /// 창 안에서 지금 보여줄 달이 몇 번째인지. 오프셋은 이 값으로 정해지므로,
    /// 달만 바뀌고 창은 그대로여도 페이지를 새로 만들지 않고 미끄러지기만 한다.
    private var currentIndex: Int {
        monthPages.firstIndex(of: currentMonthStart) ?? prefetchRadius
    }

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            ForEach(monthPages, id: \.self) { month in
                page(for: month, isCurrent: month == currentMonthStart)
            }
        }
        .offset(x: -CGFloat(currentIndex) * width + dragTranslation)
        .frame(width: width, alignment: .topLeading)
        .clipped()
        // "오늘" 버튼이나 지난달 날짜 탭처럼 달이 훌쩍 뛰면 창 밖으로 나가버린다.
        // 그때는 미룰 것 없이 바로 창을 다시 잡는다.
        .onChange(of: currentMonthStart) { _, month in
            guard !monthPages.contains(month) else { return }
            windowCenter = month
        }
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

    private func page(for month: Date, isCurrent: Bool) -> some View {
        MonthGridView(
            month: month,
            positionedBlocks: positionedBlocks,
            blocksRevision: blocksRevision,
            selectedDate: isCurrent ? selectedDate : nil,
            selectedRowIndex: isCurrent ? selectedRowIndex : nil,
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


    private func commit(direction: Int) {
        // 달을 먼저 바꾸고 그만큼 오프셋을 보정한다. 보여줄 달이 창 안에서 한 칸
        // 옮겨가면 오프셋도 한 페이지만큼 움직이는데, 같은 양을 dragTranslation에
        // 더해주면 화면에 보이는 그림은 완전히 같다 — 이 교체는 눈에 안 띈다.
        //
        // 예전엔 슬라이드가 "끝난 뒤"에 onMonthChange를 불러서, 상단 월 숫자가
        // 애니메이션이 다 끝나고서야 바뀌어 반응이 늦게 느껴졌다. 이제는 손을 떼는
        // 순간 바뀌고, 남은 잔여 오프셋만 미끄러지듯 0으로 간다.
        //
        // 이때 창(monthPages)은 그대로 두는 게 중요하다. 미리 ±2개월을 올려놨으니
        // 새로 보여줄 달은 이미 만들어져 있고, 따라서 이 프레임에 새로 그릴 페이지가
        // 없다 — 여기서 창까지 옮기면 결국 매번 새 페이지를 만들게 돼 원점이다.
        var immediate = Transaction()
        immediate.disablesAnimations = true
        withTransaction(immediate) {
            onMonthChange(direction)
            dragTranslation += CGFloat(direction) * width
        }

        // 느슨한 러버밴드 대신 딱 걸리는 스냅 느낌: 응답을 짧고 감쇠를 크게.
        withAnimation(.interactiveSpring(response: 0.28, dampingFraction: 0.92)) {
            dragTranslation = 0
        } completion: {
            recenterWindow()
            releaseDragLock()
        }
    }

    /// 애니메이션이 끝난 뒤 창을 지금 달 기준으로 다시 잡는다. 겹치는 달은
    /// identity가 같아 재사용되므로 실제로 새로 만들어지는 건 가장자리 한 달뿐이고,
    /// 그마저도 화면 밖이라 눈에 안 띈다. 창을 옮기면 currentIndex가 가운데로
    /// 돌아오면서 오프셋도 같이 바뀌는데, 페이지 배열도 같은 만큼 밀리므로
    /// 시각적으로는 아무 일도 안 일어난다 — 애니메이션 없이 처리해야 한다.
    private func recenterWindow() {
        guard currentMonthStart != center else { return }
        var immediate = Transaction()
        immediate.disablesAnimations = true
        withTransaction(immediate) {
            windowCenter = currentMonthStart
        }
    }

    /// 제스처가 끝난 직후 남아있을 수 있는 탭 이벤트까지 잠깐 더 억제한 뒤 해제한다.
    private func releaseDragLock() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            isDragging = false
        }
    }
}
