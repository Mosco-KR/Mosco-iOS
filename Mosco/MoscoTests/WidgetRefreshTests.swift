import Foundation
import Testing

/// 위젯 깨우기를 모아 보내는 규칙.
///
/// 이 규칙에 테스트가 붙어야 하는 이유는, 틀렸을 때 **아무 일도 안 일어나는
/// 모양으로 틀리기 때문**이다. 너무 자주 보내면 갱신 예산이 말라서 위젯이 안
/// 바뀌고, 안 보내도 위젯이 안 바뀐다 — 둘 다 "위젯이 그대로"로 보여서 눈으로는
/// 구분할 수 없다.
///
/// **시계를 쓰지 않는다.** 기다리는 방법을 통째로 갈아끼우고 예약된 일 자체를
/// 기다린다. 실제 시계로 재면 바쁜 기계에서 흔들리는데(CI에서 실제로 깨졌다),
/// 그렇게 깨지는 테스트는 코드가 아니라 기계를 재는 것이라 곧 아무도 안 믿는다.
///
/// **직렬로 돌린다.** `WidgetRefresh`는 앱에 하나뿐인 자리라 테스트가 그 전역
/// 상태를 갈아끼우며 쓴다.
@MainActor
@Suite(.serialized)
struct WidgetRefreshTests {

    @MainActor
    final class Counter {
        private(set) var count = 0
        func bump() { count += 1 }
    }

    /// 기다림이 곧바로 끝나는 자리. 예약이 제대로 걸렸는지만 본다.
    private func arrangeImmediate() -> Counter {
        arrange { _ in }
    }

    /// 기다림이 끝나지 않는 자리. 기다리는 동안의 동작(모으기·즉시 보내기)을 본다.
    private func arrangeNeverFinishing() -> Counter {
        arrange { _ in try? await Task.sleep(for: .seconds(3600)) }
    }

    private func arrange(_ sleep: @escaping @Sendable (Duration) async -> Void) -> Counter {
        WidgetRefresh.reset()
        WidgetRefresh.sleep = sleep
        let counter = Counter()
        WidgetRefresh.reload = { counter.bump() }
        return counter
    }

    @Test("기다린_뒤에_한_번_보낸다")
    func 한_번() async {
        let counter = arrangeImmediate()

        WidgetRefresh.schedule()
        await WidgetRefresh.waitForPending()

        #expect(counter.count == 1)
        #expect(!WidgetRefresh.hasPending, "보내고 나면 예약이 비어야 다음 요청이 깨끗하게 선다")
    }

    @Test("연달아_부르면_한_번만_보낸다")
    func 모으기() async {
        let counter = arrangeImmediate()

        WidgetRefresh.schedule()
        WidgetRefresh.schedule()
        WidgetRefresh.schedule()
        await WidgetRefresh.waitForPending()

        #expect(counter.count == 1, "세 번 눌러도 요청은 한 번이어야 한다")
    }

    @Test("기다리는_동안에는_보내지_않는다")
    func 기다리는_중() {
        let counter = arrangeNeverFinishing()

        WidgetRefresh.schedule()

        #expect(counter.count == 0)
        #expect(WidgetRefresh.hasPending)
    }

    /// 앱이 뒤로 갈 때의 자리. 예약해둔 작업이 돌아간다는 보장이 없으므로
    /// 그때는 모으기를 포기하고 바로 보낸다.
    @Test("앱이_뒤로_가면_기다리지_않고_바로_보낸다")
    func 즉시() {
        let counter = arrangeNeverFinishing()

        WidgetRefresh.schedule()
        WidgetRefresh.flush()

        #expect(counter.count == 1, "기다림이 끝나기를 기다리지 않고 지금 보내야 한다")
        #expect(!WidgetRefresh.hasPending, "예약이 남아 있으면 같은 변경으로 두 번 깨운다")
    }

    @Test("아무것도_예약하지_않았으면_보내지_않는다")
    func 조용함() async {
        let counter = arrangeImmediate()
        await WidgetRefresh.waitForPending()
        #expect(counter.count == 0)
    }
}
