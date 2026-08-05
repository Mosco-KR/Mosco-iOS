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

    func sceneDidDisconnect(_ scene: UIScene) {
        // Called as the scene is being released by the system.
        // This occurs shortly after the scene enters the background, or when its session is discarded.
        // Release any resources associated with this scene that can be re-created the next time the scene connects.
        // The scene may re-connect later, as its session was not necessarily discarded (see `application:didDiscardSceneSessions` instead).
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        // Called when the scene has moved from an inactive state to an active state.
        // Use this method to restart any tasks that were paused (or not yet started) when the scene was inactive.
    }

    func sceneWillResignActive(_ scene: UIScene) {
        // Called when the scene will move from an active state to an inactive state.
        // This may occur due to temporary interruptions (ex. an incoming phone call).
    }

    func sceneWillEnterForeground(_ scene: UIScene) {
        // Called as the scene transitions from the background to the foreground.
        // Use this method to undo the changes made on entering the background.
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
        // Called as the scene transitions from the foreground to the background.
        // Use this method to save data, release shared resources, and store enough scene-specific state information
        // to restore the scene back to its current state.
    }


}

