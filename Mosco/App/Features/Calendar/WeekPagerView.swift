import SwiftUI

/// 하루치 페이지 맨 위에 서는 한 줄짜리 주간 스트립.
///
/// 77d0649에서 한 번 걷어냈던 줄이다. 그때는 이게 **달력 화면이 접힌 모습**이었다 —
/// 한 화면이 달 격자와 주간 스트립을 오가니 지금 보고 있는 게 달인지 하루인지
/// 헷갈렸다. 지금은 접히는 화면이 아니라 하루치 페이지의 머리다. 달력은 뒤에
/// 그대로 남아 있고, 이 줄은 "고른 날 앞뒤로 어떤 날이 있는지"만 말한다.
///
/// **고른 날이 늘 가운데 온다.** 들어올 때도, 줄에서 다른 날을 눌렀을 때도 그 날이
/// 넷째 칸으로 미끄러져 온다. 일요일로 시작하는 주로 끊던 때는 들어온 날이 맨 왼쪽
/// 끝에 붙기도 했다. 그래서 칸을 하루 단위로 늘어놓는다(`WeekStripPaging`).
///
/// 미는 손짓은 예전처럼 한 번에 한 주다. 다만 `.paging`은 페이지 경계가 창의 첫
/// 날에 묶여 있어 아무 날이나 가운데 둘 수 없으므로 `WeekStep`이 멈출 자리를 정한다.
/// "40pt 넘게 밀면 ±7일 점프"처럼 손짓을 직접 판정하면 손가락을 따라오지 않았으니,
/// 스크롤 자체는 계속 스크롤뷰에 맡긴다.
///
/// **날짜를 넘기는 손짓은 이 줄 안에서만 받는다.** 페이지 본문까지 좌우 스와이프를
/// 열면 목록 셀의 스와이프 삭제와 방향이 겹쳐 서로 먹힌다
/// (`DayTodosContentView` 주석 참고).
///
/// 칸마다 Button을 두지 않고 UIKit 탭 인식기를 얹는다 — 달 격자와 같은 방식이고,
/// 이유는 `CellTouchBridge`에 적혀 있다(SwiftUI 제스처는 바깥 스크롤뷰의 pan을
/// 채간다).
struct WeekPagerView: View {
    let width: CGFloat
    let today: Date
    let selectedDate: Date?
    /// 각 날짜의 날씨 심볼을 찾아주는 클로저. 한 번에 보이는 칸은 7개뿐이므로
    /// 값으로 미리 뽑아 넘길 이유가 없다.
    let weatherSymbol: (Date) -> String?
    let onSelect: (Date) -> Void

    /// 숫자 원(30) + 위아래 여백. 이 높이에서는 공휴일 이름을 둘 자리가 없어
    /// `DayCell`이 그 줄을 접는다(`showsHolidayLabel: false`).
    static let height: CGFloat = 44

    /// 맨 왼쪽 칸의 날짜. 스크롤 위치를 이것으로 잡는다.
    @State private var leadingDay: Date?

    private let calendar = Calendar.current

    var body: some View {
        let dayWidth = width / CGFloat(WeekStripPaging.daysPerPage)
        // 흐림 처리는 "고른 날짜가 속한 달"을 기준으로 한다 — 줄이 달 경계를
        // 걸칠 때 어느 쪽이 이번 달인지 알려주려는 것이다.
        let referenceMonth = selectedDate.map { CalendarMonth.containing($0) }

        ScrollView(.horizontal) {
            LazyHStack(spacing: 0) {
                ForEach(DayStripWindow.days, id: \.self) { day in
                    dayCell(day, isDimmed: referenceMonth.map { CalendarMonth.containing(day) != $0 } ?? false)
                        .frame(width: dayWidth, height: Self.height)
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(WeekStep(dayWidth: dayWidth))
        .scrollPosition(id: $leadingDay, anchor: .leading)
        .scrollIndicators(.hidden)
        .frame(height: Self.height)
        .onAppear {
            leadingDay = WeekStripPaging.leadingDay(centering: selectedDate ?? today)
        }
        // 줄에서 고른 날도, '오늘'로 돌아온 날도 가운데로 데려온다.
        .onChange(of: selectedDate) { _, date in
            guard let date else { return }
            withAnimation(.easeInOut(duration: 0.25)) {
                leadingDay = WeekStripPaging.leadingDay(centering: date)
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
            // 44pt 한 줄엔 공휴일 이름을 둘 자리가 없다 — 대신 그 자리에
            // 날씨를 숫자 원 모서리에 얹는다(DayCell 쪽에서 처리).
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

    /// 칸이 하루 단위로 흐르니 열 순서가 더는 요일이 아니다 — 날짜에서 읽는다.
    private func weekendKind(of day: Date) -> DayCell.WeekendKind? {
        switch calendar.component(.weekday, from: day) {
        case 1: .sunday
        case 7: .saturday
        default: nil
        }
    }
}

/// 한 번 밀면 한 주씩 넘기되 칸(하루) 경계에 멈춘다. 계산은 `WeekStripPaging`.
private struct WeekStep: ScrollTargetBehavior {
    let dayWidth: CGFloat

    func updateTarget(_ target: inout ScrollTarget, context: TargetContext) {
        target.rect.origin.x = WeekStripPaging.restingOffset(
            start: context.originalTarget.rect.minX,
            proposed: target.rect.minX,
            dayWidth: dayWidth
        )
    }
}

/// 스트립이 올려둘 날들. `MonthWindow`와 같은 이유로 고정 배열이다 —
/// 창을 옮기며 오프셋을 되돌리는 방식은 그 순간이 튀기 쉬운데, `LazyHStack`은
/// 화면 밖 칸을 만들지 않으므로 창을 크게 잡아도 비용이 같다.
enum DayStripWindow {
    /// 앞뒤 약 10년. 주 단위로 끊던 때와 같은 거리다.
    static let radius = 3650

    static let days: [Date] = {
        let calendar = Calendar.current
        let anchor = calendar.startOfDay(for: Date())
        return (-radius...radius).compactMap {
            calendar.date(byAdding: .day, value: $0, to: anchor)
        }
    }()
}
