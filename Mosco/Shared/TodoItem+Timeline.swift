import Foundation

/// 시간축에 놓기 위한 값들. 계산 자체는 `TimelineLayout`에 있고(테스트로 덮임)
/// 여기서는 모델의 필드를 넘겨주기만 한다.
extension TodoItem {
    var timelineStartMinute: Int {
        TimelineLayout.minutes(start: startTime, end: endTime).start
    }

    var timelineEndMinute: Int {
        TimelineLayout.minutes(start: startTime, end: endTime).end
    }

    /// 블록 안에 적는 시각 — `오후 7시 - 오후 8시`. 종료가 없으면 시작만.
    var timeRangeLabel: String? {
        guard let startTime else { return nil }
        let calendar = Calendar.current
        func label(_ date: Date) -> String {
            let c = calendar.dateComponents([.hour, .minute], from: date)
            return TimeExpressionParser.koreanTimeLabel(hour24: c.hour ?? 0, minute: c.minute ?? 0)
        }
        guard let endTime, endTime > startTime else { return label(startTime) }
        return "\(label(startTime)) - \(label(endTime))"
    }
}
