import Foundation

/// 1.4.0에서 오늘 탭이 사라진 것을 **예전 버전을 써본 사람에게만** 한 번 알린다.
///
/// 탭 바를 눌러 오늘 할 일을 보던 사람은 업데이트 뒤 그 자리를 잃는다. 누르는 횟수는
/// 같지만(앱 켜기 → 오늘 누르기) 어디를 누르는지가 바뀌었다. 처음 깐 사람은 튜토리얼이
/// 같은 것을 가르치므로 이 안내가 필요 없다.
///
/// 상태는 셋이다 — 아직 안 정함(""), 띄울 차례(`pending`), 끝(`done`).
/// 1.4.0을 처음 켤 때 **튜토리얼이 시작되기 전에** 한 번 정한다: 그때 이미 안내에 답한
/// 적이 있으면(예전 버전에서 답했다) 예전 사용자다.
enum CalendarHomeNotice {
    static let key = "calendarHomeNotice"
    static let pending = "pending"
    static let done = "done"

    static func decide(current: String, answeredTutorialBefore: Bool) -> String {
        guard current.isEmpty else { return current }
        return answeredTutorialBefore ? pending : done
    }
}
