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

