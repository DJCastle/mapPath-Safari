//
//  AppDelegate.swift
//  macOS (App)
//
//  Adds the explicit secure-coding opt-in Apple recommends for restorable
//  state (silences the "WARNING: Secure coding is automatically enabled..."
//  log line). Otherwise identical to the converter template.
//

import Cocoa

@main
class AppDelegate: NSObject, NSApplicationDelegate {

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Override point for customization after application launch.
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }

    /// Help menu (⌘?) → the support page. The app has no help book; the
    /// responder chain delivers showHelp: here, and the web FAQ is the help.
    @objc func showHelp(_ sender: Any?) {
        if let url = URL(string: "https://codecraftedapps.com/extensions/map-path/support.html") {
            NSWorkspace.shared.open(url)
        }
    }

}
