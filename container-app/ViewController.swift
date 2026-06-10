//
//  ViewController.swift
//  Shared (App)
//
//  Hardened version: removes force unwraps / casts on the launch path and logs
//  the previously-silent error branches via os_log. iOS branch now allows
//  scrolling (fallback when content exceeds viewport) and handles the
//  "open-ios-settings" message posted by the iOS CTA button.
//

import WebKit
import os.log

#if os(iOS)
import UIKit
typealias PlatformViewController = UIViewController
#elseif os(macOS)
import Cocoa
import SafariServices
typealias PlatformViewController = NSViewController
#endif

let extensionBundleIdentifier = "com.doncastle.mappath.Extension"

private let log = OSLog(subsystem: "com.doncastle.mappath", category: "Container")

class ViewController: PlatformViewController, WKNavigationDelegate, WKScriptMessageHandler {

    @IBOutlet var webView: WKWebView!

    override func viewDidLoad() {
        super.viewDidLoad()

        self.webView.navigationDelegate = self

#if os(iOS)
        // Allow scroll as a graceful fallback when Dynamic Type or smaller
        // devices push content past the viewport. CSS layout aims to fit
        // without scrolling at typical sizes.
        self.webView.scrollView.isScrollEnabled = true
        self.webView.scrollView.alwaysBounceVertical = false
#elseif os(macOS)
        // Size the container window so the full onboarding fits without
        // scrolling at default open size. The storyboard ships a smaller
        // default; this overrides it. Width is the typical small-utility
        // width on macOS; height accommodates the hero + CTA + steps cards.
        self.preferredContentSize = NSSize(width: 480, height: 560)
#endif

        self.webView.configuration.userContentController.add(self, name: "controller")

        guard let mainURL = Bundle.main.url(forResource: "Main", withExtension: "html"),
              let resourceURL = Bundle.main.resourceURL else {
            os_log(.error, log: log,
                   "Bundle is missing Main.html or resource URL — onboarding cannot load.")
            return
        }
        self.webView.loadFileURL(mainURL, allowingReadAccessTo: resourceURL)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
#if os(iOS)
        // Pass the iOS-version variant so the onboarding shows the correct
        // Settings menu path. iOS 17 introduced the "Apps" intermediate level
        // (Settings → Apps → Safari → Extensions); older iOS goes directly
        // (Settings → Safari → Extensions).
        let major = ProcessInfo.processInfo.operatingSystemVersion.majorVersion
        let variant = major >= 17 ? "modern" : "legacy"
        webView.evaluateJavaScript("show('ios', null, '\(variant)')")
#elseif os(macOS)
        webView.evaluateJavaScript("show('mac')")

        SFSafariExtensionManager.getStateOfSafariExtension(withIdentifier: extensionBundleIdentifier) { (state, error) in
            if let error = error {
                os_log(.error, log: log,
                       "Failed to read extension state: %{public}@",
                       error.localizedDescription)
                return
            }
            guard let state = state else {
                os_log(.error, log: log,
                       "Extension state callback returned neither state nor error.")
                return
            }

            DispatchQueue.main.async {
                webView.evaluateJavaScript("show('mac', \(state.isEnabled))")
            }
        }
#endif
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let body = message.body as? String else { return }

#if os(macOS)
        guard body == "open-preferences" else { return }

        SFSafariApplication.showPreferencesForExtension(withIdentifier: extensionBundleIdentifier) { error in
            if let error = error {
                os_log(.error, log: log,
                       "Failed to open Safari Extensions settings: %{public}@",
                       error.localizedDescription)
                return
            }

            DispatchQueue.main.async {
                NSApp.terminate(self)
            }
        }
#elseif os(iOS)
        switch body {
        case "open-ios-settings":
            // Opens iOS Settings to Map Path's own app page. From there, the
            // user taps Safari Extensions → Map Path → toggle on → All
            // Websites → Allow. There is no public API to deep-link directly
            // to the extension's permission row.
            if let url = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(url, options: [:], completionHandler: nil)
            }
        default:
            // "dismiss-onboarding" and "show-steps-again" are JS-only — no
            // native action needed.
            break
        }
#endif
    }
}
