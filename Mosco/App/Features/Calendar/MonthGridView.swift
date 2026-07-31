import SwiftUI

/// `Equatable` 채택 + 호출부의 `.equatable()`로, 관련 값이 그대로면 드래그 중
/// 매 프레임 다시 그려지는 걸 건너뛴다.
///
/// `Grid`/`GridRow` 대신 순수 `VStack`+`HStack`을 쓴다 — `Grid`는 모든 행이 공유하는
/// 컬럼 폭을 내부적으로 계산하는데, 특정 행에 외부 프레임을 주면 그 계산이
/// 깨진다(실제로 겪은 버그). 각 행이 서로 독립적인 구조에서는 이 문제가 없다.
///
/// 높이는 화면을 채우려 늘어나지 않고, 각 주(週)가 자기 내용만큼만 차지한다 —
/// 블록이 많은 주만 길어지고 나머지 주는 컴팩트하게 유지된다. 전체가 화면보다
/// 길어지면 바깥(CalendarScreen)의 ScrollView가 받아준다.
struct MonthGridView: View, Equatable {
    let month: Date
    let positionedBlocks: [PositionedBlock]
    /// 지금 선택된 날짜 — 압축된 행에서 그 날짜 셀에 빈 동그라미 표시를 넣는 용도.
    /// "현재" 페이지가 아니면 항상 nil로 넘어온다(다른 페이지엔 선택 표시가 없다).
    let selectedDate: Date?
    /// 이 페이지에서 압축(선택)된 주의 행 번호. nil이면 평소 그리드 그대로,
    /// 값이 있으면 그 행만 44pt로 남고 나머지 행은 이 그리드 자체가 접히듯 사라진다
    /// — 실제 레이아웃 하나로 압축/복원 애니메이션이 항상 대칭으로 이어진다.
    let selectedRowIndex: Int?
    let onSelect: (Date) -> Void

    static func == (lhs: MonthGridView, rhs: MonthGridView) -> Bool {
        lhs.month == rhs.month
            && lhs.positionedBlocks == rhs.positionedBlocks
            && lhs.selectedDate == rhs.selectedDate
            && lhs.selectedRowIndex == rhs.selectedRowIndex
    }

    private let calendar = Calendar.current
    // 제목이 길면 말줄임표 대신 두 줄로 끊어서 보여주기로 해서, 한 줄(16pt)보다
    // 훨씬 넉넉하게 잡는다 — 9pt 텍스트 두 줄(~22~24pt) + 위아래 여백이 실제로
    // 들어가려면 32는 돼야 한다(WeekBlockBarsView의 행 높이 계산과 맞물려 있다).
    private let blockRowHeight: CGFloat = 32
    /// 블록이 없어도 최소 한 줄 자리는 확보해서, 주 사이 간격이 완전히 붙지 않게.
    private let minBlockRows = 1
    /// 지금 누르고 있는 날짜 — 배경 버튼(터치 인식)과 DayCell(눌림 애니메이션)이
    /// 서로 다른 뷰라 상태를 공유해야 둘 다 같은 순간에 반응한다.
    @State private var pressedDate: Date?

    private struct WeekRow {
        let dates: [Date]
        let inMonth: [Bool]
    }

    /// 항상 실제 날짜 7개(일~토)로 구성된 주 단위 행. 이번 달이 아닌 날짜는
    /// inMonth가 false라 흐리게 표시될 뿐, 블록 이어짐 계산에는 그대로 쓰인다.
    private var weekRows: [WeekRow] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: month),
              let firstWeek = calendar.dateInterval(of: .weekOfYear, for: monthInterval.start)
        else { return [] }

        var rows: [WeekRow] = []
        var weekStart = firstWeek.start
        while weekStart < monthInterval.end {
            var dates: [Date] = []
            var inMonth: [Bool] = []
            var current = weekStart
            for _ in 0..<7 {
                dates.append(current)
                inMonth.append(calendar.isDate(current, equalTo: month, toGranularity: .month))
                current = calendar.date(byAdding: .day, value: 1, to: current) ?? current
            }
            rows.append(WeekRow(dates: dates, inMonth: inMonth))
            weekStart = calendar.date(byAdding: .weekOfYear, value: 1, to: weekStart) ?? monthInterval.end
        }
        return rows
    }

    /// 이 주(週)에 실제로 쓰이는 블록 행 수 — 달 전체 최대에 맞춰 모든 주를
    /// 늘리지 않고, 주마다 자기 블록 수만큼만 높이를 가진다.
    /// 이전/다음 달의 흐린 칸에만 걸치는 블록은 그려지지 않으므로(WeekBlockBarsView가
    /// 잘라냄) 높이 계산에서도 빼야 하고, 전역 행 번호가 아니라 "서로 다른 행의
    /// 개수"를 세야 한다 — WeekBlockBarsView가 주 안에서 행을 촘촘하게 다시 매기는
    /// 것과 같은 기준이라, 다른 주의 긴 반복 일정 때문에 빈 행이 예약되지 않는다.
    private func blockRows(for week: WeekRow) -> Int {
        let inMonthDates = zip(week.dates, week.inMonth).filter(\.1).map(\.0)
        guard let firstInMonth = inMonthDates.first, let lastInMonth = inMonthDates.last else { return minBlockRows }
        let usedRows = Set(
            positionedBlocks
                .filter { $0.block.start <= lastInMonth && $0.block.end >= firstInMonth }
                .map(\.row)
        )
        return max(usedRows.count, minBlockRows)
    }

    private func blockAreaHeight(for week: WeekRow) -> CGFloat {
        CGFloat(blockRows(for: week)) * blockRowHeight - 2
    }

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(weekRows.enumerated()), id: \.offset) { index, week in
                weekRowView(week, index: index)
            }
        }
    }

    private func weekRowView(_ week: WeekRow, index: Int) -> some View {
        let isCompact = selectedRowIndex != nil
        let isSelectedRow = selectedRowIndex == index
        let rowVisible = !isCompact || isSelectedRow

        return VStack(spacing: 0) {
            // 날짜 숫자 + 그 블록들은 하나의 뭉치로 맨 위에 붙인다 — 행이 화면을
            // 채우려 늘어나도, 늘어난 여백은 이 뭉치 "아래"(Spacer)로 가야
            // 블록이 항상 자기 날짜 바로 밑에 붙어 보인다. 예전엔 숫자 칸 자체가
            // 늘어나서 블록이 다음 줄처럼 멀리 떨어져 보였다.
            VStack(spacing: 2) {
                HStack(spacing: 0) {
                    ForEach(0..<7, id: \.self) { col in
                        dayCell(week: week, col: col, isCompact: isCompact)
                    }
                }
                .allowsHitTesting(false)

                if !isCompact {
                    WeekBlockBarsView(
                        weekStart: week.dates[0],
                        weekDates: week.dates,
                        positionedBlocks: positionedBlocks,
                        inMonth: week.inMonth,
                        totalRows: blockRows(for: week),
                        onSelect: onSelect
                    )
                    .equatable()
                    .frame(height: blockAreaHeight(for: week))
                }
            }
            // 터치 인식과 눌림 하이라이트를 맡는 배경 버튼 — .background()는
            // 앞(위 VStack)의 콘텐츠와 정확히 같은 크기로 저절로 맞춰지므로,
            // 공휴일 라벨 유무 등으로 숫자 줄 실제 높이가 미묘하게 달라져도
            // 높이를 따로 계산해서 어긋나는 일(바닥이 비는 것)이 없다 — 항상
            // 실제 렌더 크기 그대로 딱 맞는다. 위에 그려지는 숫자는
            // allowsHitTesting(false)로 손을 떼서 터치가 이 배경까지 그대로
            // 통과하고, 블록 막대는 같은 자리에서 앞쪽에 그려지므로 블록을
            // 직접 누르면 그쪽 제스처가 우선한다.
            .background(alignment: .top) {
                HStack(spacing: 0) {
                    ForEach(0..<7, id: \.self) { col in
                        let date = week.dates[col]
                        Button {
                            onSelect(date)
                        } label: {
                            Color.clear
                        }
                        .buttonStyle(CellPressHighlightStyle(onPressingChanged: { isPressed in
                            pressedDate = isPressed ? date : (pressedDate == date ? nil : pressedDate)
                        }))
                    }
                }
            }
            .padding(.vertical, isCompact ? 0 : 4)

            if !isCompact {
                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(
            minHeight: isCompact ? (isSelectedRow ? 44 : 0) : nil,
            maxHeight: isCompact ? (isSelectedRow ? 44 : 0) : .infinity
        )
        .opacity(rowVisible ? 1 : 0)
        .clipped()
    }

    @ViewBuilder
    private func dayCell(week: WeekRow, col: Int, isCompact: Bool) -> some View {
        let date = week.dates[col]
        DayCell(
            date: date,
            isToday: calendar.isDateInToday(date),
            isSelected: selectedDate.map { calendar.isDate($0, inSameDayAs: date) } ?? false,
            isDimmed: !week.inMonth[col],
            weekendKind: weekendKind(for: date),
            holidayName: KoreanHoliday.name(for: date),
            showsHolidayLabel: !isCompact,
            isPressed: pressedDate == date
        )
        .frame(maxWidth: .infinity)
    }

    private func weekendKind(for date: Date) -> DayCell.WeekendKind? {
        switch calendar.component(.weekday, from: date) {
        case 1: .sunday
        case 7: .saturday
        default: nil
        }
    }
}

/// 날짜 칸 배경 버튼(위 weekRowView) 전용 눌림 효과 — 칸 전체(숫자+블록 영역)에
/// 옅은 액센트 배경을 깔아서, 어디를 누르든 "이 칸 전체가 눌렸다"는 게 보이게
/// 한다. 눌림 상태를 onPressingChanged로 밖에도 알려서, 숫자 자체의 축소·페이드
/// 애니메이션(DayCell.isPressed)이 이 배경과 같은 타이밍에 같이 움직인다.
private struct CellPressHighlightStyle: ButtonStyle {
    var onPressingChanged: (Bool) -> Void = { _ in }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(MoscoPalette.accent.opacity(configuration.isPressed ? 0.08 : 0))
            )
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, newValue in
                onPressingChanged(newValue)
            }
    }
}
