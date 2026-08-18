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
/// **왜 iCloud에 두나.** 키체인은 재설치를 건너오지만 기기마다 다르다. iCloud
/// 키–값 저장소는 같은 Apple 계정이면 기기가 달라도 같은 값을 준다 — 이 앱은
/// 이미 iCloud로 할 일을 동기화하므로 새로 얻어야 할 권한도 없다.
///
/// iCloud를 못 쓰는 경우(로그인 안 됨)에도 로컬 값으로 계속 동작하고, 나중에
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
        local: any IdentityStore,
        newID: () -> String = { UUID().uuidString }
    ) -> (id: String, origin: IdentityOrigin) {
        // 1. iCloud에 있으면 그게 정본이다. 재설치도 기기 교체도 건너온 값이다.
        if let cloud, let existing = cloud.string(forKey: key), !existing.isEmpty {
            // 기기 저장소에도 적어둔다 — 다음 실행에서 iCloud가 늦게 붙어도
            // 곧바로 같은 값을 쓸 수 있다.
            local.set(existing, forKey: key)
            return (existing, .restoredFromCloud)
        }

        // 2. 로컬에만 있으면 그대로 쓰고, iCloud를 쓸 수 있으면 올려둔다.
        //    iCloud를 나중에 켠 사람이 여기로 온다.
        if let existing = local.string(forKey: key), !existing.isEmpty {
            cloud?.set(existing, forKey: key)
            return (existing, cloud == nil ? .created : .promotedFromLocal)
        }

        // 3. 아무 데도 없으면 새로 만든다. 진짜 첫 실행이다.
        let created = newID()
        local.set(created, forKey: key)
        cloud?.set(created, forKey: key)
        return (created, .created)
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
