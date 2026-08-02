import SwiftUI

/// 날짜 숫자만 담당한다. 그날의 일정(블록)은 셀 안이 아니라 주(week) 단위
/// 오버레이(WeekBlockBarsView)에서 여러 셀에 걸쳐 그려진다.
///
/// 탭 인식과 눌림 배경(박스)은 MonthGridView가 숫자 줄부터 그 아래 블록
/// 영역까지를 하나의 사각형으로 묶어 대신 맡는다(그래야 숫자 바로 아래 빈
/// 자리를 눌러도 같은 날짜로 잡힌다) — 그래서 여기엔 Button이 없고, 눌림 상태도
/// 안 받는다. 예전엔 부모가 눌린 날짜를 @State로 들고 여기까지 내려줬는데, 그러면
/// 칸 하나를 누를 때마다 부모 body가 통째로 재평가돼 격자 전체가 다시 만들어졌다.
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
        VStack(spacing: 0) {
            Text(dayNumber)
                .font(.moscoBody())
                .fontWeight(isToday || isSelected ? .semibold : .regular)
                .foregroundStyle(numberColor)
                // 큰 동적 타입에서도 동그라미를 넘지 않게 줄여서 그린다 — 격자는
                // 높이가 고정이라(MonthPageMetrics) 숫자가 커지면 아래 막대 자리를
                // 먹는 게 아니라 그냥 잘린다.
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(width: 30, height: 30)
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
                            .font(.system(size: 8))
                            .symbolRenderingMode(.multicolor)
                            .padding(1.5)
                            .background(MoscoPalette.canvas, in: Circle())
                            // 숫자를 가리지 않을 만큼만 바깥으로. 더 밀면 선택
                            // 테두리에 닿는다 — 아래 선택 표시의 여백과 짝이다.
                            .offset(x: 3, y: -2)
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
        // 예전엔 여기에 minHeight 44(iOS 권장 최소 탭 영역)를 걸었다. 이제는 탭을
        // 이 뷰가 받지 않는다 — 좌표를 날짜로 환산하는 방식이라 실제 탭 영역이
        // 이미 행 전체(~103pt)다. 그대로 두면 40pt로 잡은 숫자 줄 높이를 넘겨
        // 막대 자리를 먹으므로 뺀다(MonthPageMetrics.dayHeaderHeight 참고).
        //
        // 압축된 주간 스트립에서는 반대로 **높이를 꽉 채운다**. 안 그러면 셀이
        // 내용만큼(34pt)만 커지고, 선택 테두리가 그 안쪽으로 그려져 44pt 스트립
        // 한가운데 답답하게 작은 박스가 남았다.
        .frame(
            maxWidth: .infinity,
            maxHeight: showsHolidayLabel ? nil : .infinity,
            alignment: showsHolidayLabel ? .top : .center
        )
        // 선택된 날짜는 채움이 아니라 칸 전체를 감싸는 빈 사각형(테두리만)으로
        // 표시한다 — 숫자 둘레의 작은 동그라미 대신, 실제 탭 영역과 같은
        // 크기라야 "여기가 선택됐다"는 표시와 "여기를 눌렀다"가 서로 일치한다.
        // opacity 0으로 항상 그려두면 42칸 × 페이지 수만큼 보이지도 않는 도형이
        // 매 업데이트마다 레이아웃·렌더 대상이 된다. 필요할 때만 만든다.
        .overlay {
            if isSelected && !isToday {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(MoscoPalette.accent, lineWidth: 1.5)
                    // 칸 가장자리에 딱 붙이지 않고 살짝 안쪽으로 — 옆 칸의 표시와
                    // 사이가 뜬다. 세로는 거의 여백을 안 준다: 스트립에서 위아래로
                    // 조이면 날씨 배지와 닿고 답답해 보인다.
                    .padding(.horizontal, 4)
                    .padding(.vertical, showsHolidayLabel ? 2 : 1)
            }
        }
    }
}
