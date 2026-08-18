import Foundation

/// 안내가 어떻게 끝났는가.
nonisolated enum TutorialOutcome: String, Equatable {
    /// 끝맺음 카드까지 갔다.
    case finished
    /// "혼자 둘러볼게요" 또는 진행 중 "건너뛰기" — **본인이 그만두겠다고 눌렀다.**
    case skipped
    /// 아무것도 안 누르고 사라졌다 — 앱을 끄거나, 백그라운드로 두고 안 돌아왔다.
    /// 건너뛰기와 완전히 다른 신호다. 건너뛰기는 "필요 없다"이고 이건 "막혔거나
    /// 지루했다"에 가깝다. 섞어서 세면 어느 단계를 고쳐야 할지 알 수 없다.
    case abandoned
}

/// 안내를 도중에 떠난 것을 **다음 실행에서** 알아낸다.
///
/// 왜 이런 모양인가 — 이탈은 그 순간에 못 잡는다. 앱이 죽는 시점에는 이벤트를
/// 보낼 시간이 없고, 백그라운드로 갔다고 해서 떠난 것도 아니다(대부분 돌아온다).
/// 그래서 **"어느 단계에 있었다"를 적어두고, 다음에 앱이 켜졌을 때 그 자국이
/// 남아 있으면 떠난 것으로 친다.**
///
/// - 안내를 시작하거나 단계를 옮길 때 `mark(step:)`
/// - 끝맺음·건너뛰기로 정상 종료할 때 `clear()`
/// - 앱을 켤 때 `pendingAbandonment(...)` — 값이 있으면 지난번에 떠난 것이다
nonisolated enum TutorialFunnel {
    static let key = "tutorialInProgressStep"

    /// 지금 이 단계에 있다고 적어둔다.
    static func mark(step: String, in store: any IdentityStore) {
        store.set(step, forKey: key)
    }

    /// 정상 종료 — 자국을 지운다. 이걸 안 지우면 다음 실행에서 이탈로 잡힌다.
    static func clear(in store: any IdentityStore) {
        store.set("", forKey: key)
    }

    /// 지난 실행에서 떠났다면 그때 머물던 단계. 아니면 nil.
    ///
    /// **안내가 지금 돌고 있으면 판정하지 않는다.** 같은 실행 안에서 자기가 방금
    /// 적어둔 자국을 이탈로 오해하면 안 된다.
    static func pendingAbandonment(
        in store: any IdentityStore,
        isRunningNow: Bool
    ) -> String? {
        guard !isRunningNow else { return nil }
        guard let step = store.string(forKey: key), !step.isEmpty else { return nil }
        return step
    }
}
