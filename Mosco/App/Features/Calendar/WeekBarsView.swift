import SwiftUI

/// 한 주(週)의 일정 막대들. 좌표는 스냅샷에서 이미 확정돼 있어서, 여기서는
/// `.offset`으로 자리에 놓기만 한다.
///
/// 막대는 **평평하게** 그린다 — 유리(`moscoGlass`)도, `clipShape`도 쓰지 않는다.
/// 예전엔 막대마다 리퀴드 글래스(iOS 26) 또는 `.ultraThinMaterial`이 붙어 있었는데,
/// 둘 다 실시간으로 배경을 샘플링하는 블러 레이어다. 달을 스와이프하면 그 배경이
/// 매 프레임 달라지므로, 화면에 올라와 있는 막대 수만큼의 블러가 매 프레임 다시
/// 렌더됐다 — 이게 프레임 드랍의 가장 큰 원인이었다. 디자인 시스템의 원칙
/// (`GlassSurface` 주석: "카드/리스트 같은 일반 표면에는 쓰지 않는다")과도 이제 맞다.
struct WeekBarsView: View, Equatable {
    let bars: WeekBars
    let metrics: MonthPageMetrics

    static func == (lhs: WeekBarsView, rhs: WeekBarsView) -> Bool {
        lhs.bars == rhs.bars && lhs.metrics == rhs.metrics
    }

    // 한때 막대 끝에 소속 캘린더 색 점을 찍었는데, 막대가 14pt 한 줄이라 그 점이
    // 가뜩이나 좁은 제목 자리를 뺏어 정작 무슨 일정인지 못 읽게 만들었다.
    // 소속은 날짜를 눌렀을 때 아래 리스트에 칩으로 이름까지 나오니 거기서 본다.

    var body: some View {
        let capacity = metrics.barCapacity
        // 넘치는 게 있으면 마지막 한 줄을 "+N" 자리로 비워둔다(Google/Apple 캘린더와
        // 같은 방식). 여러 날에 걸친 막대는 열마다 따로 자를 수 없으니, 자르는 기준을
        // 주 단위로 통일해야 줄이 어긋나지 않는다.
        let hasOverflow = bars.rowCount > capacity
        let limit = hasOverflow ? capacity - 1 : capacity

        ZStack(alignment: .topLeading) {
            if limit > 0 {
                ForEach(bars.bars.filter { $0.row < limit }) { bar in
                    barView(bar)
                }
            }
            if hasOverflow {
                ForEach(overflowMarks(limit: limit)) { mark in
                    overflowLabel(count: mark.count, column: mark.column, row: max(limit, 0))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    /// 잘린 막대가 있는 열과, 그 열에서 몇 개가 잘렸는지.
    private struct OverflowMark: Identifiable {
        let column: Int
        let count: Int
        var id: Int { column }
    }

    private func overflowMarks(limit: Int) -> [OverflowMark] {
        var counts = [Int](repeating: 0, count: 7)
        for bar in bars.bars where bar.row >= limit {
            for column in bar.startColumn...bar.endColumn where counts.indices.contains(column) {
                counts[column] += 1
            }
        }
        return counts.enumerated().compactMap {
            $0.element > 0 ? OverflowMark(column: $0.offset, count: $0.element) : nil
        }
    }

    private func overflowLabel(count: Int, column: Int, row: Int) -> some View {
        Text("+\(count)")
            .font(.system(size: 9, weight: .semibold))
            .foregroundStyle(MoscoPalette.textSecondary)
            .frame(width: metrics.columnWidth, height: MonthPageMetrics.barHeight, alignment: .leading)
            .padding(.leading, 6)
            .offset(
                x: metrics.columnWidth * CGFloat(column),
                y: CGFloat(row) * (MonthPageMetrics.barHeight + MonthPageMetrics.barSpacing)
            )
    }

    /// 인용문처럼 맨 앞에만 카테고리 색 세로 바를 두고, 나머지는 아주 옅은 톤 채움.
    /// 이어지는 막대의 중간/끝 조각(`continuesBefore`)엔 앞 주에서 이미 색 바를
    /// 보여줬으니 다시 그리지 않는다.
    private func barView(_ bar: BarSpec) -> some View {
        let spanWidth = metrics.columnWidth * CGFloat(bar.endColumn - bar.startColumn + 1)
        let shape = UnevenRoundedRectangle(
            topLeadingRadius: bar.continuesBefore ? 0 : 5,
            bottomLeadingRadius: bar.continuesBefore ? 0 : 5,
            bottomTrailingRadius: bar.continuesAfter ? 0 : 5,
            topTrailingRadius: bar.continuesAfter ? 0 : 5
        )
        // 함수 참조(`map(CategoryColorPalette.color(forHex:))`)로 넘기면 메인 액터에
        // 묶인 함수를 값으로 꺼내는 셈이라 경고가 난다 — 클로저로 감싸 그 자리에서 부른다.
        let color = bar.categoryColorHex.map { CategoryColorPalette.color(forHex: $0) }
            ?? MoscoPalette.textSecondary

        return HStack(spacing: 3) {
            if !bar.continuesBefore {
                // 반복 일정은 이 바를 소문자 i 모양(점 + 막대)으로 바꿔 한 번짜리(|)와
                // 구분한다 — 별도 아이콘을 덧붙이면 좁은 막대에서 제목 자리가 준다.
                VStack(spacing: 1) {
                    if bar.isRepeating {
                        Circle()
                            .fill(color)
                            .frame(width: 2.5, height: 2.5)
                    }
                    Capsule().fill(color)
                }
                .frame(width: 2.5)
                .padding(.vertical, 3)
            }

            Text(bar.title)
                .font(.system(size: 9, weight: .semibold))
                .strikethrough(bar.isCompleted)
                .foregroundStyle(MoscoPalette.textPrimary)
                .lineLimit(1)
                // 자르기 전에 **먼저 줄여서** 최대한 많은 글자를 보여준다. 한 칸이
                // 56pt 남짓이라 9pt 그대로면 네 글자쯤에서 "..."로 끊겨, 무슨
                // 일정인지 알아볼 수가 없었다. 0.7배까지는 작아도 읽히고,
                // 그래도 넘치면 그때 자른다.
                .minimumScaleFactor(0.7)
                .truncationMode(.tail)
        }
        // 좌우 여백을 줄여 글자 자리를 넓힌다 — 막대가 좁을수록 여백 1pt가 글자
        // 한 자다.
        .padding(.horizontal, 3)
        // 폭을 고정하면 Text가 알아서 잘리므로 clipShape가 필요 없다 — 막대마다
        // 오프스크린 렌더 패스를 하나씩 얹지 않게 된다.
        .frame(width: max(spanWidth - 1.5, 0), height: MonthPageMetrics.barHeight, alignment: .leading)
        .background(shape.fill(color.opacity(0.14)))
        .overlay(shape.strokeBorder(color.opacity(0.30), lineWidth: 0.75))
        // 완료된 항목은 TodoRow와 같은 방식(톤 낮춤)으로 구분한다. 이번 달 밖의
        // 칸에만 있는 막대도 흐린 날짜 숫자(DayCell의 0.4)와 같은 톤으로 낮춘다.
        .opacity(bar.isCompleted ? 0.45 : (bar.isDimmed ? 0.4 : 1))
        .offset(
            x: metrics.columnWidth * CGFloat(bar.startColumn),
            y: CGFloat(bar.row) * (MonthPageMetrics.barHeight + MonthPageMetrics.barSpacing)
        )
    }
}
