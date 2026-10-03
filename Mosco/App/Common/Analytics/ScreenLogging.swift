import SwiftUI

extension View {
    /// 이 화면이 보일 때 `screen_view`를 남긴다.
    ///
    /// **`onAppear`가 아니라 `task`를 쓴다.** 둘 다 "뜰 때" 불리지만 `onAppear`는
    /// 같은 화면이 다시 그려지는 과정에서 여러 번 불릴 수 있다. `task`는 그 뷰가
    /// 화면에 붙어 있는 동안 한 번만 돌고 사라질 때 취소되므로, 한 번 들어간 것이
    /// 한 번으로 세어진다.
    ///
    /// 돌아올 때는 다시 센다. 하루 페이지를 열었다가 달력으로 나오면 달력이 한 번 더
    /// 세어지는데, 그게 맞다 — 사람은 달력을 두 번 본 것이다.
    func logScreen(_ screen: AnalyticsScreen) -> some View {
        task { Analytics.log(.screenViewed(screen)) }
    }
}
