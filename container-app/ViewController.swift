//
//  ViewController.swift
//  Shared (App)
//
//  SwiftUI onboarding hosted in the converter-generated storyboard app via a
//  platform hosting controller (NS/UIHostingController). One adaptive SwiftUI
//  tree serves iPhone, iPad, Mac, and (via iPad compatibility) Vision Pro, and
//  picks up Liquid Glass, Dynamic Type, and dark mode from the system. Native
//  SafariServices calls stay here and are injected into SwiftUI as closures so
//  the view layer carries no AppKit/UIKit imports.
//

import SwiftUI
import Observation
import os.log

#if os(iOS)
import UIKit
typealias PlatformViewController = UIViewController
typealias PlatformHostingController = UIHostingController
#elseif os(macOS)
import Cocoa
import SafariServices
typealias PlatformViewController = NSViewController
typealias PlatformHostingController = NSHostingController
#endif

#if os(macOS)
let extensionBundleIdentifier = "com.doncastle.mappath.Extension"
#endif

private let log = OSLog(subsystem: "com.doncastle.mappath", category: "Container")

private let testPageURL = URL(string: "https://codecraftedapps.com/extensions/map-path/test.html")

// MARK: - Model

/// Observable state + injected native actions for the onboarding UI.
@Observable
final class OnboardingModel {
    enum MacExtensionState: Equatable { case unknown, enabled, disabled }

    /// True on return visits — drives the compact verification view instead of
    /// the full first-run setup.
    let isReturnVisit: Bool
    /// iOS 17+ added the Settings → Apps → Safari level; older goes direct.
    let iosModernSettingsPath: Bool
    /// macOS extension enable state; always `.unknown` on iOS (no such API).
    var macState: MacExtensionState = .unknown

    let actions: OnboardingActions

    init(isReturnVisit: Bool, iosModernSettingsPath: Bool, actions: OnboardingActions) {
        self.isReturnVisit = isReturnVisit
        self.iosModernSettingsPath = iosModernSettingsPath
        self.actions = actions
    }
}

/// Native actions the SwiftUI layer can invoke without importing AppKit/UIKit.
struct OnboardingActions {
    var openSettings: () -> Void = {}
    var openTestPage: () -> Void = {}
}

// MARK: - Hosting view controller

class ViewController: PlatformViewController {

    private static let hasOpenedBeforeKey = "MapPathHasOpenedBefore"
    private var model: OnboardingModel?

    override func viewDidLoad() {
        super.viewDidLoad()

        // First-open detection persisted in UserDefaults: the very first launch
        // sees false, every later launch sees true.
        let defaults = UserDefaults.standard
        let isReturnVisit = defaults.bool(forKey: Self.hasOpenedBeforeKey)
        if !isReturnVisit {
            defaults.set(true, forKey: Self.hasOpenedBeforeKey)
        }

#if os(iOS)
        let modernPath = ProcessInfo.processInfo.operatingSystemVersion.majorVersion >= 17
#else
        let modernPath = true
#endif

        var actions = OnboardingActions()
        actions.openSettings = { [weak self] in self?.openSettings() }
        actions.openTestPage = { [weak self] in self?.openTestPage() }

        let model = OnboardingModel(isReturnVisit: isReturnVisit,
                                    iosModernSettingsPath: modernPath,
                                    actions: actions)
        self.model = model

        let host = PlatformHostingController(rootView: OnboardingView(model: model))
        addChild(host)
        host.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(host.view)
        NSLayoutConstraint.activate([
            host.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            host.view.topAnchor.constraint(equalTo: view.topAnchor),
            host.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
#if os(iOS)
        host.didMove(toParent: self)
#elseif os(macOS)
        // A comfortable default; the window is resizable and the content scrolls.
        preferredContentSize = NSSize(width: 480, height: 640)
#endif
    }

#if os(macOS)
    override func viewDidAppear() {
        super.viewDidAppear()
        refreshMacState()
    }

    private func refreshMacState() {
        SFSafariExtensionManager.getStateOfSafariExtension(withIdentifier: extensionBundleIdentifier) { [weak self] state, error in
            DispatchQueue.main.async {
                if let error = error {
                    os_log(.error, log: log,
                           "Failed to read extension state: %{public}@", error.localizedDescription)
                    self?.model?.macState = .unknown
                    return
                }
                self?.model?.macState = (state?.isEnabled == true) ? .enabled : .disabled
            }
        }
    }

    private func openSettings() {
        SFSafariApplication.showPreferencesForExtension(withIdentifier: extensionBundleIdentifier) { error in
            if let error = error {
                os_log(.error, log: log,
                       "Failed to open Safari Extensions settings: %{public}@", error.localizedDescription)
            }
        }
    }

    private func openTestPage() {
        guard let testPageURL else { return }
        NSWorkspace.shared.open(testPageURL)
    }
#elseif os(iOS)
    private func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    private func openTestPage() {
        guard let testPageURL else { return }
        UIApplication.shared.open(testPageURL)
    }
#endif
}

// MARK: - SwiftUI onboarding

struct OnboardingView: View {
    let model: OnboardingModel

    var body: some View {
        NavigationStack {
            HomeScreen(model: model)
        }
    }
}

private struct HomeScreen: View {
    let model: OnboardingModel

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                HeaderView(isReturnVisit: model.isReturnVisit)

                if model.isReturnVisit {
                    VerificationView(model: model)
                } else {
                    PrimaryActionsView(model: model)
                }

                MoreLinksView(model: model)
                FooterView()
            }
            .frame(maxWidth: 540)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 28)
            .padding(.vertical, 32)
        }
        .navigationTitle("")
    }
}

private struct HeaderView: View {
    let isReturnVisit: Bool

    var body: some View {
        VStack(spacing: 12) {
            Image("LargeIcon")
                .resizable()
                .scaledToFit()
                .frame(width: 76, height: 76)
                .accessibilityHidden(true)
            Text(isReturnVisit ? "Map Path" : "Welcome to Map Path")
                .font(.largeTitle.weight(.bold))
                .multilineTextAlignment(.center)
            Text("Map links route to Apple Maps.")
                .font(.title3)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }
}

private struct PrimaryActionsView: View {
    let model: OnboardingModel

    var body: some View {
        VStack(spacing: 14) {
#if os(macOS)
            MacStatusView(state: model.macState)
            if model.macState == .enabled {
                // Already on — lead with verifying it works.
                Button("Test it now") { model.actions.openTestPage() }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                Button("Open Safari Extensions Settings") { model.actions.openSettings() }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                Text("Map Path is on. Tap **Test it now** to confirm a map link opens in Apple Maps. If a site still opens Google or Waze, set that site's permission to **Always Allow**.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            } else {
                // Not enabled (or status unknown) — lead with opening Settings.
                Button("Open Safari Extensions Settings") { model.actions.openSettings() }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                Button("Test it now") { model.actions.openTestPage() }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                Text("In the Extensions tab, turn on **Map Path**, then choose **Always Allow on Every Website** when prompted.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
#elseif os(iOS)
            Button("Open Settings") { model.actions.openSettings() }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            Button("Test it now") { model.actions.openTestPage() }
                .buttonStyle(.bordered)
                .controlSize(.large)
            Text("**Open Settings** jumps to Map Path — turn on **Allow Extension** and set **All Websites** to **Allow**. **Test it now** opens a page where a Google Maps link should open Apple Maps.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
#endif
        }
        .frame(maxWidth: .infinity)
    }
}

private struct VerificationView: View {
    let model: OnboardingModel

    var body: some View {
        VStack(spacing: 14) {
#if os(macOS)
            MacStatusView(state: model.macState)
#else
            Text("Setup complete? Tap below to test.")
                .font(.headline)
                .multilineTextAlignment(.center)
#endif
            Button("Test it now") { model.actions.openTestPage() }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            Button(settingsLabel) { model.actions.openSettings() }
                .buttonStyle(.bordered)
                .controlSize(.large)
            Text("If a map link still opens Google or Waze, the usual fix is **All Websites: Allow** (not Ask).")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    private var settingsLabel: LocalizedStringKey {
#if os(macOS)
        "Open Safari Extensions Settings"
#else
        "Open Settings"
#endif
    }
}

#if os(macOS)
private struct MacStatusView: View {
    let state: OnboardingModel.MacExtensionState

    var body: some View {
        switch state {
        case .unknown:
            Label("Checking status…", systemImage: "circle.dotted")
                .foregroundStyle(.secondary)
                .font(.headline)
        case .enabled:
            Label("Map Path is enabled in Safari", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .font(.headline)
        case .disabled:
            Label("Map Path needs to be set up in Safari", systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
                .font(.headline)
        }
    }
}
#endif

private struct MoreLinksView: View {
    let model: OnboardingModel

    var body: some View {
        VStack(spacing: 12) {
            NavigationLink {
                SetupStepsScreen(model: model)
            } label: {
                Label("Set-up steps", systemImage: "list.number")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)

            NavigationLink {
                PrivacyScreen()
            } label: {
                Label("Privacy", systemImage: "hand.raised")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
        }
    }
}

private struct SetupStepsScreen: View {
    let model: OnboardingModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
#if os(macOS)
                Text("New to Safari extensions?")
                    .font(.title2.bold())
                StepRow(1, "Open **Safari**.")
                StepRow(2, "Choose **Safari ▸ Settings** (⌘,), then click **Extensions**.")
                StepRow(3, "Check the box next to **Map Path**.")
                StepRow(4, "When prompted about website access, choose **Always Allow on Every Website**.")
#elseif os(iOS)
                Text("Apple lets you — not us — grant extension permissions. If you skip a step, Safari keeps Map Path off and your links still open in Google, Waze, or the other map sites.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Text("3 steps in Settings")
                    .font(.title2.bold())
                if model.iosModernSettingsPath {
                    StepRow(1, "In **Settings ▸ Apps ▸ Safari ▸ Extensions**, tap **Map Path** and turn on **Allow Extension**.")
                } else {
                    StepRow(1, "In **Settings ▸ Safari ▸ Extensions**, tap **Map Path** and turn on **Allow Extension**.")
                }
                StepRow(2, "On the same screen, set **All Websites** to **Allow** (not Ask).")
                StepRow(3, "Optional — turn on **Allow in Private Browsing** to cover Private tabs too.")
#endif
            }
            .frame(maxWidth: 560, alignment: .leading)
            .frame(maxWidth: .infinity)
            .padding(28)
        }
        .navigationTitle("Set-up steps")
#if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
#endif
    }
}

private struct StepRow: View {
    let number: Int
    let text: LocalizedStringKey

    init(_ number: Int, _ text: LocalizedStringKey) {
        self.number = number
        self.text = text
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text("\(number)")
                .font(.headline)
                .foregroundStyle(.tint)
                .frame(width: 24, alignment: .trailing)
            Text(text)
                .font(.body)
            Spacer(minLength: 0)
        }
    }
}

private struct PrivacyScreen: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Map Path rewrites map links from Google, Waze, Bing, and HERE — plus `geo:` links — so they open in Apple Maps. Everything runs on your device.")
                    .font(.body)

                VStack(alignment: .leading, spacing: 10) {
                    PrivacyPoint("No tracking")
                    PrivacyPoint("No analytics")
                    PrivacyPoint("No network calls")
                    PrivacyPoint("No data collection")
                }

#if os(iOS)
                Divider()
                Text("Private Browsing")
                    .font(.headline)
                Text("If you turn on **Allow in Private Browsing**, note that Apple Maps keeps its own Recents list, independent of Safari. A link you tap from a Private tab can still appear in Maps' Recents — only Apple controls that. Clear it from inside the Maps app if it matters to you.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
#endif
            }
            .frame(maxWidth: 560, alignment: .leading)
            .frame(maxWidth: .infinity)
            .padding(28)
        }
        .navigationTitle("Privacy")
#if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
#endif
    }
}

private struct PrivacyPoint: View {
    let text: LocalizedStringKey
    init(_ text: LocalizedStringKey) { self.text = text }

    var body: some View {
        Label {
            Text(text)
        } icon: {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
        }
    }
}

private struct FooterView: View {
    var body: some View {
        VStack(spacing: 4) {
            Text("No tracking · No analytics · No network calls · No data collection")
            Text("By CodeCrafted Apps · codecraftedapps.com")
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
    }
}
