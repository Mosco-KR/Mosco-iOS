import Foundation

/// 시스템 리뷰창이 **실제로 떴는지**를 창 목록의 변화로 판정한다.
///
/// `requestReview()`는 아무것도 돌려주지 않는다. 조건이 안 맞으면 조용히 아무 일도
/// 일어나지 않고, 호출한 쪽은 떴는지 안 떴는지를 알 수 없다. 그런데 **이 둘은 완전히
/// 다른 사건이다** — 떴는데 사람이 그냥 닫은 것이면 문구나 순간을 고쳐야 하고,
/// 애초에 안 떴다면 고칠 곳은 전혀 다른 데다. 2026-10-25까지 우리는 이 둘을 구분하지
/// 못한 채 "요청을 냈다"만 세고 있었다.
///
/// 시스템 창은 앱의 창 위에 **별도의 `UIWindow`로** 올라온다. 그래서 요청 직전과
/// 직후의 창 목록을 비교해서, 새로 생긴 창이 있으면 떴다고 본다. 어디까지나 어림이다 —
/// 애플이 창을 어떻게 올리는지는 공개된 약속이 아니다. 그래서 이 판정은 **기회를
/// 쓸지 말지에만** 쓰고, 사람에게 보이는 것은 아무것도 여기 걸지 않는다. 틀려도
/// 손해가 "한 번 더 물어본다"에서 멈춘다.
///
/// 키보드는 예외다. 할 일을 완료한 직후에는 입력창이 다시 뜨면서 키보드 창이
/// 같이 올라올 수 있는데, 그걸 리뷰창으로 세면 안 떴는데 떴다고 적게 된다.
enum ReviewPromptWindows {
    /// 요청 직전의 창 식별자들과 직후의 창 목록을 받아, 리뷰창이 올라왔다고 볼지 정한다.
    static func didPresentReviewWindow(
        before: Set<ObjectIdentifier>,
        after: [(id: ObjectIdentifier, className: String)]
    ) -> Bool {
        after.contains { window in
            !before.contains(window.id) && !isSystemChrome(window.className)
        }
    }

    /// 리뷰창이 아닌 걸 아는 창들. 이름으로 거르는 게 마음에 들지는 않지만,
    /// 익스텐션으로 올라오는 키보드 창은 클래스 이름 말고 붙잡을 것이 없다.
    private static func isSystemChrome(_ className: String) -> Bool {
        className.contains("Keyboard")
            || className.contains("TextEffects")
            || className.contains("RemoteKeyboard")
    }
}
