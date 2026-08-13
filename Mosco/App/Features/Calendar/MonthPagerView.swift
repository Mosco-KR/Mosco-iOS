import SwiftUI

/// 달을 좌우로 넘기는 페이저. 페이징을 SwiftUI(=UIScrollView)에 통째로 맡긴다.
///
/// 예전엔 3개월을 나란히 놓고 `dragTranslation`(@State)만큼 `.offset`을 주다가
/// 손을 떼면 스프링으로 스냅하는 수동 캐러셀이었다. 손가락이 움직일 때마다
/// `@State`가 바뀌니 **매 프레임 SwiftUI body가 재평가**됐고, `.clipped()`와
/// `.offset`이 그 서브트리 전체에 걸렸다. 게다가 세로 스크롤과 가로 페이징이
/// 서로 축을 뺏지 않게 하려고 UIKit 제스처 인식기를 조상 스크롤뷰에 몰래
/// 얹는 다리(`DirectionalCarouselGesture`)까지 필요했다.
///
/// `.scrollTargetBehavior(.paging)`을 쓰면 드래그 중에는 UIScrollView가 레이어를
/// 옮길 뿐, SwiftUI는 아무 일도 하지 않는다. 방향 잠금도 UIScrollView가 원래
/// 제대로 하는 일이라 다리도 필요 없다.
struct MonthPagerView: View {
    let snapshot: CalendarSnapshot
    /// 페이지 한 장의 크기. 압축/복원 애니메이션 도중에도 흔들리면 안 된다 —
    /// 이 값이 바뀌면 페이지 body가 다시 도는데, 애니메이션 프레임마다 그러면
    /// 애써 없앤 비용이 그대로 돌아온다(호출부에서 안정적인 값을 넘긴다).
    let pageSize: CGSize
    let today: Date
    /// 지금 보이는 달. 페이징이 끝나면 여기로 올라오고, 반대로 "오늘" 버튼처럼
    /// 밖에서 바꾸면 그 달로 스크롤한다.
    @Binding var visibleMonth: CalendarMonth
    let onSelect: (Date) -> Void

    @State private var scrollTarget: CalendarMonth?
    @Environment(TutorialCoordinator.self) private var tutorial: TutorialCoordinator?

    var body: some View {
        ScrollView(.horizontal) {
            LazyHStack(spacing: 0) {
                // id를 명시적으로 달 자체로 잡는다. `Identifiable` 기본 구현을 쓰면
                // 스크롤 identity가 `CalendarMonth.id`(=Int)가 돼서,
                // `scrollPosition(id:)`의 `CalendarMonth?` 바인딩과 타입이 어긋나
                // 값이 영영 올라오지 않는다(헤더의 달이 안 바뀐다).
                ForEach(MonthWindow.months, id: \.self) { month in
                    page(for: month)
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.paging)
        .scrollPosition(id: $scrollTarget)
        .scrollIndicators(.hidden)
        // 안내가 "오늘을 눌러보세요"라고 말하는 동안 달이 넘어가면 안 된다 —
        // 오늘 칸이 화면 밖으로 나가면 겨눌 자리가 사라진다. 사용자의 손가락만
        // 막고, `visibleMonth`로 옮기는 프로그램 스크롤은 그대로 둔다.
        .scrollDisabled(tutorial?.locksScroll == true)
        // 창(MonthWindow)이 오늘을 한가운데 두고 대칭이라, 가운데로 맞추면 앱을
        // 켰을 때 정확히 이번 달에 서 있게 된다. iOS 17에서 scrollPosition(id:)의
        // 초기값이 반영되지 않는 사례가 있어 초기 위치는 이쪽에 맡긴다.
        .defaultScrollAnchor(.center)
        // 이 페이저는 압축(주간 스트립)에서 돌아올 때마다 새로 만들어진다. 그때
        // scrollTarget은 nil이라 창의 한가운데(=오늘 달)에 서게 되는데, 정작 헤더가
        // 보는 visibleMonth는 다른 달일 수 있다 — 격자는 8월인데 헤더만 9월이던
        // 어긋남이 이것이었다. 나타날 때 보고 있어야 할 달로 맞춘다.
        .onAppear {
            guard scrollTarget != visibleMonth else { return }
            scrollTarget = visibleMonth
        }
        .onChange(of: scrollTarget) { _, month in
            // 페이징 도중 nil이 잠깐 올라올 수 있다 — 그건 무시한다.
            guard let month, month != visibleMonth else { return }
            visibleMonth = month
        }
        .onChange(of: visibleMonth) { _, month in
            // 밖에서 달이 바뀐 경우("오늘" 버튼, 이전/다음 달 날짜 탭)에만 스크롤한다.
            guard scrollTarget != month else { return }
            scrollTarget = month
        }
    }

    /// 모든 페이지가 같은 값을 받는다 — 페이지마다 달라지는 건 달과 그 달의 막대뿐이라,
    /// 스와이프 중에 `==`가 걸려 아무 페이지도 다시 그려지지 않는다.
    private func page(for month: CalendarMonth) -> some View {
        MonthPageView(
            month: month,
            bars: snapshot.layout(for: month),
            snapshotVersion: snapshot.version,
            pageSize: pageSize,
            today: today,
            onSelect: onSelect
        )
        .equatable()
        .frame(width: pageSize.width)
    }
}

/// 페이저가 올려둘 달들. 오늘을 한가운데 둔 **고정** 배열이다.
///
/// 재중심화(recenter)를 하지 않는 게 핵심이다. 3페이지짜리 창을 옮겨가며
/// 오프셋을 몰래 되돌리는 방식은 그 순간이 눈에 띄거나 튀기 쉬운데,
/// `LazyHStack`은 화면 밖 페이지를 아예 만들지 않으므로 창을 크게 잡아도
/// 비용이 같다 — 그래서 창을 옮길 이유 자체가 없다.
enum MonthWindow {
    /// 앞뒤 30년. 이 범위 밖으로 갈 일은 없고, 있더라도 스크롤 한계로 자연스럽다.
    static let radius = 360
    static let anchor = CalendarMonth.containing(Date())
    static let months: [CalendarMonth] = (-radius...radius).map { anchor.advanced(by: $0) }
}
