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
//  macOS additionally polls the live extension state (every second while the
//  window is open, plus an instant refresh when the app regains focus) so the
//  status updates the moment the user enables Map Path in Safari and returns.
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
    var closeWindow: () -> Void = {}
    var recheck: () -> Void = {}
}

// MARK: - Hosting view controller

class ViewController: PlatformViewController {

    private static let hasOpenedBeforeKey = "MapPathHasOpenedBefore"
    private var model: OnboardingModel?

#if os(macOS)
    private var statePollTimer: Timer?
#endif

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
#if os(macOS)
        actions.closeWindow = { [weak self] in self?.closeWindow() }
        actions.recheck = { [weak self] in self?.refreshMacState() }
#endif

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
        // Refresh the instant the user tabs back from Safari after toggling it.
        NotificationCenter.default.addObserver(
            self, selector: #selector(appBecameActive),
            name: NSApplication.didBecomeActiveNotification, object: nil)
#endif
    }

#if os(macOS)
    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        refreshMacState()
        startStatePolling()
    }

    override func viewWillDisappear() {
        super.viewWillDisappear()
        stopStatePolling()
    }

    @objc private func appBecameActive() {
        refreshMacState()
    }

    // Poll while the window is open so enabling Map Path in Safari is reflected
    // live (the system has no change notification for extension state).
    private func startStatePolling() {
        stopStatePolling()
        statePollTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
            self?.refreshMacState()
        }
    }

    private func stopStatePolling() {
        statePollTimer?.invalidate()
        statePollTimer = nil
    }

    private func refreshMacState() {
        SFSafariExtensionManager.getStateOfSafariExtension(withIdentifier: extensionBundleIdentifier) { [weak self] state, error in
            DispatchQueue.main.async {
                guard let model = self?.model else { return }
                if let error = error {
                    os_log(.error, log: log,
                           "Failed to read extension state: %{public}@", error.localizedDescription)
                    return  // keep last known state — don't flip the UI on a transient error
                }
                let newState: OnboardingModel.MacExtensionState = (state?.isEnabled == true) ? .enabled : .disabled
                // Only mutate when the value actually changes; assigning an
                // @Observable property notifies observers even for an equal
                // value, which would re-render (flash) the window every poll.
                if model.macState != newState {
                    model.macState = newState
                }
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

    private func closeWindow() {
        view.window?.close()
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

                primaryContent

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

    @ViewBuilder
    private var primaryContent: some View {
#if os(macOS)
        // Live state drives the macOS view: once enabled, show the all-set view
        // regardless of first-run vs return.
        if model.macState == .enabled {
            AllSetView(model: model)
        } else if model.isReturnVisit {
            VerificationView(model: model)
        } else {
            PrimaryActionsView(model: model)
        }
#else
        if model.isReturnVisit {
            VerificationView(model: model)
        } else {
            PrimaryActionsView(model: model)
        }
#endif
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
            Button("Recheck") { model.actions.recheck() }
                .buttonStyle(.borderless)
                .controlSize(.small)
            ImportantSetupCallout(model: model)
            Button("Open Safari Extensions Settings") { model.actions.openSettings() }
                .buttonStyle(.bordered)
                .controlSize(.large)
            Button("Test it now") { model.actions.openTestPage() }
                .buttonStyle(.bordered)
                .controlSize(.large)
            Text("In the Extensions tab, turn on **Map Path**, then choose **Always Allow on Every Website** when prompted.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
#elseif os(iOS)
            ImportantSetupCallout(model: model)
            Button("Open Settings") { model.actions.openSettings() }
                .buttonStyle(.bordered)
                .controlSize(.large)
            Button("Test it now") { model.actions.openTestPage() }
                .buttonStyle(.bordered)
                .controlSize(.large)
            Text("**Test it now** opens a page where a Google Maps link should open Apple Maps.")
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
            Button("Recheck") { model.actions.recheck() }
                .buttonStyle(.borderless)
                .controlSize(.small)
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
private struct AllSetView: View {
    let model: OnboardingModel

    var body: some View {
        VStack(spacing: 14) {
            Label("Map Path is enabled in Safari", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .font(.headline)
            Text("You're all set — map links will open in Apple Maps.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Test it now") { model.actions.openTestPage() }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            Button("Close") { model.actions.closeWindow() }
                .buttonStyle(.bordered)
                .controlSize(.large)
            Text("**Test it now** opens a sample page in Safari. The first time, Safari may ask for website access — choose **Always Allow on Every Website** (or set **All Websites: Allow**), or links won't open in Apple Maps yet.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }
}

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
                Text("Map Path lives inside Safari, so Safari is where you switch it on. This button jumps straight to the right screen:")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Button {
                    model.actions.openSettings()
                } label: {
                    Label("Open Safari Extensions Settings", systemImage: "safari")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                VStack(alignment: .leading, spacing: 10) {
                    StepRow(1, "Click the button above — or, in Safari, choose **Safari ▸ Settings** (⌘,), then click **Extensions**.")
                    SettingsMockCard(indented: true) {
                        Text("Safari ▸ Settings… ▸ Extensions")
                            .font(.subheadline)
                    }
                }
                VStack(alignment: .leading, spacing: 10) {
                    StepRow(2, "Check the box next to **Map Path**.")
                    SettingsMockCard(indented: true) { MockCheckboxRow(label: "Map Path") }
                }
                VStack(alignment: .leading, spacing: 10) {
                    StepRow(3, "When Safari asks about website access, choose **Always Allow on Every Website**.")
                    SettingsMockCard(indented: true) { MockPromptButton(title: "Always Allow on Every Website") }
                }
#elseif os(iOS)
                Text("For your safety, Apple makes you flip these switches yourself — no app can turn itself on.")
                    .font(.callout)
                    .foregroundStyle(.secondary)

                Text("Find Map Path")
                    .font(.title2.bold())
                Button {
                    model.actions.openSettings()
                } label: {
                    Label("Open the Settings app", systemImage: "arrow.up.forward.app")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                if model.iosModernSettingsPath {
                    StepRow(1, "Tap **Apps** (near the bottom).")
                    StepRow(2, "Tap **Safari**.")
                    StepRow(3, "Tap **Extensions**, then **Map Path**.")
                } else {
                    StepRow(1, "Tap **Safari**.")
                    StepRow(2, "Tap **Extensions**, then **Map Path**.")
                }

                Text("Flip these 3 switches")
                    .font(.title2.bold())
                VStack(alignment: .leading, spacing: 10) {
                    StepRow(1, "Turn on **Allow Extension**.")
                    SettingsMockCard(indented: true) { MockToggleRow(label: "Allow Extension") }
                }
                VStack(alignment: .leading, spacing: 10) {
                    StepRow(2, "Set **All Websites** to **Allow** — not Ask. Most-missed step!")
                    SettingsMockCard(indented: true) { MockDisclosureRow(label: "All Websites", value: "Allow") }
                }
                VStack(alignment: .leading, spacing: 10) {
                    StepRow(3, "Optional: **Allow in Private Browsing**.")
                    SettingsMockCard(indented: true) { MockToggleRow(label: "Allow in Private Browsing") }
                }
#endif
                DisclosureGroup {
                    Image("SetupScreenshot")
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: 400)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(.quaternary, lineWidth: 1))
                        .frame(maxWidth: .infinity)
                        .padding(.top, 10)
                        .accessibilityLabel("Annotated screenshot of the settings screen, with arrows marking the switches described in the steps above.")
                } label: {
                    Label("See a sample of the finished screen", systemImage: "photo")
                        .font(.body.weight(.medium))
                }
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

// MARK: - Settings look-alike visuals

/// Stylized, non-interactive recreation of the Settings UI a step refers to,
/// shown under the step's text to reinforce it visually. Drawn natively rather
/// than embedded as screenshots so it follows dark/light mode and Dynamic Type
/// and doesn't go stale when the OS redesigns Settings.
private struct SettingsMockCard<Content: View>: View {
    let indented: Bool
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .frame(maxWidth: 400, alignment: .leading)
            .background(.fill.tertiary, in: RoundedRectangle(cornerRadius: 10))
            .allowsHitTesting(false)
            // Decorative: the step text above carries the same meaning for VoiceOver.
            .accessibilityHidden(true)
            .padding(.leading, indented ? 36 : 0) // clear of the step-number column
    }
}

/// "Allow Extension"-style row with a green switch locked ON.
private struct MockToggleRow: View {
    let label: String

    var body: some View {
        HStack {
            Text(label)
            Spacer()
            Toggle("", isOn: .constant(true))
                .labelsHidden()
#if os(macOS)
                .toggleStyle(.switch)
#endif
                .tint(.green)
        }
        .font(.subheadline)
    }
}

/// "All Websites — Allow ›"-style disclosure row.
private struct MockDisclosureRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .font(.subheadline)
    }
}

/// macOS extensions-list row with its checkbox ticked.
private struct MockCheckboxRow: View {
    let label: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.square.fill")
                .foregroundStyle(.white, .blue)
            Text(label)
            Spacer()
        }
        .font(.subheadline)
    }
}

/// The button to pick in Safari's website-access prompt.
private struct MockPromptButton: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.subheadline.weight(.medium))
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(Capsule().fill(.blue))
    }
}

/// First-run attention banner. Apple's HIG reserves red for destructive and
/// error states, so the required-setup flag uses the warning color (orange)
/// with the screen's single prominent button leading to the steps.
private struct ImportantSetupCallout: View {
    let model: OnboardingModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label {
                Text("Important — Map Path is **off** until you flip 3 switches in \(settingsPlace).")
                    .font(.callout.weight(.medium))
                    .multilineTextAlignment(.leading)
            } icon: {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
            }
            NavigationLink {
                SetupStepsScreen(model: model)
            } label: {
                Label("Show me the 3 steps", systemImage: "list.number")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(.orange.opacity(0.35), lineWidth: 1))
    }

    private var settingsPlace: String {
#if os(macOS)
        "Safari's settings"
#else
        "the Settings app"
#endif
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
