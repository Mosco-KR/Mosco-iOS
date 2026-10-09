import Foundation
import Testing

/// 위젯 깨우기를 모아 보내는 규칙.
///
/// 이 규칙에 테스트가 붙어야 하는 이유는, 틀렸을 때 **아무 일도 안 일어나는
/// 모양으로 틀리기 때문**이다. 너무 자주 보내면 갱신 예산이 말라서 위젯이 안
/// 바뀌고, 안 보내도 위젯이 안 바뀐다 — 둘 다 "위젯이 그대로"로 보여서 눈으로는
/// 구분할 수 없다.
/// **직렬로 돌린다.** `WidgetRefresh`는 앱에 하나뿐인 자리라 테스트가 그 전역
/// 상태를 갈아끼우며 쓴다. 병렬로 돌리면 한 테스트가 `await`로 기다리는 사이
/// 다른 테스트가 `reset()`으로 그 예약을 지워버려서, 코드가 멀쩡해도 실패한다.
@MainActor
@Suite(.serialized)
struct WidgetRefreshTests {

    /// 테스트마다 깨끗한 상태로 시작한다. `WidgetRefresh`는 전역이라 앞선
    /// 테스트가 예약해둔 것이 남아 있으면 다음 테스트가 그걸 본다.
    private func arrange(delay: Duration = .milliseconds(30)) -> Counter {
        WidgetRefresh.reset()
        WidgetRefresh.delay = delay
        let counter = Counter()
        WidgetRefresh.reload = { counter.bump() }
        return counter
    }

    @MainActor
    final class Counter {
        private(set) var count = 0
        func bump() { count += 1 }
    }

    @Test("연달아_부르면_한_번만_보낸다")
    func 모으기() async {
        let counter = arrange()

        WidgetRefresh.schedule()
        WidgetRefresh.schedule()
        WidgetRefresh.schedule()
        #expect(counter.count == 0, "기다리는 동안에는 아직 보내지 않는다")

        try? await Task.sleep(for: .milliseconds(120))
        #expect(counter.count == 1, "세 번 눌러도 요청은 한 번이어야 한다")
    }

    @Test("기다린_뒤에_보낸다")
    func 한_번() async {
        let counter = arrange()

        WidgetRefresh.schedule()
        #expect(WidgetRefresh.hasPending)

        try? await Task.sleep(for: .milliseconds(120))
        #expect(counter.count == 1)
        #expect(!WidgetRefresh.hasPending, "보내고 나면 예약이 비어야 다음 요청이 깨끗하게 선다")
    }

    /// 앱이 뒤로 갈 때의 자리. 예약해둔 작업이 돌아간다는 보장이 없으므로
    /// 그때는 모으기를 포기하고 바로 보낸다.
    @Test("앱이_뒤로_가면_기다리지_않고_바로_보낸다")
    func 즉시() async {
        let counter = arrange(delay: .seconds(10))

        WidgetRefresh.schedule()
        WidgetRefresh.flush()
        #expect(counter.count == 1, "10초를 기다리지 않고 지금 보내야 한다")
        #expect(!WidgetRefresh.hasPending)

        // 예약해둔 것이 뒤늦게 또 나가면 안 된다 — 같은 변경으로 두 번 깨우는 꼴이다.
        try? await Task.sleep(for: .milliseconds(80))
        #expect(counter.count == 1)
    }

    @Test("아무것도_예약하지_않았으면_보내지_않는다")
    func 조용함() async {
        let counter = arrange()
        try? await Task.sleep(for: .milliseconds(120))
        #expect(counter.count == 0)
    }
}
