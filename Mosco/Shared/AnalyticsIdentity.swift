import Foundation

/// 식별자를 담아둘 곳. iCloud와 로컬 저장소를 같은 모양으로 다뤄서
/// 결정 로직을 저장소 없이 테스트할 수 있게 한다.
nonisolated protocol IdentityStore {
    func string(forKey key: String) -> String?
    func set(_ value: String, forKey key: String)
}

/// 어디서 온 식별자인가 — 왜 이 값이 됐는지가 로그에 남아야 나중에
/// "재설치했는데 다른 사람으로 잡힌다"를 추적할 수 있다.
nonisolated enum IdentityOrigin: Equatable {
    /// iCloud에 있던 것을 그대로 썼다. 재설치·기기 교체를 건너온 값이다.
    case restoredFromCloud
    /// 키체인에 있던 것을 썼다. **이 기기에서 재설치했다**는 뜻이다 — iCloud가
    /// 아직 안 왔거나 못 쓰는 상태에서도 같은 사람으로 이어졌다.
    case restoredFromKeychain
    /// 로컬에만 있던 것을 iCloud로 올렸다. iCloud를 나중에 켠 경우.
    case promotedFromLocal
    /// 처음 만들었다.
    case created
}

/// 같은 사람을 같은 사람으로 세기 위한 익명 식별자.
///
/// **이름도 이메일도 아니다.** 앱이 만든 UUID 하나이고, 이 값만으로는 누구인지
/// 알 수 없다. 하는 일은 "이 이벤트들이 한 사람의 것인가"를 잇는 것뿐이다.
///
/// 왜 필요한가 — 이게 없으면 앱을 지웠다 깔 때마다 **새 사람**이 된다. 그러면
/// "튜토리얼을 건너뛴 사람이 나중에 돌아와서 다시 봤나" 같은 것을 물어볼 수
/// 없고, 재방문·리텐션은 전부 실제보다 낮게 잡힌다.
///
/// **저장소가 셋이고, 셋 다 다른 일을 한다.**
///
/// - iCloud 키–값 저장소: 같은 Apple 계정이면 **기기를 건넌다.** 다만 비동기라
///   재설치 직후 첫 실행에는 아직 안 와 있을 수 있다.
/// - 키체인: 앱을 지워도 남고 기다릴 필요가 없다. **재설치를 건넌다.** iCloud가
///   늦게 오는 그 순간을 메우는 것이 이것의 유일한 일이다 — 이게 없으면 그 틈에
///   새 값을 만들어 iCloud의 멀쩡한 값을 덮어쓴다(`KeychainIdentityStore`).
/// - `UserDefaults`: 가장 빠르고 가장 먼저 사라진다. 캐시로만 쓴다.
///
/// iCloud를 못 쓰는 경우(로그인 안 됨)에도 나머지로 계속 동작하고, 나중에
/// 로그인하면 그때 iCloud로 올린다(`promotedFromLocal`).
nonisolated enum AnalyticsIdentity {
    static let key = "analyticsUserID"

    /// 식별자를 정한다. **이미 있는 값을 절대 덮어쓰지 않는다** — 덮어쓰는 순간
    /// 그 사람은 통계에서 두 사람이 된다.
    ///
    /// - Parameters:
    ///   - cloud: iCloud 키–값 저장소. 못 쓰면 nil을 넘긴다.
    ///   - local: 기기 저장소. iCloud가 없을 때의 대비책.
    static func resolve(
        cloud: (any IdentityStore)?,
        keychain: (any IdentityStore)? = nil,
        local: any IdentityStore,
        newID: () -> String = { UUID().uuidString }
    ) -> (id: String, origin: IdentityOrigin) {
        // 1. iCloud에 있으면 그게 정본이다. 재설치도 기기 교체도 건너온 값이다.
        if let existing = value(in: cloud) {
            // 다른 저장소에도 적어둔다 — 다음 실행에서 iCloud가 늦게 붙어도
            // 곧바로 같은 값을 쓸 수 있다.
            local.set(existing, forKey: key)
            keychain?.set(existing, forKey: key)
            return (existing, .restoredFromCloud)
        }

        // 2. 키체인. **여기가 재설치를 막는 자리다.** iCloud 키–값 저장소는
        //    비동기라, 재설치 직후 첫 실행에서는 아직 비어 있을 수 있다. 그때
        //    곧장 새 값을 만들면 그 값이 iCloud의 멀쩡한 값을 덮어쓰고, 한 사람이
        //    둘이 된다. 키체인은 앱을 지워도 남고 기다릴 필요가 없다.
        if let existing = value(in: keychain) {
            local.set(existing, forKey: key)
            cloud?.set(existing, forKey: key)
            return (existing, .restoredFromKeychain)
        }

        // 3. 로컬에만 있으면 그대로 쓰고, 쓸 수 있는 곳에 올려둔다.
        //    iCloud를 나중에 켠 사람, 그리고 키체인을 쓰기 전 버전에서 올라온
        //    사람이 여기로 온다.
        if let existing = value(in: local) {
            cloud?.set(existing, forKey: key)
            keychain?.set(existing, forKey: key)
            return (existing, cloud == nil ? .created : .promotedFromLocal)
        }

        // 4. 아무 데도 없으면 새로 만든다. 진짜 첫 실행이다.
        let created = newID()
        local.set(created, forKey: key)
        keychain?.set(created, forKey: key)
        cloud?.set(created, forKey: key)
        return (created, .created)
    }

    /// 빈 문자열은 없는 것으로 친다 — 저장소에 따라 지운 자리에 빈 값이 남는다.
    private static func value(in store: (any IdentityStore)?) -> String? {
        guard let raw = store?.string(forKey: key), !raw.isEmpty else { return nil }
        return raw
    }

    static let reportedKey = "analyticsIdentityReported"

    /// 식별자가 어디서 왔는지(`analytics_identity`)를 이 설치에서 아직 안 남겼으면
    /// true를 돌려주고 남긴 것으로 적는다.
    ///
    /// **기기 저장소에만 적는다.** 앱을 지우면 같이 지워져서, 재설치하면 한 번 더
    /// 남는다 — 그게 이 이벤트가 재려는 것("재설치를 건너온 비율")이다. 예전엔
    /// 실행마다 남겨서 세션 수와 같은 숫자가 됐다.
    static func markReported(in local: any IdentityStore) -> Bool {
        guard local.string(forKey: reportedKey) != "1" else { return false }
        local.set("1", forKey: reportedKey)
        return true
    }
}

/// 개발자·테스트 기기 표시를 켜고 끄는 **링크**.
///
/// 개발자 기기 두 대가 9월 데이터에서 사용자 7~9명, 참여 세션의 15~30%로 잡혔다.
/// 지웠다 깔 때마다 새 사람이 됐고, 사용법 안내를 반복해서 본 기록이 실제 사용자의
/// 이탈 지점 숫자에 섞였다.
///
/// **켜는 법:** 그 기기에서 `mosco://internal`을 한 번 연다(메모 앱이나 사파리에서).
/// 끄려면 `mosco://internal/off`.
///
/// **표시는 기기 한 대에만 붙는다** — 어디에 적히고 어떻게 재설치를 건너오는지는
/// `DeviceIdentity`에 있다. 1.4.2까지는 계정 하나에 하나뿐이어서, 한 대를 표시하면
/// 같은 Apple 계정의 모든 기기가 같이 빠졌다.
enum InternalUser {
    static let host = "internal"

    /// 받은 URL이 이 표시를 켜거나 끄라는 것이면 그 값, 아니면 nil.
    static func command(from url: URL) -> Bool? {
        guard url.scheme == WidgetDeepLink.scheme, url.host == host else { return nil }
        let path = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        switch path {
        case "", "on": return true
        case "off": return false
        default: return nil
        }
    }
}

extension UserDefaults: IdentityStore {
    public func string(forKey key: String) -> String? {
        object(forKey: key) as? String
    }

    public func set(_ value: String, forKey key: String) {
        set(value as Any?, forKey: key)
    }
}

/// iCloud 키–값 저장소. 계정이 없거나 동기화가 꺼져 있으면 값이 안 올라가지만,
/// 그때도 읽고 쓰는 것 자체는 실패하지 않는다(로컬 캐시로 동작한다).
nonisolated struct CloudIdentityStore: IdentityStore {
    private let store = NSUbiquitousKeyValueStore.default

    /// iCloud를 실제로 쓸 수 있을 때만 만든다.
    init?() {
        guard FileManager.default.ubiquityIdentityToken != nil else { return nil }
        store.synchronize()
    }

    func string(forKey key: String) -> String? { store.string(forKey: key) }

    func set(_ value: String, forKey key: String) {
        store.set(value, forKey: key)
        store.synchronize()
    }
}
