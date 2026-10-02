import Foundation
import Testing

/// 카테고리 자동 분류의 기록과 덮어쓰기. 예전엔 분류가 돌 때마다 이벤트를 남겨
/// 전체 이벤트의 57%가 타이핑 소음이었고, 수정하려고 열면 분류기가 사람이 골라둔
/// 카테고리를 갈아치웠다.
@MainActor
struct CategorySuggestionLogTests {

    @Test("여러_번_분류돼도_저장할_때_한_번만_남는다")
    func 저장할_때_한_번() {
        var log = CategorySuggestionLog()
        for _ in 0..<8 { log.didClassify(matched: true) }
        #expect(log.eventsOnSave.map(\.name) == ["category_suggested"])
    }

    @Test("분류기가_골라_넣은_것을_바꿨으면_override가_같이_남는다")
    func 바꾸면_override() {
        var log = CategorySuggestionLog()
        log.didClassify(matched: true)
        log.didPickManually(changed: true)
        #expect(log.eventsOnSave.map(\.name) == ["category_suggested", "category_overridden"])
    }

    @Test("같은_걸_다시_누른_건_override가_아니다")
    func 같은_걸_누르면_아니다() {
        var log = CategorySuggestionLog()
        log.didClassify(matched: true)
        log.didPickManually(changed: false)
        #expect(log.eventsOnSave.map(\.name) == ["category_suggested"])
    }

    @Test("나중_분류가_못_찾아도_앞서_넣은_건_골라준_것으로_센다")
    func 한_번_넣었으면_골라준_것() {
        var log = CategorySuggestionLog()
        log.didClassify(matched: true)
        log.didClassify(matched: false)
        log.didPickManually(changed: true)
        #expect(log.eventsOnSave.map(\.name) == ["category_suggested", "category_overridden"])
        guard case let .categorySuggested(matched) = log.eventsOnSave.first else {
            Issue.record("첫 이벤트가 category_suggested가 아니다")
            return
        }
        #expect(matched)
    }

    @Test("분류기가_아무것도_못_찾았으면_matched가_false로_남는다")
    func 못_찾음() {
        var log = CategorySuggestionLog()
        log.didClassify(matched: false)
        guard case let .categorySuggested(matched) = log.eventsOnSave.first else {
            Issue.record("이벤트가 없다")
            return
        }
        #expect(!matched)
    }

    @Test("분류가_한_번도_안_돌았으면_아무것도_안_남긴다")
    func 분류_없으면_없다() {
        var log = CategorySuggestionLog()
        log.didPickManually(changed: true)
        #expect(log.eventsOnSave.isEmpty)
    }

    @Test("수정_중에는_분류기가_카테고리를_덮어쓰지_않는다")
    func 수정_중엔_안_덮어쓴다() {
        let log = CategorySuggestionLog()
        #expect(!log.allowsAutoAssign(isEditing: true), "수정하려고 열면 골라둔 카테고리가 바뀐다")
        #expect(log.allowsAutoAssign(isEditing: false))
    }

    @Test("직접_고른_뒤에는_분류기가_덮어쓰지_않는다")
    func 직접_고르면_안_덮어쓴다() {
        var log = CategorySuggestionLog()
        log.didPickManually(changed: true)
        #expect(!log.allowsAutoAssign(isEditing: false))
    }

    @Test("저장하고_나면_다음_할_일은_처음부터_센다")
    func 저장하면_초기화() {
        var log = CategorySuggestionLog()
        log.didClassify(matched: true)
        log.didPickManually(changed: true)
        log.reset()
        #expect(log.eventsOnSave.isEmpty)
        #expect(log.allowsAutoAssign(isEditing: false))
    }
}
