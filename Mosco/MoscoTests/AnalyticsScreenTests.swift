import Foundation
import Testing

/// 화면 이름은 한번 정하면 바꾸기 어렵다 — 바꾸는 순간 그 전 데이터와 이어지지 않아서
/// 보고서에 같은 화면이 두 줄로 나온다. 그래서 규칙을 테스트로 묶어둔다.
@Suite("화면 로깅")
struct AnalyticsScreenTests {

    @Test("화면 이름은 서로 겹치지 않는다")
    func 이름이_겹치지_않는다() {
        let names = AnalyticsScreen.allCases.map(\.rawValue)
        #expect(Set(names).count == names.count)
    }

    @Test("화면 이름은 snake_case다", arguments: AnalyticsScreen.allCases)
    func 이름_규칙(screen: AnalyticsScreen) {
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyz_")
        #expect(
            screen.rawValue.unicodeScalars.allSatisfy(allowed.contains),
            "'\(screen.rawValue)'에 소문자와 밑줄이 아닌 글자가 있다"
        )
        #expect(!screen.rawValue.isEmpty)
    }

    /// Firebase는 `screen_view`라는 이름과 `firebase_screen` 파라미터로 와야만
    /// "페이지 및 화면" 보고서에 넣는다. 이름을 바꾸면 그 보고서가 조용히 빈다 —
    /// 앱은 멀쩡히 돌고 아무도 모르는 채로 몇 달이 간다.
    @Test("예약된 이름과 파라미터로 나간다")
    func 예약어를_지킨다() {
        let event = AnalyticsEvent.screenViewed(.settings)
        #expect(event.name == "screen_view")
        #expect(event.parameters["firebase_screen"] == "settings")
        #expect(event.parameters["firebase_screen_class"] == "settings")
    }

    @Test("화면마다 자기 이름이 실린다", arguments: AnalyticsScreen.allCases)
    func 이름이_실린다(screen: AnalyticsScreen) {
        #expect(AnalyticsEvent.screenViewed(screen).parameters["firebase_screen"] == screen.rawValue)
    }
}
