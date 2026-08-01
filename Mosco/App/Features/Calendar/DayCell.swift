import SwiftUI

/// 날짜 숫자만 담당한다. 그날의 일정(블록)은 셀 안이 아니라 주(week) 단위
/// 오버레이(WeekBlockBarsView)에서 여러 셀에 걸쳐 그려진다.
///
/// 탭 인식과 눌림 배경(박스)은 MonthGridView가 숫자 줄부터 그 아래 블록
/// 영역까지를 하나의 사각형으로 묶어 대신 맡는다(그래야 숫자 바로 아래 빈
/// 자리를 눌러도 같은 날짜로 잡힌다) — 그래서 여기엔 Button이 없다. 다만
/// 숫자 자체의 축소·페이드 애니메이션은 그 배경 버튼의 눌림 상태를
/// `isPressed`로 그대로 전달받아 같은 타이밍에 재생한다.
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
    /// MonthGridView의 배경 버튼이 지금 눌리고 있는 날짜면 true.
    var isPressed: Bool = false
    /// 그날 날씨 아이콘(SF Symbol). 압축된 주간 스트립에서만 쓴다 — 예보 범위
    /// 밖이거나 날씨를 못 받아왔으면 nil이고, 그때는 아무것도 안 그린다.
    var weatherSymbol: String? = nil

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
                // 압축된 주간 스트립은 높이가 44로 고정이라 숫자 아래에 한 줄을
                // 더 두면 잘린다 — 숫자 원의 오른쪽 위 모서리에 작게 얹어서
                // 높이를 안 늘리고도 그날 날씨가 보이게 한다.
                //
                // 바깥으로 밀어내지 않고 원 위에 살짝 걸치게 둔다. 예전엔 오른쪽
                // 위로 밀어놨더니 선택 표시(칸을 감싸는 사각형)의 모서리에 거의
                // 붙어서 답답해 보였다 — 아래 padding과 함께 여백을 만든다.
                .overlay(alignment: .topTrailing) {
                    if let weatherSymbol {
                        Image(systemName: weatherSymbol)
                            .font(.system(size: 9))
                            .symbolRenderingMode(.multicolor)
                            .padding(2)
                            .background(MoscoPalette.canvas, in: Circle())
                            .offset(x: 1, y: -1)
                    }
                }

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
        // 압축된 주간 스트립(공휴일 라벨을 생략하는 그 상태)에서만 위쪽 여백을
        // 준다 — 날씨 아이콘이 칸 맨 위에 붙어 선택 표시 사각형과 겹쳐 보이는 걸
        // 막는다. 펼친 달력에는 날씨를 안 그리므로 여백도 필요 없고, 여기에 주면
        // 주(週) 행 높이가 통째로 밀려 블록 위치까지 어긋난다.
        .padding(.top, showsHolidayLabel ? 0 : 4)
        // maxHeight를 여기서 .infinity로 주면 이 칸이 속한 HStack이 통째로
        // 늘어나 버려서, 같은 주(週) VStack 안에 있는 블록 바(WeekBlockBarsView)가
        // 늘어난 만큼 아래로 밀려난다 — 블록 수가 적은 주(특히 탭바 바로 위
        // 마지막 줄)일수록 그 밀림이 커져, 블록이 화면 밖으로 밀려나거나
        // 잘려 보였다. 그래서 maxHeight는 여전히 안 주지만, minHeight는 44(iOS
        // 권장 최소 탭 영역)로 맞춘다.
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .top)
        // 선택된 날짜는 채움이 아니라 칸 전체를 감싸는 빈 사각형(테두리만)으로
        // 표시한다 — 숫자 둘레의 작은 동그라미 대신, 실제 탭 영역과 같은
        // 크기라야 "여기가 선택됐다"는 표시와 "여기를 눌렀다"가 서로 일치한다.
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(MoscoPalette.accent, lineWidth: 1.5)
                .opacity(isSelected && !isToday ? 1 : 0)
                // 칸 가장자리에 딱 붙이지 않고 살짝 안쪽으로 — 옆 칸의 표시와도,
                // 날씨 아이콘과도 사이가 뜬다.
                .padding(2)
        )
        // 예전엔 이 축소·페이드가 DayCell 자신의 버튼 눌림에서 나왔지만, 지금은
        // 탭을 배경 버튼이 대신 받으므로 그 눌림 상태를 isPressed로 전달받아
        // 같은 느낌을 그대로 재현한다.
        .scaleEffect(isPressed ? 0.88 : 1)
        .opacity(isPressed ? 0.7 : 1)
        .animation(.easeOut(duration: 0.12), value: isPressed)
    }
}
