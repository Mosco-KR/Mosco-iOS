import Foundation

/// 안내 첫 단계에서 따라 적게 하는 연습용 할 일.
///
/// **이름이 앞, 시간이 뒤여야 한다.** 입력창은 시간 표현을 알아채는 순간 칩을 띄우고,
/// 안내는 그 칩이 뜨는 순간 "시간을 누르세요"로 넘어간다. 예전 예시 `7시 러닝`은
/// `7시`까지만 쳐도 칩이 떠서 `러닝`을 치는 도중에 지시가 바뀌었다. 게다가 `7시`는
/// 오전/오후가 갈려 칩이 둘이었고, 그 자리에서 칩을 누르면 제목이 비어 이름을 한 번
/// 더 적어야 했다. `러닝 오후 7시`는 마지막 글자를 칠 때 처음 칩이 뜨고, 칩이 하나이며,
/// 눌러도 `러닝`이 남는다.
///
/// 화면 구조체가 아니라 여기 두는 건 그 세 가지를 테스트로 묶어두기 위해서다
/// (`TutorialPracticeTests`).
nonisolated enum TutorialPractice {
    /// 안내가 보여주는 예시. 사용자가 그대로 따라 적는다.
    static var sample: String { sample(for: .current) }
    /// 시간 칩을 누른 뒤 남는 이름. 대신 만들어줄 때도 이 이름으로 만든다.
    static var title: String { title(for: .current) }
    /// 예시의 시각(24시간제). 대신 만들어줄 때도 이 시각을 붙인다.
    static let hour24 = 19

    /// 언어마다 예시가 다르지만 **위의 세 조건은 똑같이 지켜야 한다** — 마지막 글자에서
    /// 처음 칩이 뜨고, 칩이 하나이고, 눌러도 이름이 남는다. 테스트가 세 언어를 다 돈다.
    static func sample(for language: AppLanguage) -> String {
        switch language {
        case .ko: "러닝 오후 7시"
        case .en: "Run 7pm"
        case .ja: "ランニング 午後7時"
        }
    }

    static func title(for language: AppLanguage) -> String {
        switch language {
        case .ko: "러닝"
        case .en: "Run"
        case .ja: "ランニング"
        }
    }
}
