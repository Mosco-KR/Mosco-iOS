import SwiftUI

extension View {
    /// 이 화면이 보일 때 `screen_view`를 남긴다.
    ///
    /// **`onAppear`가 아니라 `task`를 쓴다.** 둘 다 "뜰 때" 불리지만 `onAppear`는
    /// 같은 화면이 다시 그려지는 과정에서 여러 번 불릴 수 있다. `task`는 그 뷰가
    /// 화면에 붙어 있는 동안 한 번만 돌고 사라질 때 취소되므로, 한 번 들어간 것이
    /// 한 번으로 세어진다.
    ///
    /// **탭 뿌리는 이걸로 세지 못한다.** 탭은 한 번 세워지면 앱이 떠 있는 동안
    /// 계속 살아 있어서 `task`가 다시 돌지 않는다 — 실행당 한 번만 찍힌다. 탭을
    /// 오가는 것은 `RootTabView`가 선택이 바뀔 때 직접 센다.
    ///
    /// `nil`을 받으면 아무것도 안 남긴다. 같은 화면이 탭 뿌리로도, 밀려 들어온
    /// 페이지로도 서는 경우(`DayTodosContentView`) 호출부에서 가르기 위한 것이다.
    func logScreen(_ screen: AnalyticsScreen?) -> some View {
        task {
            guard let screen else { return }
            Analytics.log(.screenViewed(screen))
        }
    }
}
