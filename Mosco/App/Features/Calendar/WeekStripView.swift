import SwiftUI

/// 하루치 페이지 맨 위에 서는 한 줄짜리 주간 스트립.
///
/// 77d0649에서 한 번 걷어냈던 뷰다. 그때는 이게 **달력 화면이 접힌 모습**이었다 —
/// 한 화면이 달 격자와 주간 스트립을 오가니 지금 보고 있는 게 달인지 하루인지
/// 헷갈렸다. 지금은 접히는 화면이 아니라 하루치 페이지의 머리다. 달력은 뒤에
/// 그대로 남아 있고, 이 줄은 "지금 이 주의 어디를 보고 있는지"만 말한다.
///
/// 셀마다 Button을 두지 않고 좌표를 날짜로 환산한다 — 달 격자와 같은 방식이고,
/// 이유는 `CellTouchBridge`에 적혀 있다(SwiftUI 제스처는 바깥 스크롤뷰의 pan을
/// 채간다).
struct WeekStripView: View {
    let dates: [Date]
    let inMonth: [Bool]
    let width: CGFloat
    let today: Date
    let selectedDate: Date?
    let weatherSymbols: [String?]
    let onSelect: (Date) -> Void

    /// 숫자 원(30) + 위아래 여백. 이 높이에서는 공휴일 이름을 둘 자리가 없어
    /// `DayCell`이 그 줄을 접는다(`showsHolidayLabel: false`).
    static let height: CGFloat = 44

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
        .allowsHitTesting(false)
        .background {
            CellTouchBridge(
                onPressChanged: { _ in },
                onTap: { point in
                    let column = min(max(Int(point.x / max(width / 7, 1)), 0), 6)
                    guard dates.indices.contains(column) else { return }
                    onSelect(dates[column])
                },
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
