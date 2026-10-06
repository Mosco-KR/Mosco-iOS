import Foundation

/// 이 사람이 쓰는 기기 한 대. iCloud에 등록부로 쌓인다.
nonisolated struct DeviceRecord: Equatable, Codable, Sendable {
    /// 8자 16진수. **짧게 만든 이유는 사람이 눈으로 맞춰야 하기 때문이다** —
    /// GA4 보고서에 뜬 값과 설정 화면에 뜬 값을 비교해서 "이게 내 14 Pro다"를
    /// 알아내는 게 이 값의 유일한 용도다. UUID 36자는 그 일에 못 쓴다.
    let id: String
    /// `utsname.machine` 그대로(`iPhone17,1`). GA4의 기종 열은 때로 그냥 "iPhone"이라
    /// 두 대를 가를 수 없어서 우리가 따로 싣는다.
    let model: String
    /// 개발자·테스트 기기인가.
    var isInternal: Bool
    let firstSeen: Date
}

/// 기기를 **한 대씩** 알아보기 위한 등록부.
///
/// ## 왜 필요한가
///
/// 9월 데이터에서 개발자 기기 두 대가 사용자 7~9명으로 잡혔다. 그걸 빼려고
/// `internal_user` 표시를 만들었는데, 그 값은 **계정 하나에 하나**였다 —
/// iCloud에 "이 사람은 내부"라고만 적혀서, 한 대를 표시하면 같은 Apple 계정의
/// 모든 기기가 같이 빠졌다. 기기별로 켜고 끌 수가 없었고, 보고서에서 어느 행이
/// 어느 기기인지도 기종 이름으로 눈대중해야 했다.
///
/// 이제 iCloud에는 기기 **목록**이 들어간다. 각 줄에 짧은 id와 기종, 내부 표시가
/// 있어서 한 대만 표시할 수 있고, 다른 기기에서도 그 목록이 보인다.
///
/// ## 재설치를 건너오는 방법
///
/// 기기를 영구히 식별하는 값은 앱이 가질 수 없다 — `identifierForVendor`도 앱을
/// 지우면 바뀐다. 그래서 **기종이 같고 내부로 표시된 기기가 등록부에 있으면 그
/// 표시를 물려받는다.** 재설치한 14 Pro는 내부 표시를 다시 얻고, 같은 계정의 다른
/// 기종은 영향이 없다. 같은 기종 두 대를 하나만 내부로 두고 싶은 경우에는 틀리지만,
/// 그런 상황보다 재설치가 훨씬 잦다 — 지웠다 깔 때마다 새 사람이 되는 것이 애초에
/// 이 전체를 만든 이유다.
nonisolated enum DeviceIdentity {
    /// iCloud에 둘 등록부.
    static let registryKey = "analyticsDevices"
    /// 이 설치가 쓰는 기기 id.
    static let localKey = "analyticsDeviceID"
    /// 1.4.2까지 쓰던 계정 단위 표시.
    ///
    /// **한 번 읽어서 등록부로 옮겨 담고 바로 내린다.** 읽기만 하고 남겨두면
    /// 그 값이 계정에 계속 붙어 있어서, **앞으로 추가되는 기기까지** 전부 내부로
    /// 물려받는다 — 기기별로 가르려고 이걸 만든 것인데 그러면 제자리다.
    /// 새로 쓰는 일은 없다.
    static let legacyInternalKey = "analyticsInternalUser"

    /// 이 기기를 등록부에 세우고, 내부 표시까지 정해서 돌려준다.
    ///
    /// **이미 있는 id는 절대 새로 만들지 않는다** — 바꾸는 순간 보고서에서 한 대가
    /// 두 대가 된다.
    static func resolve(
        cloud: (any IdentityStore)?,
        local: any IdentityStore,
        model: String,
        now: Date = .now,
        newID: () -> String = Self.makeID
    ) -> (device: DeviceRecord, registry: [DeviceRecord]) {
        var registry = current(cloud: cloud, local: local)
        let id = local.string(forKey: localKey).flatMap { $0.isEmpty ? nil : $0 } ?? newID()
        local.set(id, forKey: localKey)

        // 1.4.2까지의 계정 단위 표시, 또는 같은 기종의 내부 표시를 물려받는다.
        let legacy = local.string(forKey: legacyInternalKey) == "1"
            || cloud?.string(forKey: legacyInternalKey) == "1"
        let inherited = legacy || registry.contains { $0.model == model && $0.isInternal }

        let device: DeviceRecord
        if let index = registry.firstIndex(where: { $0.id == id }) {
            // 등록부에 있던 기기 — 내부 표시는 둘 중 하나라도 켜져 있으면 켜진 것이다.
            registry[index].isInternal = registry[index].isInternal || inherited
            device = registry[index]
        } else {
            device = DeviceRecord(id: id, model: model, isInternal: inherited, firstSeen: now)
            registry.append(device)
        }

        write(registry, to: cloud, local: local)
        // 옛 표시는 등록부로 옮겨 담은 뒤 내린다(위 `legacyInternalKey` 주석).
        if legacy {
            local.set("0", forKey: legacyInternalKey)
            cloud?.set("0", forKey: legacyInternalKey)
        }
        return (device, registry)
    }

    /// 이 기기의 내부 표시를 켜거나 끈다. **다른 기기는 건드리지 않는다** —
    /// 기종이 같은 줄만 함께 따라간다(재설치를 건너오는 규칙과 짝을 맞춘다.
    /// 껐는데 같은 기종의 옛 줄이 켜진 채로 남으면 다음 실행에 다시 켜진다).
    static func mark(
        _ on: Bool,
        deviceID: String,
        model: String,
        cloud: (any IdentityStore)?,
        local: any IdentityStore
    ) -> [DeviceRecord] {
        var registry = current(cloud: cloud, local: local)
        for index in registry.indices where registry[index].id == deviceID || registry[index].model == model {
            registry[index].isInternal = on
        }
        write(registry, to: cloud, local: local)
        return registry
    }

    static func isInternal(deviceID: String, in registry: [DeviceRecord]) -> Bool {
        registry.first { $0.id == deviceID }?.isInternal ?? false
    }

    /// 8자 16진수. 보고서에서 눈으로 맞출 수 있는 길이다.
    static func makeID() -> String {
        String(UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(8)).lowercased()
    }

    // MARK: - 저장

    /// 지금 쓸 등록부. **iCloud에 있으면 그게 정본이다** — 재설치도 기기 교체도
    /// 건너온 목록이다. 비어 있으면 기기에 있던 것을 올린다(iCloud를 나중에 켠 경우).
    ///
    /// 키–값 저장소는 마지막에 쓴 쪽이 통째로 이긴다. 두 기기가 거의 동시에 쓰면
    /// 한 대가 목록에서 빠질 수 있는데, 모든 기기가 실행할 때마다 자기를 다시
    /// 세우므로 다음 실행에 돌아온다. 목록은 **쌓이는 기록이 아니라 지금 보이는
    /// 명단**으로 쓴다.
    static func current(cloud: (any IdentityStore)?, local: any IdentityStore) -> [DeviceRecord] {
        guard let cloud else { return read(from: local) }
        let fromCloud = read(from: cloud)
        return fromCloud.isEmpty ? read(from: local) : fromCloud
    }

    /// 등록부는 JSON 문자열 하나로 둔다. iCloud 키–값 저장소도, `UserDefaults`도
    /// 문자열은 확실히 받는다 — 여러 키로 쪼개면 일부만 올라간 중간 상태가 생긴다.
    static func read(from store: any IdentityStore) -> [DeviceRecord] {
        guard let raw = store.string(forKey: registryKey), let data = raw.data(using: .utf8) else { return [] }
        return (try? JSONDecoder().decode([DeviceRecord].self, from: data)) ?? []
    }

    private static func write(_ registry: [DeviceRecord], to cloud: (any IdentityStore)?, local: any IdentityStore) {
        guard let data = try? JSONEncoder().encode(registry),
              let raw = String(data: data, encoding: .utf8)
        else { return }
        // 기기 저장소에도 적어둔다 — iCloud가 늦게 붙는 실행에서도 곧바로 같은
        // 목록을 쓸 수 있다.
        local.set(raw, forKey: registryKey)
        cloud?.set(raw, forKey: registryKey)
    }
}

/// 이 기기의 기종 문자열.
///
/// `UIDevice.current.name`은 iOS 16부터 권한 없이는 기종 이름만 돌려주고,
/// `UIDevice.current.model`은 "iPhone"처럼 뭉뚱그린 값이다. `utsname.machine`은
/// `iPhone17,1`처럼 세대까지 갈라서, 손에 든 두 대를 구분하는 데 쓸 수 있다.
///
/// 맥 Catalyst에서는 이 값이 칩 아키텍처(`arm64`)로 나와서 아이폰과 구분이
/// 안 된다. 그래서 맥에서는 앞에 표시를 붙인다.
nonisolated enum DeviceModel {
    static let current: String = {
        var info = utsname()
        uname(&info)
        let machine = withUnsafeBytes(of: &info.machine) { raw in
            String(cString: raw.baseAddress!.assumingMemoryBound(to: CChar.self))
        }
        #if targetEnvironment(macCatalyst)
        return "mac-\(machine)"
        #else
        return machine
        #endif
    }()
}
