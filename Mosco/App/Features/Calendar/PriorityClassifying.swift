import Foundation

/// 입력한 제목을 보고 우선순위를 자동으로 추천하는 분류기의 인터페이스.
/// 지금은 CoreML 모델이 없어서(직접 학습·번들링 필요) 키워드 기반의 임시
/// 구현체(``KeywordPriorityClassifier``)만 있다 — .mlmodel을 준비되면
/// 이 프로토콜을 구현하는 CoreML 버전으로 바로 교체하면 된다(QuickAddView는
/// 이 프로토콜 하나만 알아서, 교체해도 UI 쪽은 손댈 필요가 없다).
protocol PriorityClassifying {
    func classify(_ text: String) async -> Priority?
}

/// 임시 구현체. 실제 판별은 아니고, 자주 쓰는 한국어 표현 몇 가지로 대충
/// 흉내만 낸다 — CoreML 모델이 준비되기 전까지 UI(로딩 표시, 전송 잠금 등)를
/// 실제로 동작시켜 보기 위한 자리표시자다.
struct KeywordPriorityClassifier: PriorityClassifying {
    private let mustKeywords = ["긴급", "필수", "마감", "당장", "즉시"]
    private let shouldKeywords = ["중요", "회의", "미팅", "약속"]
    private let couldKeywords = ["여유", "언젠가", "생각", "고려"]
    private let wontKeywords = ["보류", "취소", "나중"]

    func classify(_ text: String) async -> Priority? {
        // 실제 추론이 걸리는 느낌을 흉내 — CoreML 추론도 비슷한 정도의 지연이 있다.
        try? await Task.sleep(nanoseconds: 400_000_000)

        if mustKeywords.contains(where: text.contains) { return .must }
        if shouldKeywords.contains(where: text.contains) { return .should }
        if couldKeywords.contains(where: text.contains) { return .could }
        if wontKeywords.contains(where: text.contains) { return .wont }
        return nil
    }
}
