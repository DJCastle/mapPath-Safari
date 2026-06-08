//
//  ViewController.swift
//  Shared (App)
//
//  Hardened version: removes force unwraps / casts on the launch path and logs
//  the previously-silent error branches via os_log. Container-app behavior is
//  unchanged.
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
        self.webView.scrollView.isScrollEnabled = false
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
        webView.evaluateJavaScript("show('ios')")
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
#if os(macOS)
        guard let body = message.body as? String, body == "open-preferences" else {
            return
        }

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
#endif
    }
}
