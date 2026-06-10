# Changelog

All notable changes to Map Path are documented here.
Format loosely follows [Keep a Changelog](https://keepachangelog.com/).

## [1.0.0] - 2026-06-10

Initial public release on the App Store for Safari on macOS, iOS,
iPadOS, and visionOS.

### Web extension

- MV3 manifest with the minimum surface: a single content script, no
  `host_permissions`, no `webRequest`, no `declarativeNetRequest`,
  no `optional_permissions`. Just `<all_urls>` match for the rewriter
  and an `action` popup.
- Per-source link parsers for Google Maps, Waze, Bing Maps, HERE WeGo,
  `geo:` URIs, and raw coordinates. Hostname-based classification
  avoids the substring trap (`atmosphere.com` vs `here.com`).
- Parser test harness (`test/parser.test.mjs`) — fake-DOM + `vm` runner
  asserting real-world link variations rewrite (or are intentionally
  left alone). **28/28 passing.**
- Single-layer transparent Safari toolbar icons (48/96/128/256/512),
  rendered from the canonical `app-icon/MapPath.icon` source.
- Popup links to the marketing page and the support/FAQ page in addition
  to the privacy bullets.

### Container app

- Adaptive single-layer app icon (Icon Composer), Mac asset catalog
  covers all required sizes (16→1024 at @1x/@2x) plus the iOS
  universal 1024. AppIcon PNGs flattened to opaque white so the
  large-icon validator (App Store error 90717) accepts them; the
  canonical source stays transparent for the Safari toolbar icons.
- Container-app onboarding rewritten from the Apple converter template:
  horizontal welcome hero, one-click "Quit & Open Safari Extensions
  Settings" CTA on macOS, platform-specific step-by-step enablement
  for iOS / iPadOS 26.5 and macOS 26.5, terse on-device explainer
  near the footer.
- **Adaptive sizing across iPhone, iPad, and macOS** — typography and
  layout scale per Apple HIG (15px body / 24px h1 on iPhone, 16px /
  28px on iPad, 13px / 20px on the constrained macOS window), with
  50-54pt minimum touch targets on iOS / iPadOS and `viewport-fit=cover`
  + safe-area insets to respect the notch and home indicator.
- **iOS / iPadOS action buttons**: primary "Open Settings" (jumps to
  Map Path's iOS settings page via `UIApplication.openSettingsURLString`,
  the closest public API permits) and secondary "I'll do this later"
  (dismisses the onboarding cards, leaves a quiet "Map Path is
  installed" view with a way back to the steps).
- `ViewController.swift` hardened: no force unwraps on launch path,
  no force cast on the script-message body, error branches now log via
  `os_log` instead of swallowing silently. iOS branch enables scrolling
  as a graceful fallback for Dynamic Type or smaller devices.
- `AppDelegate` implements `applicationSupportsSecureRestorableState`
  to silence the macOS secure-coding warning.
- macOS Info.plist sets `LSApplicationCategoryType =
  public.app-category.utilities`.

### Privacy

- `PrivacyInfo.xcprivacy` at the repo root declares `NSPrivacyTracking
  = false`, empty tracking domains, empty collected data, and empty
  accessed required-reason APIs.
- No analytics, no network calls of any kind from the extension, no
  storage. Verifiable in source.

### Project layout

- Canonical sources are `extension/`, `container-app/`, and
  `app-icon/MapPath.icon/`. The Xcode tree (`Map Path/`) is
  gitignored because the `.xcodeproj` embeds the Apple Team ID.
- `scripts/sync-container-app.sh` (dry-run by default, `--apply` to
  write) regenerates the Xcode tree's customized files from the
  canonical sources, builds the asset catalog from the icon source,
  copies the privacy manifest into both target dirs, and patches
  `LSApplicationCategoryType` into the macOS Info.plist via
  `PlistBuddy`. Fresh-Mac flow: `safari-web-extension-converter
  extension/` → set dev team in Xcode → `scripts/sync-container-app.sh
  --apply` → drag-add `PrivacyInfo.xcprivacy` to all 4 targets in
  Xcode → build.
- `scripts/flatten-icon.swift` — Swift / Core Graphics utility the
  sync script invokes to composite the transparent icon design onto an
  opaque white background at each required size; output has no alpha
  channel (App Store requirement for the large macOS icon).
- App Store screenshots (4 per platform × Mac / iPhone / iPad) tracked
  in `screenshots/` so they survive fresh-Mac rebuilds and don't live
  only on the Desktop. Consistent story arc across platforms:
  Onboarding → Conversion (Mac) or Settings (iOS, iPadOS) → Popup
  (Mac) or long-press preview (iOS, iPadOS) → Apple Maps.
- Public marketing/legal/test/support pages live in the
  `codeCraftedApps` repo at `codecraftedapps.com/extensions/map-path/`.

[1.0.0]: https://github.com/DJCastle/mapPath-Safari/releases/tag/v1.0.0
