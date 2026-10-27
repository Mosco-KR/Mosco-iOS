import Foundation

/// 메모장이 무엇을 어떤 순서로 세우는가.
///
/// 화면 안에 두면 테스트가 한 줄도 닿지 않는다(`TodoListPage`와 같은 이유).
/// 메모는 규칙이 단순하지만, 단순한 규칙일수록 화면에 묻혀 있으면 바꿀 때마다
/// 눈으로 확인하게 된다.
nonisolated enum MemoList {

    /// 고정된 것이 먼저, 그다음 **마지막으로 고친 순서**다.
    ///
    /// 만든 순서가 아니라 고친 순서인 게 중요하다 — 메모는 며칠 전에 만든 장보기
    /// 목록을 오늘 다시 여는 식으로 쓴다. 그걸 만든 날 기준으로 아래에 묻어두면
    /// 매번 찾아 내려가야 한다.
    static func sorted(_ notes: [MemoNote]) -> [MemoNote] {
        notes.sorted { lhs, rhs in
            if lhs.isPinned != rhs.isPinned { return lhs.isPinned }
            return lhs.updatedAt > rhs.updatedAt
        }
    }

    /// 적은 글 전체에서 찾는다. 빈 검색어면 전부 돌려준다.
    static func search(_ query: String, in notes: [MemoNote]) -> [MemoNote] {
        let keyword = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !keyword.isEmpty else { return notes }
        return notes.filter { $0.body.lowercased().contains(keyword) }
    }

    /// 빈 메모는 남기지 않는다.
    ///
    /// 새 메모는 **빈 채로 먼저 만들어** 편집기를 연다(제목부터 묻지 않으려고).
    /// 그래서 아무것도 안 적고 나오면 빈 장이 쌓인다 — 나올 때 지운다.
    static func shouldDiscard(_ note: MemoNote) -> Bool {
        note.isEmpty
    }
}
