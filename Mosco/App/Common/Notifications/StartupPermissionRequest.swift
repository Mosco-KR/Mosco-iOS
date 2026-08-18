import Foundation

/// 첫 실행에 필요한 권한을 **한 줄로 세워** 묻는다.
///
/// 시스템은 권한 창을 한 번에 하나씩만 보여준다. 두 개를 동시에 요청하면 뒤엣것이
/// 조용히 무시되거나, 앞엣것을 고르는 사이 뒤엣것이 덮친다. 그래서 순서를 정해
/// 앞것이 끝난 뒤에 다음을 묻는다.
///
/// **묻는 시점은 안내(튜토리얼)가 끝난 뒤다.** 앱을 아직 보지도 못한 사람에게 첫
/// 화면에서 결정을 두 개 요구하면 대부분 거부하고, 한 번 거부된 권한은 앱이 다시
/// 물을 수 없다. 안내를 끝까지 본 사람은 이 앱이 알림을 왜 쓰는지 알고 있다.
///
/// 순서는 **알림 → 위치**다. 알림이 이 앱의 본래 기능(시작 시간 알림)에 걸린
/// 권한이라 먼저 묻는 것이 맥락에 맞고, 날씨는 곁들이는 기능이다.
@MainActor
enum StartupPermissionRequest {

    /// 아직 결정되지 않은 권한만 묻는다. 이미 허용했거나 거부한 것은 건드리지 않는다 —
    /// 거부된 권한은 앱에서 다시 물을 수 없고, 시도해봐야 아무 창도 안 뜬다.
    static func run(
        notifications: TodoNotificationScheduler,
        weather: WeatherStore
    ) async {
        await notifications.requestAuthorizationOnFirstLaunch()

        // 날씨를 꺼둔 사람에게 위치를 물을 이유가 없다.
        guard weather.isEnabled, weather.permission == .notDetermined else { return }
        weather.loadIfNeeded()
    }
}
