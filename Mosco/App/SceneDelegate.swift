//
//  SceneDelegate.swift
//  App
//
//  Created by SeoJunYoung on 7/30/26.
//

import UIKit
import SwiftUI
import SwiftData

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?


    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }

        applyMacWindowSizeLimits(windowScene)

        // 위젯도 같은 저장소를 읽어야 해서 App Group 컨테이너를 쓴다.
        let rootView = RootTabView()
            .modelContainer(SharedModelContainer.make())

        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = UIHostingController(rootView: rootView)
        self.window = window
        window.makeKeyAndVisible()

        // 앱이 꺼져 있을 때 위젯을 누르면 URL이 여기로 들어온다 —
        // `scene(_:openURLContexts:)`는 이미 떠 있을 때만 불린다. 둘 다
        // 받아야 콜드/웜 실행이 같은 수로 잡힌다.
        handle(connectionOptions.urlContexts)
    }

    /// **맥에서는 창을 너무 작게 줄이지 못하게 막는다.**
    ///
    /// 달 격자는 한 주 행에 막대를 **몇 개까지 넣을지 행 높이로 계산한다**
    /// (`MonthPageMetrics.barCapacity`). 아이폰은 화면 높이가 고정이라 이 값이 늘
    /// 4로 굳어 있는데, 맥은 창을 줄이면 3 → 2 → 1로 떨어지고 **격자가 324pt
    /// 아래로 내려가면 0이 된다** — 그러면 막대도 `+N`도 없어서 일정이 있는 날이
    /// 빈 날과 똑같아 보인다. 접은 것이 아니라 거짓말이 되는 지점이다.
    ///
    /// 640pt면 상단 크롬을 빼도 격자에 막대 3개가 남는다. 폭 480은 일곱 칸이
    /// 각각 68pt 남짓이라 날짜 숫자와 공휴일 이름이 안 잘리는 선이다.
    private func applyMacWindowSizeLimits(_ windowScene: UIWindowScene) {
        #if targetEnvironment(macCatalyst)
        windowScene.sizeRestrictions?.minimumSize = CGSize(width: 480, height: 640)
        #endif
    }

    /// 앱이 떠 있는 상태에서 위젯을 눌렀을 때.
    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        handle(URLContexts)
    }

    /// 위젯이 실어 보낸 표시를 읽어 어느 위젯으로 들어왔는지 남긴다.
    ///
    /// **SwiftUI의 `.onOpenURL`은 이 앱에서 동작하지 않는다.** 이 앱은 UIKit
    /// 생명주기(AppDelegate + SceneDelegate) 위에 올라가 있어서, SwiftUI가
    /// 씬 이벤트를 받지 못한다("Cannot use Scene methods for URL ... without
    /// using SwiftUI Lifecycle" 경고가 그 뜻이다). 그래서 여기서 받는다.
    private func handle(_ contexts: Set<UIOpenURLContext>) {
        for context in contexts {
            if let on = InternalUser.command(from: context.url) {
                markInternalUser(on)
                continue
            }
            guard let kind = WidgetDeepLink.kind(from: context.url) else { continue }
            Analytics.log(.widgetTapped(kind: kind))
            // '오늘 할 일' 위젯과 라이브 액티비티는 오늘 페이지로 바로 연다.
            if WidgetDeepLink.opensTodayPage(kind: kind) {
                AppNavigation.shared.todayPageRequest =
                    kind == WidgetDeepLink.liveActivityKind ? "live_activity" : "widget"
            }
        }
    }

    /// 개발자·테스트 기기 표시를 켜거나 끈다(`mosco://internal`). 사용자에게는
    /// 보이지 않는 길이라 화면 대신 알림창 하나로 됐다는 것만 알린다 — 아무 반응이
    /// 없으면 링크가 먹었는지 알 수 없다.
    private func markInternalUser(_ on: Bool) {
        let cloud = CloudIdentityStore()
        let local = UserDefaults.standard
        let device = DeviceIdentity.resolve(cloud: cloud, local: local, model: DeviceModel.current).device
        _ = DeviceIdentity.mark(on, deviceID: device.id, model: device.model, cloud: cloud, local: local)
        Analytics.set(.internalUser(on))
        let alert = UIAlertController(
            title: on ? "이 기기를 내부 사용자로 표시했어요" : "내부 사용자 표시를 껐어요",
            // **기기 id를 여기서 보여준다.** 보고서에서 어느 줄이 이 기기인지
            // 맞추려면 이 값이 필요하고, 표시를 켜는 순간이 그걸 알려줄 자리다.
            message: "기기 \(device.id) · \(device.model)",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "확인", style: .default))
        // 앱이 꺼져 있다가 링크로 켜진 경우 화면이 아직 안 올라왔을 수 있다.
        // 시트가 떠 있으면 그 위에 띄워야 한다 — 맨 아래 화면에 띄우면 조용히 무시된다.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
            var top = self?.window?.rootViewController
            while let presented = top?.presentedViewController { top = presented }
            top?.present(alert, animated: true)
        }
    }
}

