import Foundation

/// 월 그리드가 몇 주로 표시되는지, 특정 날짜가 몇 번째 주에 속하는지 계산.
/// MonthGridView와 CalendarScreen(전환 애니메이션의 앵커 계산)이 같이 쓴다.
extension Calendar {
    func weekRowCount(for month: Date) -> Int {
        guard let monthInterval = dateInterval(of: .month, for: month),
              let firstWeek = dateInterval(of: .weekOfYear, for: monthInterval.start)
        else { return 0 }

        var count = 0
        var weekStart = firstWeek.start
        while weekStart < monthInterval.end {
            count += 1
            weekStart = date(byAdding: .weekOfYear, value: 1, to: weekStart) ?? monthInterval.end
        }
        return count
    }

    /// date가 month 그리드에서 몇 번째 주(0-based)에 속하는지.
    func weekRowIndex(of targetDate: Date, in month: Date) -> Int {
        guard let monthInterval = dateInterval(of: .month, for: month),
              let firstWeek = dateInterval(of: .weekOfYear, for: monthInterval.start)
        else { return 0 }

        var index = 0
        var weekStart = firstWeek.start
        while weekStart < monthInterval.end {
            if let weekEnd = date(byAdding: .day, value: 6, to: weekStart),
               targetDate >= weekStart && targetDate <= weekEnd {
                return index
            }
            weekStart = date(byAdding: .weekOfYear, value: 1, to: weekStart) ?? monthInterval.end
            index += 1
        }
        return max(index - 1, 0)
    }
}
