import Foundation

/// 한 주(週) 안에서 막대 하나가 차지할 자리. **렌더 시점에 계산할 게 남아있지 않은**
/// 최종 좌표다 — 행 번호, 시작/끝 열, 이어짐 여부까지 전부 확정되어 있다.
///
/// 예전엔 이 계산(`WeekBlockBarsView.segments`)이 렌더 중에 돌았다. 주마다
/// 전체 블록을 훑어 겹침을 구하고 행을 다시 매겼으니, 달을 넘길 때
/// 주 수 × 블록 수만큼의 일이 프레임 안에서 벌어졌다.
nonisolated struct BarSpec: Equatable, Identifiable, Sendable {
    let id: String
    let title: String
    let categoryColorHex: String?
    let calendarColorHex: String?
    let isCompleted: Bool
    let isRepeating: Bool
    /// 이 주 안에서 0부터 촘촘하게 다시 매긴 행 번호.
    let row: Int
    let startColumn: Int
    let endColumn: Int
    /// 이 주 시작 전부터 이어져 왔는지 / 다음 주로 이어지는지 — 모서리 처리에 쓴다.
    let continuesBefore: Bool
    let continuesAfter: Bool
    /// 걸쳐 있는 칸이 전부 이번 달 밖이면 true — 흐린 날짜 숫자와 톤을 맞춘다.
    let isDimmed: Bool
}

/// 한 주의 막대 배치.
nonisolated struct WeekBars: Equatable, Sendable {
    let bars: [BarSpec]
    /// 실제로 쓰인 행 수(0이면 이 주엔 일정이 없다).
    let rowCount: Int

    static let empty = WeekBars(bars: [], rowCount: 0)
}

/// 한 달치 막대 배치 — 주 순서는 `MonthLayout.weeks`와 1:1로 대응한다.
nonisolated struct MonthEventLayout: Equatable, Sendable {
    let weeks: [WeekBars]

    static let empty = MonthEventLayout(weeks: [])

    func week(_ index: Int) -> WeekBars {
        weeks.indices.contains(index) ? weeks[index] : .empty
    }
}

/// 겹치는 이벤트들에 안정적인 행 번호를 매긴다. 매주 새로 계산하면 같은 다일(多日)
/// 일정이 주마다 다른 줄로 튀거나, 다른 일정과 자리를 바꿔가며 깜빡이는 것처럼
/// 보인다 — 전체를 한 번에 놓고 그리디 구간 스케줄링으로 배정해서, 한 일정은
/// 항상 같은 줄에 그려지게 한다.
nonisolated enum EventRowAssigner {
    /// 반환값의 순서는 입력 순서가 아니라 시작일 순이다(행 배정 순서 그대로).
    static func assign(_ events: [CalendarEvent]) -> [(event: CalendarEvent, row: Int)] {
        // 시작일 순으로 처리하는 게 먼저다 — 다일 일정을 무조건 먼저 배정해버리면,
        // 그 일정이 시작하기 "전"에 이미 끝난 하루짜리 이벤트의 자리까지 통째로
        // 예약해버려서, 정작 겹치지도 않는 그 하루짜리가 애먼 아래 행으로 밀려나고
        // 원래 행엔 빈 공간만 남았다(예: 다일 일정이 7/31~8/3인데, 7/30에 끝나는
        // 하루짜리도 그 위 행을 못 쓰게 됨).
        // 같은 시작일 안에서만 다일 일정이 하루짜리보다 위쪽 행을 먼저 차지한다.
        let sorted = events.sorted { lhs, rhs in
            if lhs.start != rhs.start { return lhs.start < rhs.start }
            let lhsMultiDay = lhs.start != lhs.end
            let rhsMultiDay = rhs.start != rhs.end
            if lhsMultiDay != rhsMultiDay { return lhsMultiDay }
            if lhs.end != rhs.end { return lhs.end < rhs.end }
            // 나머지가 전부 같으면(흔히 같은 날 새 할 일이 끼어드는 경우) 먼저
            // 만든 쪽이 앞선다 — 안 그러면 어느 게 이길지 배열 순서에 우연히
            // 맡겨져서, 원래 그 행에 있던 반복 일정이 새 할 일한테 밀려나 보였다.
            return lhs.createdAt < rhs.createdAt
        }

        var rowEnds: [Date] = [] // rowEnds[i] = 그 행에 마지막으로 들어간 이벤트의 종료일
        var result: [(event: CalendarEvent, row: Int)] = []
        result.reserveCapacity(sorted.count)

        for event in sorted {
            if let rowIndex = rowEnds.firstIndex(where: { $0 < event.start }) {
                rowEnds[rowIndex] = event.end
                result.append((event, rowIndex))
            } else {
                rowEnds.append(event.end)
                result.append((event, rowEnds.count - 1))
            }
        }

        return result
    }
}
