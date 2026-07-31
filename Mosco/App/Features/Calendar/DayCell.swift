import SwiftUI

/// 날짜 숫자만 담당한다. 그날의 일정(블록)은 셀 안이 아니라 주(week) 단위
/// 오버레이(WeekBlockBarsView)에서 여러 셀에 걸쳐 그려진다.
///
/// 이 뷰 자체는 순전히 그림만 그린다 — 탭 인식과 눌림 하이라이트는
/// MonthGridView가 숫자 줄부터 그 아래 블록 영역까지를 하나의 사각형으로 묶어
/// 대신 맡는다(그래야 숫자 바로 아래 빈 자리를 눌러도 같은 날짜로 잡힌다).
/// 그래서 여기엔 Button도, action도 없다.
struct DayCell: View {
    enum WeekendKind {
        case sunday
        case saturday
    }

    let date: Date
    let isToday: Bool
    var isSelected: Bool = false
    /// 이번 달이 아닌(이전/다음 달) 날짜는 흐리게 — 여전히 탭 가능.
    var isDimmed: Bool = false
    /// 일요일/토요일 — 한국 캘린더 관례대로 빨강/파랑으로 구분.
    var weekendKind: WeekendKind? = nil
    /// 공휴일이면 이름(예: "광복절")이 들어온다 — 숫자 색도 빨강 톤으로 맞춘다.
    var holidayName: String? = nil
    /// 압축된 한 줄(주간 스트립)일 땐 자리가 없어 공휴일 이름을 생략한다.
    var showsHolidayLabel: Bool = true

    private var dayNumber: String {
        String(Calendar.current.component(.day, from: date))
    }

    private var numberColor: Color {
        if isToday { return .white }
        if isSelected { return MoscoPalette.accent }
        let base: Color = (weekendKind == .sunday || holidayName != nil) ? MoscoPalette.must
            : weekendKind == .saturday ? MoscoPalette.could
            : MoscoPalette.textPrimary
        return isDimmed ? base.opacity(0.4) : base
    }

    var body: some View {
        VStack(spacing: 2) {
            Text(dayNumber)
                .font(.moscoBody())
                .fontWeight(isToday || isSelected ? .semibold : .regular)
                .foregroundStyle(numberColor)
                .frame(width: 34, height: 34)
                .background(isToday ? MoscoPalette.accent : Color.clear, in: Circle())

            // 공휴일 이름이 있을 때만 채워지지만, 자리는 항상 예약해둔다 —
            // 안 그러면 공휴일이 있는 셀만 아래로 한 줄 더 커져서, 같은 행에서도
            // 숫자 높이가 셀마다 어긋나 보인다.
            if showsHolidayLabel {
                Text(holidayName ?? " ")
                    .font(.system(size: 8, weight: .medium))
                    .foregroundStyle(MoscoPalette.must.opacity(isDimmed ? 0.4 : 1))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .opacity(holidayName == nil ? 0 : 1)
            }
        }
        // maxHeight를 여기서 .infinity로 주면 이 칸이 속한 HStack이 통째로
        // 늘어나 버려서, 같은 주(週) VStack 안에 있는 블록 바(WeekBlockBarsView)가
        // 늘어난 만큼 아래로 밀려난다 — 블록 수가 적은 주(특히 탭바 바로 위
        // 마지막 줄)일수록 그 밀림이 커져, 블록이 화면 밖으로 밀려나거나
        // 잘려 보였다. 그래서 maxHeight는 여전히 안 주지만, minHeight는
        // MonthGridView.numberRowHeight(44)와 맞춘다.
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .top)
        // 선택된 날짜는 채움이 아니라 칸 전체를 감싸는 빈 사각형(테두리만)으로
        // 표시한다 — 숫자 둘레의 작은 동그라미 대신, 실제 탭 영역과 같은
        // 크기라야 "여기가 선택됐다"는 표시와 "여기를 눌렀다"가 서로 일치한다.
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(MoscoPalette.accent, lineWidth: 1.5)
                .opacity(isSelected && !isToday ? 1 : 0)
        )
    }
}
