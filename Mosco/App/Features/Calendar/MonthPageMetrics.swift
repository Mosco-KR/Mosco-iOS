import CoreGraphics
import Foundation

/// 한 달 페이지의 모든 치수를 한곳에서 정한다. 그리는 쪽과 터치를 받는 쪽이
/// **같은 계산**을 보게 하려는 것이다 — 예전엔 히트박스가 뷰(칸마다 Button)로
/// 만들어져 있어서, 실제 렌더 크기와 어긋날 때마다 "바닥이 비는" 류의 버그가 났다.
///
/// 페이지 높이가 고정이라 행 높이가 항상 같고, 그래서 좌표 → 날짜 변환이
/// 나눗셈 두 번으로 끝난다. 이게 칸마다 Button을 두지 않아도 되는 이유다.
struct MonthPageMetrics: Equatable {
    let size: CGSize
    /// 이 달이 몇 개의 주 행으로 그려지는지(4~6).
    let weekCount: Int

    /// 날짜 숫자 줄(숫자 원 + 공휴일 라벨)이 차지하는 높이.
    ///
    /// 이 값과 아래 막대 치수가 "한 주에 막대 몇 개가 보이는지"를 통째로 정한다.
    /// iPhone 16의 6주 달 기준 행 높이가 ≈102.7pt인데, 예전 값(헤더 46 / 막대 16 /
    /// 간격 2)으로는 슬롯이 3개뿐이었고 넘치는 주에서는 마지막 한 줄을 "+N"이
    /// 가져가서 **막대가 2개만** 보였다. 슬롯 4개(막대 3 + "+N" 1)를 만들려고
    /// 셋 다 줄인 값이다: 4×14 + 3×1.5 = 60.5pt ≤ 102.7 − 40 = 62.7pt.
    static let dayHeaderHeight: CGFloat = 40
    /// 막대 하나의 높이. 한 줄로 자른다 — 페이지 높이가 고정이라 막대 높이가
    /// 일정해야 "몇 개까지 들어가는지"를 셀 수 있다. 잘린 제목은 날짜를 탭하면
    /// 아래 리스트에서 다 보인다.
    static let barHeight: CGFloat = 14
    static let barSpacing: CGFloat = 1.5

    var rowHeight: CGFloat {
        weekCount > 0 ? size.height / CGFloat(weekCount) : 0
    }

    var columnWidth: CGFloat {
        size.width / 7
    }

    /// 한 주 행에서 막대들이 쓸 수 있는 높이.
    var barsHeight: CGFloat {
        max(rowHeight - Self.dayHeaderHeight, 0)
    }

    /// 그 높이에 몇 줄까지 들어가는지. n줄의 총 높이는 n*barHeight + (n-1)*barSpacing.
    var barCapacity: Int {
        let unit = Self.barHeight + Self.barSpacing
        guard unit > 0 else { return 0 }
        return max(Int((barsHeight + Self.barSpacing) / unit), 0)
    }

    /// 화면 좌표(페이지 로컬) → 격자 위치. 페이지 밖이면 가장자리로 물린다.
    func position(at point: CGPoint) -> GridPosition {
        let row = Int(point.y / max(rowHeight, 1))
        let column = Int(point.x / max(columnWidth, 1))
        return GridPosition(
            week: min(max(row, 0), max(weekCount - 1, 0)),
            column: min(max(column, 0), 6)
        )
    }

    /// 격자 위치의 사각형(눌림 하이라이트를 놓을 자리).
    func frame(of position: GridPosition) -> CGRect {
        CGRect(
            x: CGFloat(position.column) * columnWidth,
            y: CGFloat(position.week) * rowHeight,
            width: columnWidth,
            height: rowHeight
        )
    }
}

/// 달 격자 안의 한 칸.
struct GridPosition: Equatable {
    let week: Int
    let column: Int
}
