import Foundation
import SwiftData

/// 앱과 위젯이 같은 저장소를 보게 만드는 컨테이너.
///
/// 기본 위치(앱 샌드박스의 Application Support)에 두면 위젯 익스텐션은 그 파일을
/// 못 읽는다 — 익스텐션은 별도 샌드박스라서다. 그래서 App Group 공유 컨테이너로
/// 옮겨서 양쪽이 같은 파일을 열게 한다.
///
/// App Group을 켜기 전(개발 중 설정이 아직 안 된 경우)에도 앱이 죽지 않도록,
/// 공유 컨테이너를 못 찾으면 기본 위치로 조용히 되돌아간다.
enum SharedModelContainer {
    /// Xcode의 Signing & Capabilities > App Groups에 등록한 것과 같아야 한다.
    static let appGroupID = "group.com.Mosco.App"
    /// iCloud 컨테이너. Apple Developer 포털의 App ID에 CloudKit 케이퍼빌리티와
    /// 이 이름의 컨테이너가 있어야 하고, 앱·위젯 양쪽 entitlements에도 들어가야 한다.
    static let cloudKitContainerID = "iCloud.com.Mosco.App"

    static let schema = Schema([TodoItem.self, TodoCategory.self, TodoCalendar.self])

    /// 실행 인자로 명시할 때만 저장소를 버린다(개발용).
    static let resetLaunchArgument = "-MoscoResetStore"

    static func make() -> ModelContainer {
        #if DEBUG
        // 예전엔 스키마가 안 맞으면 **자동으로** 저장소를 지웠다. iCloud를 켠
        // 지금은 그게 위험하다 — 로컬을 지우면 클라우드와의 관계가 꼬이고,
        // 최악의 경우 빈 상태가 올라간다. 그래서 자동으로 하지 않고 실행 인자로
        // 명시할 때만 한다(Xcode: Scheme > Run > Arguments).
        if ProcessInfo.processInfo.arguments.contains(resetLaunchArgument) {
            resetStore()
        }
        #endif

        if let container = try? ModelContainer(for: schema, configurations: makeConfiguration()) {
            return container
        }

        // 여기까지 왔다면 대개 iCloud 쪽 문제다 — Apple Developer 포털의 App ID에
        // CloudKit 케이퍼빌리티/컨테이너가 아직 없거나, entitlements와 이름이 다르거나,
        // 기기에 iCloud 계정이 없을 때. 그 사정으로 앱이 아예 안 뜨게 두는 건 과하므로
        // 로컬 전용으로 물러나서 계속 쓸 수 있게 한다(동기화만 안 된다).
        if let local = try? ModelContainer(for: schema, configurations: localOnlyConfiguration()) {
            // 지금까지 이 물러섬은 콘솔에만 남았다 — 동기화가 안 되는 사용자가
            // 얼마나 되는지 아무도 몰랐다. 앱 실행 초반이라 sink가 아직 안 붙었을
            // 수 있으므로 버퍼에 적어두고 앱이 나중에 함께 보낸다.
            AnalyticsBuffer.record(.storeLocalFallback)
            print("""
            [Mosco] iCloud 저장소를 열지 못해 로컬 전용으로 실행합니다. \
            동기화가 필요하면 Apple Developer 포털의 App ID에 CloudKit 케이퍼빌리티와 \
            '\(cloudKitContainerID)' 컨테이너가 있는지, 기기에 iCloud 계정이 로그인돼 있는지 확인하세요.
            """)
            return local
        }

        // 로컬조차 못 열면 데이터가 아예 안 열리는 상태라 더 할 수 있는 게 없다.
        fatalError("ModelContainer를 만들지 못했습니다. 개발 중이라면 \(resetLaunchArgument) 인자로 저장소를 초기화해보세요.")
    }

    /// App Group 파일 + CloudKit 개인 데이터베이스. 둘은 서로 배타적이지 않다 —
    /// 위젯과 앱은 계속 같은 로컬 파일을 보고, 그 파일이 iCloud와 동기화된다.
    ///
    /// **위젯도 반드시 이 함수를 써야 한다.** 같은 파일을 한쪽은 CloudKit으로,
    /// 다른 쪽은 로컬 전용으로 열면 설정이 안 맞아 컨테이너 생성이 실패하고,
    /// 위젯은 그걸 조용히 삼켜(`try?`) 빈 목록을 그린다.
    static func makeConfiguration() -> ModelConfiguration {
        guard let url = sharedStoreURL() else {
            return ModelConfiguration(schema: schema, cloudKitDatabase: .private(cloudKitContainerID))
        }
        return ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .private(cloudKitContainerID))
    }

    /// iCloud를 못 쓸 때의 폴백 — 같은 파일을 CloudKit 없이 연다.
    static func localOnlyConfiguration() -> ModelConfiguration {
        guard let url = sharedStoreURL() else {
            return ModelConfiguration(schema: schema, cloudKitDatabase: .none)
        }
        return ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none)
    }

    private static func sharedStoreURL() -> URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupID)?
            .appending(path: "Mosco.store")
    }

    #if DEBUG
    /// SQLite는 본체(.store) 말고 -shm/-wal 사이드카도 함께 쓰므로 셋 다 지워야
    /// 깨끗하게 다시 만들어진다. iCloud가 켜져 있으면 지운 뒤 클라우드에서 다시
    /// 받아오므로, 정말 비우려면 iCloud 설정에서도 데이터를 지워야 한다.
    private static func resetStore() {
        guard let url = sharedStoreURL() else { return }
        for suffix in ["", "-shm", "-wal"] {
            try? FileManager.default.removeItem(atPath: url.path + suffix)
        }
    }
    #endif
}
