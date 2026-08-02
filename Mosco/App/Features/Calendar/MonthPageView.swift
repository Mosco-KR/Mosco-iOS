import SwiftUI

/// 한 달 페이지. **아무것도 계산하지 않는다** — 날짜 격자는 캐시에서, 막대 좌표는
/// 스냅샷에서 이미 확정된 채로 받아 배치만 한다.
///
/// `Equatable`이 정수·값 몇 개만 비교하는 게 중요하다. 달을 넘기는 동안 화면에
/// 올라와 있는 페이지마다 이 비교가 도는데, 배열을 통째로 비교하면 일정 수에
/// 비례하는 비용이 그대로 프레임 예산을 먹는다.
///
/// 압축(주간 스트립)은 여기서 다루지 않는다. 예전엔 이 안에서 선택된 주만 44pt로
/// 남기고 나머지 행을 0으로 접었는데, 그러면 주를 넘길 때 행이 접히고 펴지는 게
/// **세로 애니메이션**으로 보였다. 지금은 압축 상태 자체가 별도의 가로 페이저
/// (`WeekPagerView`)다.
struct MonthPageView: View, Equatable {
    let month: CalendarMonth
    let bars: MonthEventLayout
    /// 스냅샷 버전 — 막대 배열 대신 이 정수만 비교한다.
    let snapshotVersion: Int
    /// 페이지 한 장의 크기. 주 수는 달마다 다르므로 행 높이는 여기서 나눠 구한다.
    let pageSize: CGSize
    /// 오늘(startOfDay). 매 body마다 `isDateInToday`를 42번 부르지 않으려고 값으로 받는다.
    let today: Date
    let onSelect: (Date) -> Void

    static func == (lhs: MonthPageView, rhs: MonthPageView) -> Bool {
        lhs.month == rhs.month
            && lhs.snapshotVersion == rhs.snapshotVersion
            && lhs.pageSize == rhs.pageSize
            && lhs.today == rhs.today
    }

    var body: some View {
        let grid = MonthGridCache.layout(for: month)
        let metrics = MonthPageMetrics(size: pageSize, weekCount: grid.weeks.count)

        VStack(spacing: 0) {
            ForEach(Array(grid.weeks.enumerated()), id: \.offset) { index, week in
                weekRow(week, index: index, metrics: metrics)
            }
        }
        .frame(width: pageSize.width, alignment: .top)
        // 격자 자체는 터치를 받지 않는다 — 칸마다 Button을 두는 대신, 아래 깔린
        // 상호작용 레이어가 좌표를 날짜로 환산해서 처리한다(MonthPageMetrics 참고).
        .allowsHitTesting(false)
        .background(alignment: .topLeading) {
            MonthPageInteractionLayer(metrics: metrics, grid: grid, onSelect: onSelect)
        }
    }

    private func weekRow(_ week: MonthLayout.WeekRow, index: Int, metrics: MonthPageMetrics) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                ForEach(0..<7, id: \.self) { column in
                    dayCell(week: week, column: column)
                }
            }
            .frame(height: MonthPageMetrics.dayHeaderHeight)

            WeekBarsView(bars: bars.week(index), metrics: metrics)
                .equatable()
                .frame(height: metrics.barsHeight, alignment: .top)
        }
        .frame(height: metrics.rowHeight, alignment: .top)
        .clipped()
    }

    private func dayCell(week: MonthLayout.WeekRow, column: Int) -> some View {
        let date = week.dates[column]
        return DayCell(
            date: date,
            isToday: date == today,
            isDimmed: !week.inMonth[column],
            weekendKind: Self.weekendKind(column: column),
            holidayName: KoreanHoliday.name(for: date)
        )
        .frame(maxWidth: .infinity)
    }

    /// 격자의 열 순서가 곧 요일이라(일요일 시작) 날짜에서 weekday를 뽑을 필요가 없다.
    private static func weekendKind(column: Int) -> DayCell.WeekendKind? {
        switch column {
        case 0: .sunday
        case 6: .saturday
        default: nil
        }
    }
}
