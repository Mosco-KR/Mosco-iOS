//
//  AppDelegate.swift
//  App
//
//  Created by SeoJunYoung on 7/30/26.
//

import UIKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // 분석 도구는 실행 초반에 붙여야 첫 화면의 이벤트도 잡힌다.
        // Firebase 패키지나 GoogleService-Info.plist가 아직 없으면 nil이 오고,
        // 그때는 콘솔 sink만 남아서 앱은 그대로 돈다.
        if FirebaseAnalyticsSink.shouldSend, let firebase = FirebaseAnalyticsSink.configure() {
            Analytics.register(firebase)
        }
        // **sink를 붙인 뒤에 부른다.** 같은 사람을 같은 사람으로 세기 위한 익명
        // 식별자를 정한다 — 이게 없으면 앱을 지웠다 깔 때마다 새 사람이 되고,
        // 재방문·리텐션이 전부 실제보다 낮게 잡힌다.
        MainActor.assumeIsolated { Analytics.identify() }
        return true
    }

    // MARK: UISceneSession Lifecycle

    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        // Called when a new scene session is being created.
        // Use this method to select a configuration to create the new scene with.
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }
}

