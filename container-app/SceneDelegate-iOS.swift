//
//  SceneDelegate.swift
//  iOS (App)
//
//  Converter template plus Home Screen quick-action handling. Both actions
//  are URL jumps (no UI plumbing): "Test It Now" opens the public test page,
//  "Open Settings" deep-links to the app's page in Settings.
//

import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let _ = (scene as? UIWindowScene) else { return }
        if let shortcut = connectionOptions.shortcutItem {
            handle(shortcut)
        }
    }

    func windowScene(_ windowScene: UIWindowScene,
                     performActionFor shortcutItem: UIApplicationShortcutItem,
                     completionHandler: @escaping (Bool) -> Void) {
        completionHandler(handle(shortcutItem))
    }

    @discardableResult
    private func handle(_ item: UIApplicationShortcutItem) -> Bool {
        let url: URL?
        switch item.type {
        case "com.doncastle.mappath.testpage":
            url = URL(string: "https://codecraftedapps.com/extensions/map-path/test.html")
        case "com.doncastle.mappath.settings":
            url = URL(string: UIApplication.openSettingsURLString)
        default:
            url = nil
        }
        guard let url else { return false }
        UIApplication.shared.open(url)
        return true
    }

}
