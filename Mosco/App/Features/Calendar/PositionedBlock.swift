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
        // 시작일 순으로 처리하는 게 먼저다 — 다일 일정을 무조건 먼저 배정해버리면,
        // 그 일정이 시작하기 "전"에 이미 끝난 하루짜리 블록의 자리까지 통째로
        // 예약해버려서, 정작 겹치지도 않는 그 하루짜리 블록이 애먼 아래 행으로
        // 밀려나고 원래 행엔 빈 공간만 남았다(예: 다일 일정이 7/31~8/3인데,
        // 7/30에 끝나는 하루짜리 블록도 그 위 행을 못 쓰게 됨).
        // 같은 시작일 안에서만 다일 일정이 하루짜리보다 낮은(위쪽) 행을 먼저
        // 차지하게 해서, 그날 처음 등장할 땐 여전히 안정적으로 위 자리를 잡는다.
        let sorted = blocks.sorted { lhs, rhs in
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
