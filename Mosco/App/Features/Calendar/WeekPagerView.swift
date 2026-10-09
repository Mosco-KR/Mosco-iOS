import SwiftUI

/// 하루치 페이지 맨 위에 서는 주간 스트립.
///
/// 77d0649에서 한 번 걷어냈던 줄이다. 그때는 이게 **달력 화면이 접힌 모습**이었다 —
/// 한 화면이 달 격자와 주간 스트립을 오가니 지금 보고 있는 게 달인지 하루인지
/// 헷갈렸다. 지금은 접히는 화면이 아니라 하루치 페이지의 머리다. 달력은 뒤에
/// 그대로 남아 있고, 이 줄은 "고른 날이 이번 주 어디쯤인지"만 말한다.
///
/// ## 한 페이지가 한 주다
///
/// 칸 하나하나를 늘어놓고 멈출 자리를 직접 계산하던 때가 있었다(`WeekStep`).
/// 손짓은 7칸씩 넘어갔지만 두 가지가 어긋났다. **밀어도 보고 있는 날이 안 바뀌어서**
/// 줄만 움직이고 아래 목록은 그대로였고, 스크롤 위치를 `@State`에 묶어둔 탓에
/// 미는 내내 화면 전체가 다시 그려져 **손가락을 따라오는 느낌이 나지 않았다.**
///
/// 이제 **페이지 하나의 너비가 화면 너비와 같다.** 그러면 시스템의 `.paging`이
/// 그대로 맞아떨어져서 멈출 자리를 계산할 필요가 없고, 스크롤 위치도 주가 바뀔
/// 때 **한 번만** 바뀐다. 미는 동안 다시 그려질 일이 없다.
///
/// 주를 넘기면 **같은 요일의 그 주 날짜**로 간다 — 그래서 미는 손짓이 실제로
/// 무언가를 한다(`WeekStripPaging.day(inWeek:keepingWeekdayOf:)`).
///
/// **날짜를 넘기는 손짓은 이 줄 안에서만 받는다.** 페이지 본문까지 좌우 스와이프를
/// 열면 목록 셀의 스와이프 삭제와 방향이 겹쳐 서로 먹힌다.
///
/// 칸마다 Button을 두지 않고 UIKit 탭 인식기를 얹는다 — 달 격자와 같은 방식이고,
/// 이유는 `CellTouchBridge`에 적혀 있다(SwiftUI 제스처는 바깥 스크롤뷰의 pan을 채간다).
struct WeekPagerView: View {
    let width: CGFloat
    let today: Date
    let selectedDate: Date?
    /// 각 날짜의 날씨 심볼을 찾아주는 클로저. 한 번에 보이는 칸은 7개뿐이므로
    /// 값으로 미리 뽑아 넘길 이유가 없다.
    let weatherSymbol: (Date) -> String?
    let onSelect: (Date) -> Void

    /// 요일 머리글 + 숫자 원(30) + 위아래 여백.
    ///
    /// **요일 머리글이 이 줄을 읽히게 하는 것이다.** 숫자만 일곱 개 떠 있으면
    /// 그게 무슨 요일인지 세어봐야 하고, 달 격자는 바로 위에서 일~토로 서 있는데
    /// 이 줄만 다른 규칙이면 두 화면이 어긋나 보인다.
    static let height: CGFloat = 64
    private static let weekdayRowHeight: CGFloat = 16

    /// 지금 보이는 주의 일요일. 주가 바뀔 때만 값이 바뀐다.
    @State private var visibleWeek: Date?

    private let calendar = Calendar.current

    var body: some View {
        VStack(spacing: 2) {
            weekdayHeader
            pages
        }
        .frame(height: Self.height)
        .onAppear { visibleWeek = weekStart(of: selectedDate ?? today) }
        // 줄에서 다른 날을 눌렀거나 '오늘'로 돌아왔다 — 그 날이 든 주로 옮긴다.
        .onChange(of: selectedDate) { _, date in
            guard let date else { return }
            let week = weekStart(of: date)
            guard week != visibleWeek else { return }
            withAnimation(.easeInOut(duration: 0.25)) { visibleWeek = week }
        }
        // 주를 밀었다 — 보던 요일을 지킨 채 그 주로 간다. **고른 날이 이미 그 주에
        // 있으면 아무것도 하지 않는다**(위 `onChange`가 옮겨 놓은 경우가 그렇다).
        .onChange(of: visibleWeek) { _, week in
            guard let week, let selectedDate, weekStart(of: selectedDate) != week else { return }
            onSelect(WeekStripPaging.day(inWeek: week, keepingWeekdayOf: selectedDate))
        }
    }

    /// 일~토. 토요일은 파랑, 일요일은 빨강 — 달 격자와 같은 규칙이다.
    private var weekdayHeader: some View {
        HStack(spacing: 0) {
            ForEach(Array(DateText.weekdaySymbols().enumerated()), id: \.offset) { index, symbol in
                Text(symbol)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(headerColor(forColumn: index))
                    .frame(maxWidth: .infinity)
            }
        }
        .frame(height: Self.weekdayRowHeight)
    }

    /// 색 규칙은 숫자 칸과 **같은 것**을 쓴다(`CalendarDayTone`). 머리글만 다른
    /// 빨강을 쓰면 같은 열의 '일'과 날짜 숫자가 미묘하게 어긋난 색이 된다.
    private func headerColor(forColumn index: Int) -> Color {
        switch index {
        case 0: CalendarDayTone.holidayRed
        case 6: CalendarDayTone.saturdayBlue
        default: MoscoPalette.textSecondary
        }
    }

    /// **페이지 하나의 너비가 화면 너비와 같다.** 그래야 시스템 페이징이 그대로
    /// 맞아떨어진다.
    private var pages: some View {
        ScrollView(.horizontal) {
            LazyHStack(spacing: 0) {
                ForEach(WeekStripWindow.weeks, id: \.self) { week in
                    weekRow(week)
                        .frame(width: width)
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.paging)
        .scrollPosition(id: $visibleWeek)
        .scrollIndicators(.hidden)
    }

    private func weekRow(_ week: Date) -> some View {
        // 흐림 처리는 "고른 날짜가 속한 달"을 기준으로 한다 — 주가 달 경계를
        // 걸칠 때 어느 쪽이 이번 달인지 알려주려는 것이다.
        let referenceMonth = selectedDate.map { CalendarMonth.containing($0) }
        return HStack(spacing: 0) {
            ForEach(WeekStripPaging.days(of: week, calendar: calendar), id: \.self) { day in
                dayCell(day, isDimmed: referenceMonth.map { CalendarMonth.containing(day) != $0 } ?? false)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private func dayCell(_ day: Date, isDimmed: Bool) -> some View {
        DayCell(
            date: day,
            isToday: day == today,
            isSelected: selectedDate == day,
            isDimmed: isDimmed,
            weekendKind: weekendKind(of: day),
            holidayName: KoreanHoliday.name(for: day),
            // 한 줄엔 공휴일 이름을 둘 자리가 없다 — 대신 그 자리에 날씨를
            // 숫자 원 모서리에 얹는다(DayCell 쪽에서 처리).
            showsHolidayLabel: false,
            weatherSymbol: weatherSymbol(day)
        )
        .allowsHitTesting(false)
        .background {
            CellTouchBridge(
                onPressChanged: { _ in },
                onTap: { _ in onSelect(day) },
                isEnabled: true
            )
        }
    }

    private func weekStart(of date: Date) -> Date {
        WeekStripPaging.weekStart(containing: date, calendar: calendar)
    }

    private func weekendKind(of day: Date) -> DayCell.WeekendKind? {
        switch calendar.component(.weekday, from: day) {
        case 1: .sunday
        case 7: .saturday
        default: nil
        }
    }
}
