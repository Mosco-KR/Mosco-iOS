import Foundation

/// 주간 스트립(압축 캘린더)의 날짜 칸에 찍는 점.
///
/// **개수는 쓰지 않는다** — 4pt 점 옆에 숫자를 붙일 자리도 없고, 이 줄에서 알고 싶은
/// 것은 "여기 뭐가 있나" 하나다. 몇 개인지는 그 날을 누르면 아래 목록이 말한다.
nonisolated enum DayTodoMark: Equatable, Sendable {
    /// 아직 안 끝낸 것이 있다.
    case open
    /// 있던 것을 다 끝냈다. **"없는 날"과는 다르다** — 다 끝낸 날이 빈 날처럼
    /// 보이면 그날 뭘 했는지가 사라진다. 옅게 찍는다.
    case done

    /// 그날의 점. 걸치는 것이 하나도 없으면 nil이다.
    ///
    /// 반복까지 펼쳐 봐야 알 수 있어서(`TodoItem.occurs(on:)`) 화면에서 계산하면
    /// 테스트가 닿지 않는다. 일곱 날 × 할 일 수라 비용은 사실상 없다.
    static func mark(for day: Date, in todos: [TodoItem]) -> DayTodoMark? {
        var sawAny = false
        for todo in todos where todo.occurs(on: day) {
            sawAny = true
            // 체크가 없는 일(생일·월급날)은 '남은 일'이 아니다 — 그날 뭔가 있다는
            // 것만 옅은 점으로 말한다.
            if todo.countsAsRemaining(on: day) { return .open }
        }
        return sawAny ? .done : nil
    }
}
