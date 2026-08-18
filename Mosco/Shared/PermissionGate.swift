import Foundation

/// 시스템 권한 하나의 상태. 알림·위치·라이브 액티비티가 각자 다른 타입을 쓰지만
/// 화면이 알아야 하는 것은 이 셋뿐이다.
nonisolated enum PermissionState: Equatable {
    /// 아직 안 물어봤다 — 토글을 켜면 시스템 창을 띄우면 된다.
    case notDetermined
    /// 허용됐다.
    case granted
    /// 거부됐다 — 앱에서는 되돌릴 수 없고 시스템 설정으로 보내야 한다.
    case denied
}

/// 토글을 켜려 할 때 무엇을 해야 하는가.
nonisolated enum ToggleIntent: Equatable {
    /// 시스템 권한 창을 띄운다.
    case requestPermission
    /// 앱에서 할 수 있는 게 없다 — 시스템 설정으로 보낸다.
    case openSystemSettings
    /// 권한은 이미 있다. 사용자 설정만 바꾼다.
    case enableDirectly
}

/// 권한이 걸린 스위치가 **무엇으로 보여야 하는가**를 정한다.
///
/// 예전엔 스위치가 `UserDefaults` 값만 읽었다. 그래서 기기 설정에서 알림을 끄고
/// 앱으로 돌아오면 **스위치는 켜진 채로 남았다** — 켜져 있는데 알림은 안 오는,
/// 사용자가 원인을 짐작할 방법이 없는 상태다. 저장된 값과 실제로 동작하는지는
/// 다른 이야기이고, 화면은 후자를 보여줘야 한다.
///
/// 사용자가 켜둔 기록(`userPreference`)은 지우지 않는다. 나중에 권한을 다시
/// 허용하면 원래 켜뒀던 대로 돌아오는 편이, 매번 다시 켜게 하는 것보다 낫다.
nonisolated enum PermissionGate {

    /// 스위치에 실제로 표시할 값.
    /// 사용자가 켜뒀더라도 권한이 없으면 **꺼진 것으로 보여준다.**
    static func isOn(userPreference: Bool, permission: PermissionState) -> Bool {
        guard userPreference else { return false }
        return permission == .granted
    }

    /// 스위치를 켜려 할 때 할 일.
    static func intent(for permission: PermissionState) -> ToggleIntent {
        switch permission {
        case .notDetermined: .requestPermission
        case .denied: .openSystemSettings
        case .granted: .enableDirectly
        }
    }

    /// 권한 때문에 꺼져 보이는 중인가 — 안내 문구를 띄울지 정하는 데 쓴다.
    /// 사용자가 스스로 끈 경우에는 아무 안내도 하지 않는다. 그건 의도한 상태다.
    static func isBlockedByPermission(userPreference: Bool, permission: PermissionState) -> Bool {
        userPreference && permission == .denied
    }
}
