import Foundation
import Security

/// 앱을 지워도 남는 저장소.
///
/// ## 왜 필요한가
///
/// 식별자를 담아둘 자리가 지금까지 둘이었다. `UserDefaults`는 앱을 지우면 같이
/// 사라지고, iCloud 키–값 저장소는 남지만 **늦게 온다** — 그 저장소는 비동기라서,
/// 재설치 직후 앱이 막 뜬 순간에 읽으면 아직 비어 있을 수 있다. 그 순간 코드는
/// "아무 데도 없다"고 판단해 새 식별자를 만들고, 그걸 iCloud에 **덮어쓴다.**
/// 한 사람이 둘이 되고, 같은 계정의 다른 기기까지 그때 새 사람으로 갈아탄다.
///
/// 키체인은 그 사이를 메운다. 앱을 지워도 남고, 읽는 데 네트워크가 필요 없다.
/// 그래서 재설치한 기기는 iCloud가 도착하기 전에도 **자기가 누구였는지 알고 있고**,
/// 새 값을 만들어 덮어쓸 일이 없다.
///
/// 기기를 건너는 일은 여전히 iCloud 몫이다 — 키체인은 이 기기에만 있다.
///
/// ## 왜 `ThisDeviceOnly`인가
///
/// iCloud 키체인으로 동기화시키면 저장소가 둘이 되고, 둘이 서로 다른 값을 들고
/// 있을 때 무엇이 정본인지 정할 방법이 없다. 기기를 건너는 값은 iCloud 키–값
/// 저장소 하나로 충분하다. 여기서 원하는 것은 **재설치를 건너는 것**뿐이다.
nonisolated struct KeychainIdentityStore: IdentityStore {
    private let service: String

    init(service: String = "com.Mosco.App.analytics") {
        self.service = service
    }

    private func query(forKey key: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            // **맥(Catalyst)에서도 iOS와 같은 키체인을 쓰게 한다.** 이걸 빼면
            // 맥은 옛 파일 기반 키체인으로 가서 동작이 갈린다.
            kSecUseDataProtectionKeychain as String: true
        ]
    }

    func string(forKey key: String) -> String? {
        var lookup = query(forKey: key)
        lookup[kSecReturnData as String] = true
        lookup[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        guard SecItemCopyMatching(lookup as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data,
              let value = String(data: data, encoding: .utf8),
              !value.isEmpty
        else { return nil }
        return value
    }

    func set(_ value: String, forKey key: String) {
        guard let data = value.data(using: .utf8) else { return }
        let attributes: [String: Any] = [
            kSecValueData as String: data,
            // 첫 잠금 해제 뒤부터 읽을 수 있으면 된다. 앱이 뜨는 시점은 늘 그 뒤다.
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]

        let status = SecItemUpdate(query(forKey: key) as CFDictionary, attributes as CFDictionary)
        guard status == errSecItemNotFound else { return }
        _ = SecItemAdd(query(forKey: key).merging(attributes) { _, new in new } as CFDictionary, nil)
    }
}
