import SwiftUI

/// 날짜를 골랐을 때 상단에 남는 한 줄짜리 주간 스트립.
///
/// 예전엔 이게 `MonthPageView` 안에 있었다 — 한 달의 주 행을 전부 VStack에 둔 채
/// 선택된 행만 44pt로 펴고 나머지를 0으로 접는 방식이었다. 그래서 주를 넘기면
/// 3번째 행이 접히고 4번째 행이 펴지면서 **세로로 미끄러지는** 것처럼 보였다.
/// 이제는 주 자체가 페이지라서 가로로 넘어간다(`WeekPagerView`).
struct WeekStripView: View {
    let dates: [Date]
    let inMonth: [Bool]
    let width: CGFloat
    let today: Date
    let selectedDate: Date?
    let weatherSymbols: [String?]
    let onSelect: (Date) -> Void
    /// 아래로 끌어내리면 전체 달력으로 돌아간다.
    let onPullDown: () -> Void

    static let height = MonthPageMetrics.compactRowHeight

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(dates.enumerated()), id: \.offset) { column, date in
                DayCell(
                    date: date,
                    isToday: date == today,
                    isSelected: selectedDate == date,
                    isDimmed: !(inMonth.indices.contains(column) && inMonth[column]),
                    weekendKind: Self.weekendKind(column: column),
                    holidayName: KoreanHoliday.name(for: date),
                    // 44pt 한 줄엔 공휴일 이름을 둘 자리가 없다 — 대신 그 자리에
                    // 날씨를 숫자 원 모서리에 얹는다(DayCell 쪽에서 처리).
                    showsHolidayLabel: false,
                    weatherSymbol: weatherSymbols.indices.contains(column) ? weatherSymbols[column] : nil
                )
                .frame(maxWidth: .infinity)
            }
        }
        .frame(width: width, height: Self.height)
        // 격자와 같은 방식 — 셀마다 Button을 두지 않고 좌표를 날짜로 환산한다.
        .allowsHitTesting(false)
        .background {
            CellTouchBridge(
                onPressChanged: { _ in },
                onTap: { point in
                    let column = min(max(Int(point.x / max(width / 7, 1)), 0), 6)
                    guard dates.indices.contains(column) else { return }
                    onSelect(dates[column])
                },
                onPullDown: onPullDown,
                isEnabled: true
            )
        }
    }

    /// 열 순서가 곧 요일이다(일요일 시작).
    private static func weekendKind(column: Int) -> DayCell.WeekendKind? {
        switch column {
        case 0: .sunday
        case 6: .saturday
        default: nil
        }
    }
}
