import Foundation

/// 입력창 하나가 할 일 하나를 만드는 동안, 카테고리 자동 분류가 어떻게 됐는지 들고 있다.
///
/// **두 가지를 바로잡으려고 꺼냈다.**
///
/// 1. 기록이 타이핑 소음이었다. 예전엔 분류가 돌 때마다(입력이 0.2초 멈출 때마다)
///    `category_suggested`를 남겨서, 할 일 하나에 평균 7.7번 찍히고 전체 이벤트의
///    57%를 차지했다. 그 숫자로는 분류기가 맞히는지 알 수 없었다. 이제는 **저장할 때
///    한 번만** 남긴다 — 분류기가 골라 넣었는지와, 사람이 그걸 바꿨는지.
/// 2. 사람이 고른 카테고리를 분류기가 덮어썼다. 수정하려고 열면 제목이 다시 채워지며
///    분류가 돌아 원래 카테고리를 갈아치웠고, 새로 적을 때도 직접 고른 뒤 글자를 더
///    치면 다시 바뀌었다. 이제 **수정 중이거나 사람이 직접 골랐으면 손대지 않는다.**
///
/// 화면 구조체 밖에 두는 건 위 규칙을 테스트로 묶어두기 위해서다
/// (`CategorySuggestionLogTests`).
struct CategorySuggestionLog {
    /// 이번 할 일에서 분류가 한 번이라도 돌았다.
    private(set) var classified = false
    /// 분류기가 카테고리를 골라 넣은 적이 있다. 나중 분류가 아무것도 못 찾아도
    /// 앞서 넣은 카테고리는 그대로 남으므로, 한 번 넣었으면 계속 true다.
    private(set) var assigned = false
    /// 사람이 카테고리를 직접 골랐다.
    private(set) var pickedManually = false
    /// 분류기가 넣은 것을 사람이 다른 것으로 바꿨다.
    private(set) var overridden = false

    /// 분류 결과를 지금 카테고리에 넣어도 되는가.
    func allowsAutoAssign(isEditing: Bool) -> Bool {
        !isEditing && !pickedManually
    }

    mutating func didClassify(matched: Bool) {
        classified = true
        if matched { assigned = true }
    }

    /// 사람이 카테고리를 골랐다. `changed`는 지금 카테고리와 다른 걸 골랐는지 —
    /// 같은 걸 다시 누른 건 뒤집은 게 아니다.
    mutating func didPickManually(changed: Bool) {
        if changed, assigned { overridden = true }
        pickedManually = true
    }

    /// 새 할 일을 저장할 때 남길 이벤트. 분류가 안 돌았으면 아무것도 없다.
    var eventsOnSave: [AnalyticsEvent] {
        guard classified else { return [] }
        var events: [AnalyticsEvent] = [.categorySuggested(matched: assigned)]
        if overridden { events.append(.categoryOverridden) }
        return events
    }

    /// 저장했거나 입력창을 비웠다 — 다음 할 일은 처음부터 센다.
    mutating func reset() {
        self = CategorySuggestionLog()
    }
}
