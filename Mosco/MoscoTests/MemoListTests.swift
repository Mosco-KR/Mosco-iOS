import Foundation
import Testing

/// 메모장이 무엇을 어떤 순서로 세우는가.
///
/// **할 일과 섞이지 않는 것**이 요점이다 — 메모는 제 모델(`MemoNote`)을 갖고,
/// 날짜 안 정한 할 일은 지금까지처럼 할 일 탭에 그대로 선다.
@Suite("메모장")
struct MemoListTests {

    private func note(_ body: String, pinned: Bool = false, updated: TimeInterval = 0) -> MemoNote {
        let memo = MemoNote(body: body)
        memo.isPinned = pinned
        memo.updatedAt = Date(timeIntervalSince1970: 1_800_000_000 + updated)
        return memo
    }

    @Test func 첫_줄이_제목이고_나머지가_미리보기다() {
        let memo = MemoNote(body: "장보기\n우유\n달걀")
        #expect(memo.title == "장보기")
        #expect(memo.preview == "우유 달걀")
    }

    @Test func 한_줄짜리는_미리보기가_없다() {
        let memo = MemoNote(body: "우산 챙기기")
        #expect(memo.title == "우산 챙기기")
        #expect(memo.preview.isEmpty)
    }

    /// 만든 순서가 아니라 **고친 순서**다 — 며칠 전 장보기 목록을 오늘 다시 여는
    /// 식으로 쓰는 화면이라, 만든 날로 묻어두면 매번 찾아 내려가야 한다.
    @Test func 마지막으로_고친_것이_위로_온다() {
        let old = note("먼저 적은 것", updated: 0)
        let recent = note("방금 고친 것", updated: 600)
        #expect(MemoList.sorted([old, recent]).map(\.title) == ["방금 고친 것", "먼저 적은 것"])
    }

    @Test func 고정한_것이_그보다_먼저다() {
        let recent = note("방금 고친 것", updated: 600)
        let pinned = note("고정한 것", pinned: true, updated: 0)
        #expect(MemoList.sorted([recent, pinned]).map(\.title) == ["고정한 것", "방금 고친 것"])
    }

    @Test func 적은_글_전체에서_찾는다() {
        let notes = [note("장보기\n우유, 달걀"), note("들은 말\n다음 주 회의")]
        #expect(MemoList.search("달걀", in: notes).map(\.title) == ["장보기"])
        #expect(MemoList.search("회의", in: notes).map(\.title) == ["들은 말"])
        #expect(MemoList.search("  ", in: notes).count == 2)
    }

    /// 새 메모는 **빈 채로 먼저 만들어** 편집기를 연다(제목부터 묻지 않으려고).
    /// 그래서 아무것도 안 적고 나오면 빈 장이 쌓인다 — 나올 때 지운다.
    @Test func 빈_메모는_남기지_않는다() {
        #expect(MemoList.shouldDiscard(MemoNote(body: "")))
        #expect(MemoList.shouldDiscard(MemoNote(body: "   \n  ")))
        #expect(!MemoList.shouldDiscard(MemoNote(body: "한 글자")))
    }
}
