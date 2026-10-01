import Foundation
import Testing

/// 안내 첫 단계의 예시 문장. 예전 예시 `7시 러닝`은 치는 도중에 칩이 떠서 지시가
/// 바뀌었고, 오전/오후를 물었고, 칩을 누르면 제목이 비었다. 셋 다 여기서 막는다.
@Suite("안내 연습 예시")
struct TutorialPracticeTests {

    @Test("예시를_끝까지_치기_전에는_시간_칩이_뜨지_않는다")
    func 끝까지_치기_전엔_칩이_없다() {
        let sample = TutorialPractice.sample
        for length in 1..<sample.count {
            let typed = String(sample.prefix(length))
            #expect(
                TimeExpressionParser.suggestion(in: typed) == nil,
                "'\(typed)'까지 쳤을 때 칩이 떠서 안내가 치는 도중에 넘어간다"
            )
        }
        #expect(TimeExpressionParser.suggestion(in: sample) != nil)
    }

    @Test("예시의_시각은_오전오후를_묻지_않는다")
    func 오전오후가_확정된다() throws {
        let suggestion = try #require(TimeExpressionParser.suggestion(in: TutorialPractice.sample))
        #expect(suggestion.startHour24 == TutorialPractice.hour24, "칩이 둘로 갈려 하나를 골라야 한다")
        #expect(suggestion.endHour24 == nil && suggestion.endHour12 == nil)
    }

    @Test("시간_칩을_누른_뒤에도_이름이_남는다")
    func 칩을_누르면_이름이_남는다() throws {
        let suggestion = try #require(TimeExpressionParser.suggestion(in: TutorialPractice.sample))
        // 입력창이 칩을 누를 때 하는 일과 같다 — 알아챈 구간을 걷고 공백을 정리한다.
        let remaining = TutorialPractice.sample
            .replacingOccurrences(of: suggestion.matched, with: "")
            .trimmingCharacters(in: .whitespaces)
        #expect(remaining == TutorialPractice.title)
    }
}
