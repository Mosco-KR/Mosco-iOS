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
        if let firebase = FirebaseAnalyticsSink.configure() {
            Analytics.register(firebase)
        }
        return true
    }

    // MARK: UISceneSession Lifecycle

    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        // Called when a new scene session is being created.
        // Use this method to select a configuration to create the new scene with.
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
        // Called when the user discards a scene session.
        // If any sessions were discarded while the application was not running, this will be called shortly after application:didFinishLaunchingWithOptions.
        // Use this method to release any resources that were specific to the discarded scenes, as they will not return.
    }


}

