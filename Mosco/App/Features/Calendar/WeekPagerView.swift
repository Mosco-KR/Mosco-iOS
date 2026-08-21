import SwiftUI

/// 주간 스트립을 좌우로 넘기는 페이저.
///
/// `MonthPagerView`와 같은 구조를 주 단위로 적용한 것이다 — 창을 고정 배열로 두고
/// `.scrollTargetBehavior(.paging)`에 맡긴다. "40pt 넘게 밀면 ±7일 점프"처럼 직접
/// 판정하면 손가락을 따라오지 않고, 주가 바뀌는 모습이 세로로 미끄러져 보였다.
///
/// **날짜를 넘기는 손짓은 이 줄 안에서만 받는다.** 페이지 본문까지 좌우 스와이프를
/// 열면 목록 셀의 스와이프 삭제와 방향이 겹쳐 서로 먹힌다
/// (`DayTodosContentView` 주석 참고).
struct WeekPagerView: View {
    let width: CGFloat
    let today: Date
    let selectedDate: Date?
    /// 각 날짜의 날씨 심볼을 찾아주는 클로저. 스트립은 한 번에 한 주(7칸)만
    /// 그리므로 값으로 미리 뽑아 넘길 이유가 없다.
    let weatherSymbol: (Date) -> String?
    /// 지금 보이는 주의 시작일(일요일). 페이징이 끝나면 여기로 올라오고,
    /// 밖에서 바꾸면 그 주로 스크롤한다.
    @Binding var visibleWeekStart: Date
    let onSelect: (Date) -> Void

    @State private var scrollTarget: Date?

    private let calendar = Calendar.current

    var body: some View {
        ScrollView(.horizontal) {
            LazyHStack(spacing: 0) {
                ForEach(WeekWindow.weekStarts, id: \.self) { weekStart in
                    strip(for: weekStart)
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.paging)
        .scrollPosition(id: $scrollTarget)
        .scrollIndicators(.hidden)
        .frame(height: WeekStripView.height)
        .onAppear {
            // 창이 오늘 주를 한가운데 두고 대칭이 아니어도(선택한 주가 어디든)
            // 여기서 한 번 맞춰두면 된다.
            scrollTarget = WeekWindow.normalized(visibleWeekStart)
        }
        .onChange(of: scrollTarget) { _, weekStart in
            guard let weekStart, weekStart != visibleWeekStart else { return }
            visibleWeekStart = weekStart
        }
        .onChange(of: visibleWeekStart) { _, weekStart in
            guard scrollTarget != weekStart else { return }
            scrollTarget = weekStart
        }
    }

    private func strip(for weekStart: Date) -> some View {
        var dates: [Date] = []
        var inMonth: [Bool] = []
        // 스트립의 흐림 처리는 "고른 날짜가 속한 달"을 기준으로 한다 — 주가 달
        // 경계를 걸칠 때 어느 쪽이 이번 달인지 알려주려는 것이다.
        let referenceMonth = selectedDate.map { CalendarMonth.containing($0) }
        var cursor = weekStart
        for _ in 0..<7 {
            dates.append(cursor)
            inMonth.append(referenceMonth.map { CalendarMonth.containing(cursor) == $0 } ?? true)
            cursor = calendar.date(byAdding: .day, value: 1, to: cursor) ?? cursor
        }

        return WeekStripView(
            dates: dates,
            inMonth: inMonth,
            width: width,
            today: today,
            selectedDate: selectedDate,
            weatherSymbols: dates.map(weatherSymbol),
            onSelect: onSelect
        )
        .frame(width: width)
    }
}

/// 페이저가 올려둘 주들. `MonthWindow`와 같은 이유로 고정 배열이다 —
/// 창을 옮기며 오프셋을 되돌리는 방식은 그 순간이 튀기 쉬운데, `LazyHStack`은
/// 화면 밖 페이지를 만들지 않으므로 창을 크게 잡아도 비용이 같다.
enum WeekWindow {
    /// 앞뒤 약 10년.
    static let radius = 520

    static let anchor: Date = normalized(Date())

    static let weekStarts: [Date] = {
        let calendar = Calendar.current
        return (-radius...radius).compactMap {
            calendar.date(byAdding: .weekOfYear, value: $0, to: anchor)
        }
    }()

    /// 그 날짜가 속한 주의 시작일(일요일 00:00).
    static func normalized(_ date: Date, calendar: Calendar = .current) -> Date {
        calendar.dateInterval(of: .weekOfYear, for: date)?.start ?? calendar.startOfDay(for: date)
    }
}
