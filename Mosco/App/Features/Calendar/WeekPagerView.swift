import SwiftUI

/// 하루치 페이지 맨 위에 서는 주간 스트립("압축 캘린더").
///
/// 77d0649에서 한 번 걷어냈던 줄이다. 그때는 이게 **달력 화면이 접힌 모습**이었다 —
/// 한 화면이 달 격자와 주간 스트립을 오가니 지금 보고 있는 게 달인지 하루인지
/// 헷갈렸다. 지금은 접히는 화면이 아니라 하루치 페이지의 머리다. 달력은 뒤에
/// 그대로 남아 있고, 이 줄은 "고른 날이 이번 주 어디쯤인지"만 말한다.
///
/// ## 세 페이지만 든다
///
/// 전에는 앞뒤 10년치 1,041개 주를 지연 로딩하는 가로 스크롤뷰에 스크롤 자리를
/// 값으로 묶어 두었다(`scrollPosition(id:)`). 그런데 **요일 머리글은 고정이고 숫자
/// 줄만 스크롤하는 구조**라, 스크롤이 한 페이지 폭의 정수배에 서지 않으면 숫자
/// 일곱 개가 통째로 몇 pt 밀려 머리글과 어긋나 보였다. 화면에 뜨는 순간 가운데로
/// 점프해야 하는데 첫 레이아웃에서 폭이 0으로 들어오거나, 날짜가 바뀔 때 그 자리를
/// 애니메이션으로 옮기다 손가락 스크롤과 겹치면 경계에 안 섰다.
///
/// 지금은 **지난 주·이번 주·다음 주 세 장만** 들고, 넘길 때마다 가운데로 되돌린다.
/// 페이지가 셋이면 점프할 거리가 아예 없고, 페이징은 `TabView`의 것이라 늘 페이지
/// 경계에 선다. 달 격자가 안 어긋나는 이유와 같다 — 멈출 자리를 직접 계산하지 않는다.
///
/// ## 일정이 있는 날은 점으로 말한다
///
/// 달 격자는 일정을 막대로 보여주는데 그 막대는 칸 안이 아니라 주 단위 오버레이로
/// 그려져서(`WeekBarsView`) 이 줄에는 들어오지 않았다. 그래서 이 줄만 보고는 어느
/// 날에 뭐가 있는지 알 수가 없었다 — 하루 건너뛰려고 달력까지 안 나가게 만든 줄인데
/// 정작 어디로 갈지를 말해주지 않았다. 숫자 원 왼쪽 아래에 점 하나를 찍는다. 높이를
/// 안 건드리려고 날씨 배지와 같은 수를 쓴다(`DayCell`).
///
/// **날짜를 넘기는 손짓은 이 줄 안에서만 받는다.** 페이지 본문까지 좌우 스와이프를
/// 열면 목록 셀의 손짓과 방향이 겹친다.
struct WeekPagerView: View {
    let today: Date
    let selectedDate: Date?
    /// 각 날짜의 날씨 심볼. 한 번에 보이는 칸은 7개뿐이라 미리 뽑아 넘길 이유가 없다.
    let weatherSymbol: (Date) -> String?
    /// 그날 안 끝낸 일이 있는지 / 일정이 아예 없는지. 점을 찍을지 정한다.
    let dayMark: (Date) -> DayTodoMark?
    let onSelect: (Date) -> Void

    /// 요일 머리글 + 숫자 원(30) + 위아래 여백.
    ///
    /// **요일 머리글이 이 줄을 읽히게 하는 것이다.** 숫자만 일곱 개 떠 있으면
    /// 그게 무슨 요일인지 세어봐야 하고, 달 격자는 일~토로 서 있는데 이 줄만
    /// 다른 규칙이면 두 화면이 어긋나 보인다.
    static let height: CGFloat = 64
    private static let weekdayRowHeight: CGFloat = 16

    /// 가운데 페이지가 보여주는 주의 일요일.
    @State private var centerWeek: Date
    /// 지금 선 페이지(0=지난 주, 1=가운데, 2=다음 주). 넘기면 곧바로 1로 되돌린다.
    @State private var page = 1

    private let calendar = Calendar.current

    init(
        today: Date,
        selectedDate: Date?,
        weatherSymbol: @escaping (Date) -> String?,
        dayMark: @escaping (Date) -> DayTodoMark?,
        onSelect: @escaping (Date) -> Void
    ) {
        self.today = today
        self.selectedDate = selectedDate
        self.weatherSymbol = weatherSymbol
        self.dayMark = dayMark
        self.onSelect = onSelect
        _centerWeek = State(
            initialValue: WeekStripPaging.weekStart(containing: selectedDate ?? today)
        )
    }

    var body: some View {
        VStack(spacing: 2) {
            weekdayHeader
            pages
        }
        .frame(height: Self.height)
        // 줄에서 다른 날을 눌렀거나 '오늘'로 돌아왔다 — 그 날이 든 주로 옮긴다.
        .onChange(of: selectedDate) { _, date in
            guard let date else { return }
            let week = weekStart(of: date)
            guard week != centerWeek else { return }
            withAnimation(.easeInOut(duration: 0.25)) { centerWeek = week }
        }
        // 주를 넘겼다 — 보던 요일을 지킨 채 그 주로 가고, **가운데로 되돌린다.**
        // 되돌리는 것을 애니메이션 없이 해야 넘긴 자리에서 멈춘 것처럼 보인다.
        .onChange(of: page) { _, newValue in
            guard newValue != 1 else { return }
            let moved = week(at: newValue)
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                centerWeek = moved
                page = 1
            }
            guard let selectedDate else { return }
            onSelect(WeekStripPaging.day(inWeek: moved, keepingWeekdayOf: selectedDate))
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

    /// 세 장짜리 페이저. 폭을 재지도, 멈출 자리를 계산하지도 않는다 —
    /// `TabView`의 페이징은 늘 페이지 경계에 선다.
    private var pages: some View {
        TabView(selection: $page) {
            ForEach(0..<3, id: \.self) { index in
                weekRow(week(at: index))
                    .tag(index)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
    }

    private func week(at index: Int) -> Date {
        calendar.date(byAdding: .day, value: (index - 1) * WeekStripPaging.daysPerPage, to: centerWeek)
            ?? centerWeek
    }

    private func weekRow(_ week: Date) -> some View {
        // 흐림은 **그 주 자신**을 기준으로 한다 — 주의 가운데(수요일)가 속한 달이
        // 이번 달이다. 예전엔 "고른 날짜의 달"을 봤는데, 주를 넘기면 보이는 주가
        // 먼저 바뀌고 고른 날짜가 한 걸음 뒤에 따라와서 **일곱 칸이 한 프레임
        // 통째로 흐려졌다가 돌아왔다**(달을 넘길 때마다 줄 전체가 깜빡였다).
        let reference = calendar.date(byAdding: .day, value: 3, to: week) ?? week
        let referenceMonth = CalendarMonth.containing(reference)
        return HStack(spacing: 0) {
            ForEach(WeekStripPaging.days(of: week, calendar: calendar), id: \.self) { day in
                dayCell(day, isDimmed: CalendarMonth.containing(day) != referenceMonth)
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
            weatherSymbol: weatherSymbol(day),
            mark: dayMark(day)
        )
        .contentShape(Rectangle())
        // 칸을 누르면 그날로. 페이저 안이라 UIKit 인식기를 따로 얹지 않는다 —
        // `TabView`의 스와이프와 탭은 시스템이 이미 갈라 준다.
        .onTapGesture { onSelect(day) }
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
