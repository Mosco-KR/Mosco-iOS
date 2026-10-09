import Foundation
import WidgetKit

/// 위젯을 다시 그려달라는 요청을 **모아서** 보낸다.
///
/// ## 왜 모으나
///
/// 완료를 연달아 누를 때마다 시스템을 깨우면 WidgetKit의 갱신 예산이 금세 바닥난다 —
/// 그러면 정작 바뀌어야 할 순간에 위젯이 안 바뀐다. 그렇다고 앱이 뒤로 갈 때까지
/// 미루면(예전 방식) 체크한 것이 홈 화면에 한참 뒤에야 반영된다.
///
/// 그래서 **마지막 요청으로부터 잠깐 기다렸다가 한 번만** 보낸다. 할 일 다섯 개를
/// 연달아 체크해도 요청은 한 번이고, 그 한 번은 앱을 벗어나기 전에 나간다.
///
/// ## 왜 `Shared`에 있나
///
/// 앱도 위젯도 라이브 액티비티도 같은 규칙으로 요청해야 한다. 한쪽만 모으면
/// 다른 쪽이 예산을 대신 태운다.
@MainActor
enum WidgetRefresh {
    /// 마지막 요청으로부터 이만큼 기다린다. 사람이 체크를 연달아 누르는 간격보다
    /// 넉넉하고, 앱을 벗어나기 전에는 끝날 만큼 짧다.
    static var delay: Duration = .seconds(2)

    /// 실제로 시스템에 보내는 일. 테스트가 갈아끼운다 — `WidgetCenter`는 테스트
    /// 프로세스에서 부를 수 없다.
    static var reload: @MainActor () -> Void = { WidgetCenter.shared.reloadAllTimelines() }

    private static var pending: Task<Void, Never>?

    /// 곧 다시 그려야 한다고 알린다. 이미 예약된 것이 있으면 그것을 물리고
    /// 시계를 다시 시작한다.
    static func schedule() {
        pending?.cancel()
        pending = Task {
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled else { return }
            pending = nil
            reload()
        }
    }

    /// 기다릴 수 없는 자리 — 앱이 뒤로 갈 때. 예약된 것이 있으면 물리고 지금 보낸다.
    ///
    /// **앱이 뒤로 가면 예약해둔 작업이 돌아간다는 보장이 없다.** 그래서 그 자리에서는
    /// 모으기를 포기하고 바로 보낸다. 어차피 그때가 마지막 요청이다.
    static func flush() {
        pending?.cancel()
        pending = nil
        reload()
    }

    /// 예약된 것이 있는가. 테스트가 본다.
    static var hasPending: Bool { pending != nil }

    /// 테스트가 자리를 치울 때.
    static func reset() {
        pending?.cancel()
        pending = nil
    }
}
