import CloudKit
import Foundation
import Observation

/// iCloud 동기화가 지금 되고 있는지, 안 된다면 무엇 때문인지.
///
/// **이 화면을 만든 이유**: 앱스토어 빌드를 지웠다 다시 깔았더니 데이터가 통째로
/// 사라지는 일이 있었다. 원인은 동기화가 처음부터 안 되고 있었던 것인데, 지금까지
/// 그 실패는 `SharedModelContainer.make()`의 `try?` 하나에 삼켜져 콘솔에만 남았다 —
/// 사용자는 물론 개발자도 "이 기기는 백업되지 않는다"는 걸 알 방법이 없었다.
/// 조용히 실패하는 것이 데이터를 잃는 것보다 먼저 온 문제다.
enum CloudSyncState: Equatable {
    /// 저장소가 CloudKit과 함께 열렸고 계정도 정상이다.
    case active
    /// iCloud 계정이 없다(로그아웃 상태).
    case noAccount
    /// 기기 관리 정책 등으로 iCloud를 쓸 수 없다.
    case restricted
    /// 계정 상태를 물어보는 데 실패했다.
    case unknown
    /// 저장소를 CloudKit으로 못 열어 **로컬 전용**으로 물러났다. 계정이 멀쩡해도
    /// 여기 올 수 있다 — 컨테이너 설정이 안 맞거나 스키마가 배포 안 됐을 때다.
    case localOnly

    /// 이 기기의 데이터가 iCloud에 올라가고 있는가.
    var isSyncing: Bool { self == .active }
}

@Observable
@MainActor
final class CloudSyncStore {
    private(set) var state: CloudSyncState = .unknown

    /// 설정 화면이 뜰 때와 앱이 전면으로 돌아올 때 부른다 — 사용자가 설정 앱에서
    /// iCloud에 로그인하고 돌아왔을 수 있다.
    func refresh() async {
        // 저장소가 이미 로컬로 물러났다면 계정 상태와 무관하게 동기화는 없다.
        // 이걸 먼저 보는 게 중요하다 — 계정은 멀쩡한데 컨테이너/스키마 문제로
        // 물러난 경우가 실제로 있었고, 그때 "사용 가능"이라고 하면 거짓말이 된다.
        if SharedModelContainer.isCloudSyncActive == false {
            state = .localOnly
            return
        }

        do {
            switch try await CKContainer(identifier: SharedModelContainer.cloudKitContainerID).accountStatus() {
            case .available: state = .active
            case .noAccount: state = .noAccount
            case .restricted: state = .restricted
            default: state = .unknown
            }
        } catch {
            state = .unknown
        }
    }
}
