import Foundation
import Testing

/// 안내 이탈 — 지금까지 `skipped`/`finished` 둘만 기록돼서, 도중에 그냥 떠난
/// 사람은 통계에 아예 안 잡혔다. 건너뛰기("필요 없다")와 이탈("막혔다")은
/// 다른 신호인데 하나는 세고 하나는 안 센 셈이다.
@Suite("안내 이탈 감지")
struct TutorialFunnelTests {

    @Test("단계를_적어두면_다음_실행에서_이탈로_잡힌다")
    func 이탈_감지() {
        let store = MemoryStore()
        TutorialFunnel.mark(step: "pickTime", in: store)

        // 앱이 죽었다 다시 켜진 상황 — 안내는 지금 안 돌고 있다
        let pending = TutorialFunnel.pendingAbandonment(in: store, isRunningNow: false)
        #expect(pending == "pickTime", "어느 단계에서 떠났는지가 이 기능의 전부다")
    }

    @Test("정상_종료하면_이탈로_안_잡힌다")
    func 정상_종료() {
        let store = MemoryStore()
        TutorialFunnel.mark(step: "send", in: store)
        TutorialFunnel.clear(in: store)

        #expect(TutorialFunnel.pendingAbandonment(in: store, isRunningNow: false) == nil)
    }

    @Test("안내가_지금_돌고_있으면_판정하지_않는다")
    func 진행_중() {
        let store = MemoryStore()
        TutorialFunnel.mark(step: "typeTitle", in: store)

        // 같은 실행 안에서 방금 자기가 적어둔 자국을 이탈로 오해하면 안 된다.
        #expect(TutorialFunnel.pendingAbandonment(in: store, isRunningNow: true) == nil)
    }

    @Test("안내를_한_번도_안_시작했으면_아무것도_없다")
    func 시작_안_함() {
        #expect(TutorialFunnel.pendingAbandonment(in: MemoryStore(), isRunningNow: false) == nil)
    }

    @Test("마지막_단계가_이탈_지점으로_남는다")
    func 마지막_단계() {
        let store = MemoryStore()
        for step in ["typeTitle", "pickTime", "send"] {
            TutorialFunnel.mark(step: step, in: store)
        }
        #expect(TutorialFunnel.pendingAbandonment(in: store, isRunningNow: false) == "send")
    }

    @Test("이탈을_한_번_보고하면_다시_보고하지_않는다")
    func 중복_보고_없음() {
        let store = MemoryStore()
        TutorialFunnel.mark(step: "openDay", in: store)

        #expect(TutorialFunnel.pendingAbandonment(in: store, isRunningNow: false) == "openDay")
        TutorialFunnel.clear(in: store)   // 보고한 뒤에는 지운다
        #expect(
            TutorialFunnel.pendingAbandonment(in: store, isRunningNow: false) == nil,
            "앱을 켤 때마다 같은 이탈이 계속 잡히면 수치가 부풀어 오른다"
        )
    }

    @Test("끝났다는_신호_셋이_서로_구분된다")
    func 세_결말() {
        #expect(TutorialOutcome.finished.rawValue == "finished")
        #expect(TutorialOutcome.skipped.rawValue == "skipped")
        #expect(TutorialOutcome.abandoned.rawValue == "abandoned")
        #expect(Set([TutorialOutcome.finished, .skipped, .abandoned]).count == 3)
    }
}
