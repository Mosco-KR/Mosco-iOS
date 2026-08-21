// **Mac(Catalyst)에는 ActivityKit이 없다.** 라이브 액티비티는 iOS 잠금화면과
// 다이나믹 아일랜드의 것이라 맥에는 그릴 자리 자체가 없다. 파일째 빠지고,
// 그 자리를 부르던 화면도 맥에서는 항목을 감춘다
// (`TodoLiveActivityController.isSupported`).
#if !targetEnvironment(macCatalyst)

import ActivityKit
import Foundation

/// 잠금화면과 다이나믹 아일랜드에 띄우는 **사용자가 고른 할 일 하나**.
///
/// **앱과 위젯 익스텐션이 같은 타입을 봐야 한다.** 라이브 액티비티는 앱이 시작하고
/// 위젯 익스텐션이 그린다 — 두 프로세스가 이 값을 인코딩/디코딩으로 주고받으므로
/// 한쪽에만 있는 타입이면 아예 성립하지 않는다. 그래서 `Shared/`에 둔다.
///
/// **어느 할 일인가는 `Attributes`에 있다.** 예전엔 활동 하나가 하루를 대표하면서
/// 일정이 끝나면 다음 것으로 내용만 갈아끼웠는데, 이제는 사용자가 목록에서 직접
/// 고른 하나만 띄운다 — 활동이 사는 동안 대상이 바뀌지 않으므로 안 바뀌는 쪽에 둔다.
/// 앱을 껐다 켰을 때 시스템에서 되찾은 활동이 어느 할 일의 것인지도 이걸로 안다.
struct TodoActivityAttributes: ActivityAttributes {
    /// 이 활동이 대표하는 날(자정의 epoch 초, 앱 전체가 쓰는 `dayKey` 규칙).
    ///
    /// 완료를 기록할 때 어느 날의 인스턴스인지 알아야 한다 — 반복 일정은 날마다
    /// 따로 완료되므로, 이게 없으면 엉뚱한 날이 체크된다.
    let dayKey: String

    /// 어느 할 일인지. 완료 버튼이 무엇을 체크할지, 그리고 앱이 다시 켜졌을 때
    /// 이 활동을 아직 띄워둬도 되는지 확인할 때 쓴다.
    let todoID: String

    struct ContentState: Codable, Hashable {
        var event: Event
    }

    struct Event: Codable, Hashable {
        let title: String
        let categoryName: String?
        let colorHex: String?
        /// 소속 캘린더 이름. 어느 묶음에도 안 넣었으면 nil.
        let calendarName: String?
        /// 반복 일정인지. 앱의 셀과 같게 `repeat` 아이콘 하나로만 말한다 —
        /// 규칙("매주 화")까지 적으면 태그 줄이 길어진다.
        let isRepeating: Bool
        /// 디데이로 표시해둔 일인지. 남은 날짜는 안 센다(앱의 셀과 같은 규칙).
        let isDDay: Bool

        /// 시작 시각 그 자체. **남은 시간은 앱이 아니라 시스템이 센다.**
        ///
        /// 예전엔 앱이 "N분"을 계산해서 넣었는데, 그 방식은 앱이 자는 동안 숫자가
        /// 그대로 멈춰 있었다 — 잠금화면을 켜라고 만든 기능이 정작 잠금화면에서
        /// 거짓말을 했다. 이제 이 `Date`를 뷰의 `Text(timerInterval:)`에 넘겨서
        /// 앱이 꺼져 있어도 스스로 줄어들게 한다.
        ///
        /// `staleDate`도 이 값이다. 시작 시각이 지나면 시스템이 활동을 stale로
        /// 바꿔주고, 뷰는 그때 남은 시간 표기를 걷는다(`TodoLiveActivity` 참고).
        let startDate: Date

        /// "오후 4시 43분". 위젯 프로세스에서 날짜 포매팅을 다시 하지 않으려고 값으로 넣는다.
        /// 세는 숫자와 달리 **절대 시각은 앱이 자도 영원히 맞다.**
        let startLabel: String
        /// "오후 5시 15분". 종료 시각을 안 적어둔 일정은 nil.
        let endLabel: String?
        /// 적어둔 메모. 확장 화면에서 두어 줄까지 보여준다 — 잠금화면에서 일정을
        /// 봤을 때 "뭘 준비해야 하지"까지 답하려면 제목만으로는 부족하다.
        let memo: String?
    }
}

#endif
