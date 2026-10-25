import Foundation
import Testing

/// 한 줄 입력에서 제목과 메모를 가르는 규칙.
///
/// 왕복(가르고 다시 붙이기)을 특히 본다 — 수정하려고 입력창에 되돌려 넣는 길이
/// 어긋나면, 메모가 있는 할 일을 고치는 순간 메모가 사라진다.
@Suite("제목과 메모 가르기")
struct QuickAddTextTests {

    @Test func 줄바꿈이_없으면_전부_제목이다() {
        let result = QuickAddText.split("차비내기")
        #expect(result.title == "차비내기")
        #expect(result.memo == nil)
    }

    @Test func 첫_줄은_제목_그_아래는_메모다() {
        let result = QuickAddText.split("차비내기\n현금으로 2만원")
        #expect(result.title == "차비내기")
        #expect(result.memo == "현금으로 2만원")
    }

    @Test func 메모가_여러_줄이면_그대로_담는다() {
        let result = QuickAddText.split("장보기\n우유\n달걀\n식빵")
        #expect(result.title == "장보기")
        #expect(result.memo == "우유\n달걀\n식빵")
    }

    @Test func 줄바꿈만_눌렀으면_메모는_없다() {
        let result = QuickAddText.split("차비내기\n")
        #expect(result.title == "차비내기")
        #expect(result.memo == nil)
    }

    @Test func 메모_자리에_공백만_있으면_메모는_없다() {
        let result = QuickAddText.split("차비내기\n   \n  ")
        #expect(result.title == "차비내기")
        #expect(result.memo == nil)
    }

    /// 줄바꿈부터 시작하는 입력. 앞쪽 빈 줄을 안 버리면 제목이 빈 채로 갈라져서
    /// 적은 것이 전부 메모가 되고, 저장은 조용히 거절된다.
    @Test func 앞쪽_빈_줄은_버린다() {
        let result = QuickAddText.split("\n\n차비내기\n현금으로 2만원")
        #expect(result.title == "차비내기")
        #expect(result.memo == "현금으로 2만원")
    }

    @Test func 빈_입력은_제목도_메모도_없다() {
        let result = QuickAddText.split("   \n  ")
        #expect(result.title.isEmpty)
        #expect(result.memo == nil)
    }

    @Test func 제목_줄만_꺼낸다() {
        // 메모에 적은 시각이 일정 시각으로 잡히면 안 된다 — 그래서 분류기와
        // 시각 인식은 이 값을 쓴다.
        #expect(QuickAddText.titleLine("회의\n7시에 자료 보내기") == "회의")
    }

    @Test func 가른_것을_다시_붙이면_같은_입력이_된다() {
        let raw = "장보기\n우유, 달걀"
        let parts = QuickAddText.split(raw)
        #expect(QuickAddText.joined(title: parts.title, memo: parts.memo) == raw)
    }

    @Test func 메모가_없으면_붙여도_제목_하나다() {
        #expect(QuickAddText.joined(title: "차비내기", memo: nil) == "차비내기")
        #expect(QuickAddText.joined(title: "차비내기", memo: "") == "차비내기")
    }
}
