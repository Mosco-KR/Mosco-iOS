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
        let configuration: ModelConfiguration
        if let url = sharedStoreURL() {
            migrateLegacyStoreIfNeeded(to: url)
            configuration = ModelConfiguration(schema: schema, url: url)
        } else {
            configuration = ModelConfiguration(schema: schema)
        }

        do {
            return try ModelContainer(for: schema, configurations: configuration)
        } catch {
            // 여기서 실패하면 데이터가 아예 안 열리는 상태라 더 할 수 있는 게 없다.
            fatalError("ModelContainer를 만들지 못했습니다: \(error)")
        }
    }

    private static func sharedStoreURL() -> URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupID)?
            .appending(path: "Mosco.store")
    }

    /// App Group으로 옮기기 전(앱 샌드박스)에 쌓인 데이터를 한 번 복사해온다.
    /// 이걸 안 하면 업데이트한 사용자에게는 할 일이 전부 사라진 것처럼 보인다.
    ///
    /// SQLite는 본체(.store) 말고도 -shm/-wal 사이드카 파일을 함께 쓰므로 셋 다
    /// 옮겨야 한다. 공유 위치에 이미 파일이 있으면(=이미 옮겼으면) 건드리지 않는다.
    private static func migrateLegacyStoreIfNeeded(to sharedURL: URL) {
        let fileManager = FileManager.default
        guard !fileManager.fileExists(atPath: sharedURL.path) else { return }

        guard let legacyURL = fileManager
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first?
            .appending(path: "default.store"),
            fileManager.fileExists(atPath: legacyURL.path)
        else { return }

        for suffix in ["", "-shm", "-wal"] {
            let source = URL(fileURLWithPath: legacyURL.path + suffix)
            let destination = URL(fileURLWithPath: sharedURL.path + suffix)
            guard fileManager.fileExists(atPath: source.path) else { continue }
            try? fileManager.copyItem(at: source, to: destination)
        }
    }
}
