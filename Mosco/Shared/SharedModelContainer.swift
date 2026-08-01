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

    static let schema = Schema([TodoItem.self, TodoCategory.self])

    static func make() -> ModelContainer {
        let configuration = makeConfiguration()

        do {
            return try ModelContainer(for: schema, configurations: configuration)
        } catch {
            #if DEBUG
            // 아직 배포 전이라 스키마를 자주 바꾸는데, 그때마다 기존 저장소와
            // 안 맞아서 앱이 못 뜬다. 개발 중에는 저장소를 버리고 새로 만든다 —
            // 앱을 지웠다 다시 까는 수고를 없애기 위한 것이고, 그래서 릴리스
            // 빌드에는 절대 넣지 않는다(조용한 데이터 소실이 된다).
            resetStore()
            if let container = try? ModelContainer(for: schema, configurations: makeConfiguration()) {
                return container
            }
            #endif
            // 여기까지 오면 데이터가 아예 안 열리는 상태라 더 할 수 있는 게 없다.
            fatalError("ModelContainer를 만들지 못했습니다: \(error)")
        }
    }

    private static func makeConfiguration() -> ModelConfiguration {
        guard let url = sharedStoreURL() else {
            return ModelConfiguration(schema: schema)
        }
        return ModelConfiguration(schema: schema, url: url)
    }

    private static func sharedStoreURL() -> URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupID)?
            .appending(path: "Mosco.store")
    }

    #if DEBUG
    /// SQLite는 본체(.store) 말고 -shm/-wal 사이드카도 함께 쓰므로 셋 다 지워야
    /// 깨끗하게 다시 만들어진다.
    private static func resetStore() {
        guard let url = sharedStoreURL() else { return }
        for suffix in ["", "-shm", "-wal"] {
            try? FileManager.default.removeItem(atPath: url.path + suffix)
        }
    }
    #endif
}
