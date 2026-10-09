import Observation

/// 앱 밖(위젯·라이브 액티비티)에서 들어온 길을 화면에 전한다.
///
/// URL은 `SceneDelegate`가 받는데(이 앱은 UIKit 생명주기라 `.onOpenURL`이 안 돈다),
/// 화면을 옮기는 건 달력의 내비게이션이 한다. 둘 사이를 이 깃발 하나로 잇는다 —
/// 앱이 꺼져 있다 켜진 경우 URL이 화면보다 먼저 오므로, 깃발로 남겨두면 달력이
/// 뜨면서 집어 간다.
@MainActor
@Observable
final class AppNavigation {
    static let shared = AppNavigation()
    private init() {}

    /// 오늘 페이지를 열어달라는 요청과 그 출처(`widget`·`live_activity`).
    /// 달력이 열고 나서 nil로 내린다. 출처는 `day_opened`에 실린다.
    var todayPageRequest: String?

    /// 다른 탭으로 보내달라는 요청. `RootTabView`가 집어 가고 nil로 내린다.
    ///
    /// **화면이 직접 탭을 바꾸지 않는다.** 탭을 옮기는 자리는 `RootTabView`
    /// 하나뿐이다 — 두 곳에서 건드리면 서로 밀어내는 순간이 생긴다. 오늘 탭 머리의
    /// "넘어온 것" 줄이 이 길로 할 일 탭에 간다.
    var tabRequest: AppTab?
}
