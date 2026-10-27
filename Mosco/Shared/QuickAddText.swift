import Foundation

/// 한 줄 입력에 담긴 제목과 메모를 가른다.
///
/// ## 왜 줄바꿈인가
///
/// 메모를 붙이는 길이 멀었다 — 제목만 적어 저장한 뒤, 그 줄을 꾹 눌러 메뉴를 열고,
/// '메모 추가'로 시트를 띄우고, 입력 칸을 한 번 더 눌러야 커서가 왔다. 적는 순간에는
/// 메모를 붙일 방법이 아예 없었다. 그런데 입력창은 이미 네 줄까지 늘어나는 칸이라,
/// **거기서 줄을 바꾸는 것이 가장 짧은 길**이다.
///
/// 그래서 **첫 줄은 제목, 그 아래는 전부 메모**다. 손짓이 하나도 늘지 않는다.
///
/// ## 화면이 아니라 여기 있는 이유
///
/// 입력창 안에 두면 테스트가 한 줄도 닿지 않는다(`TimeExpressionParser`를 꺼낸 것과
/// 같은 이유). 제목과 메모를 가르는 일은 빈 줄·공백·줄바꿈만 있는 입력처럼 사람이
/// 눈으로 확인하기 지루한 경우가 많아서, 더 꺼내 둘 값어치가 있다.
nonisolated enum QuickAddText {

    /// 첫 줄과 그 아래를 가른다. 메모가 없으면 nil — 빈 문자열과 "안 적음"을
    /// 한 가지 상태로 다루는 `TodoItem.memo`의 규칙과 같다.
    static func split(_ raw: String) -> (title: String, memo: String?) {
        // 앞쪽 빈 줄은 버린다. 줄바꿈부터 시작하는 입력에서 제목이 빈 채로
        // 갈라지면, 적은 것이 전부 메모가 되고 저장은 조용히 거절된다.
        let text = raw.drop(while: { $0.isNewline || $0 == " " })

        guard let lineBreak = text.firstIndex(where: \.isNewline) else {
            return (text.trimmingCharacters(in: .whitespacesAndNewlines), nil)
        }

        let title = text[..<lineBreak].trimmingCharacters(in: .whitespacesAndNewlines)
        let memo = text[text.index(after: lineBreak)...]
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return (title, memo.isEmpty ? nil : memo)
    }

    /// 제목 줄만. 분류기와 시각 인식이 쓴다 — 메모에 적은 "7시"가 일정 시각으로
    /// 잡히거나, 메모 본문이 카테고리 판정에 섞이면 안 된다.
    static func titleLine(_ raw: String) -> String {
        split(raw).title
    }

    /// 수정하려고 입력창에 되돌려 넣을 한 덩어리. 가른 것을 다시 붙인다 —
    /// 왕복이 맞지 않으면 메모가 있는 할 일을 고치는 순간 메모가 날아간다.
    static func joined(title: String, memo: String?) -> String {
        guard let memo, !memo.isEmpty else { return title }
        return "\(title)\n\(memo)"
    }
}
