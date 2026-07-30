import Foundation

/// 겹치는 블록들에 안정적인 행(row) 번호를 매긴다. 매주 새로 계산하면 같은
/// 다일(多日) 일정이 주마다 다른 줄로 튀거나, 다른 일정과 자리를 바꿔가며
/// 깜빡이는 것처럼 보인다 — 전체 블록을 한 번에 놓고 그리디 구간 스케줄링으로
/// 행을 배정해서, 한 일정은 항상 같은 줄에 그려지게 한다.
struct PositionedBlock: Identifiable, Equatable {
    let block: CalendarBlock
    let row: Int

    var id: String { block.id }
}

enum BlockLayout {
    static func position(_ blocks: [CalendarBlock]) -> [PositionedBlock] {
        // 여러 날에 걸친 블록을 먼저 배정해서 항상 위쪽 행을 먼저 차지하게 한다 —
        // 이어지는 굵은 막대가 위에서 안정적으로 자리 잡고, 하루짜리 블록들이
        // 그 아래로 채워지는 게 실제 캘린더 앱들의 관례와도 맞고 더 읽기 쉽다.
        // 같은 성격(다일/하루) 안에서는 시작일 → 우선순위 순으로 처리해, 먼저
        // 시작한(또는 더 중요한) 일정이 그 안에서 낮은(위쪽) 행을 먼저 차지한다.
        let sorted = blocks.sorted { lhs, rhs in
            let lhsMultiDay = lhs.start != lhs.end
            let rhsMultiDay = rhs.start != rhs.end
            if lhsMultiDay != rhsMultiDay { return lhsMultiDay }
            if lhs.start != rhs.start { return lhs.start < rhs.start }
            if lhs.priority != rhs.priority { return lhs.priority < rhs.priority }
            return lhs.end < rhs.end
        }

        var rowEnds: [Date] = [] // rowEnds[i] = 그 행에 마지막으로 들어간 블록의 종료일
        var result: [PositionedBlock] = []

        for block in sorted {
            if let rowIndex = rowEnds.firstIndex(where: { $0 < block.start }) {
                rowEnds[rowIndex] = block.end
                result.append(PositionedBlock(block: block, row: rowIndex))
            } else {
                rowEnds.append(block.end)
                result.append(PositionedBlock(block: block, row: rowEnds.count - 1))
            }
        }

        return result
    }
}
