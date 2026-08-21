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
            guard let kind = WidgetDeepLink.kind(from: context.url) else { continue }
            Analytics.log(.widgetTapped(kind: kind))
        }
    }
}

