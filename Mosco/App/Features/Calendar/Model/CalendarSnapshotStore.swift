import Foundation
import Observation

/// 캘린더 스냅샷을 소유하고, 데이터가 바뀔 때만 백그라운드에서 다시 만든다.
///
/// 이 타입이 있는 이유는 "세 개의 시계"를 떼어놓기 위해서다. 반복 전개·행 배정·주별
/// 좌표 계산은 **할 일이 바뀔 때만**(드물게) 돌아야 하는데, 예전엔 화면 body가 돌
/// 때마다 딸려 들어갔다. 특히 재계산 여부를 판단하려고 모든 할 일의 모든 필드를
/// 문자열로 이어붙이던 키(`blocksKey`)가 매 body마다 O(N)으로 실행됐다 — 달을
/// 넘기는 그 프레임 안에서도.
@MainActor
@Observable
final class CalendarSnapshotStore {
    /// 뷰가 읽는 유일한 값. 통째로 교체되며, `==`는 version 하나만 본다.
    private(set) var snapshot: CalendarSnapshot = .empty

    @ObservationIgnored private var todos: [TodoSnapshot] = []
    @ObservationIgnored private var center: CalendarMonth = .containing(Date())
    @ObservationIgnored private var version = 0
    @ObservationIgnored private var rebuildTask: Task<Void, Never>?

    /// 중심에서 이만큼 멀어지면 그때 범위를 다시 잡는다. 계산 반경(8개월)보다
    /// 작아야 가장자리에 닿기 전에 새 범위가 준비된다.
    private static let recenterThreshold = 4

    /// 할 일 목록이 바뀌었을 때 호출. 값이 실제로 달라졌을 때만 재계산한다.
    func ingest(_ items: [TodoSnapshot]) {
        guard items != todos else { return }
        todos = items
        rebuild()
    }

    /// 보고 있는 달이 옮겨갔을 때 호출. 달마다 부르지 않고, 계산해둔 범위의
    /// 가장자리에 가까워졌을 때만 실제로 다시 계산한다 — 스와이프마다 전 범위를
    /// 다시 펼치면 애초에 스냅샷으로 뺀 의미가 없다.
    func focus(on month: CalendarMonth) {
        guard abs(center.distance(to: month)) >= Self.recenterThreshold else { return }
        center = month
        rebuild()
    }

    private func rebuild() {
        rebuildTask?.cancel()
        version += 1

        let todos = self.todos
        let center = self.center
        let version = self.version

        rebuildTask = Task { [weak self] in
            let built = await Task.detached(priority: .userInitiated) {
                CalendarSnapshotBuilder.build(todos: todos, center: center, version: version)
            }.value
            guard !Task.isCancelled else { return }
            self?.snapshot = built
        }
    }
}
