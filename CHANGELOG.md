# Changelog

All notable changes to Map Path are documented here.
Format loosely follows [Keep a Changelog](https://keepachangelog.com/).

## [1.1.0] - Unreleased

The address finder release. Open the Map Path popup on any page and it
lists the **potential addresses** it finds in the page's text — tap one
and it opens in Apple Maps. Detection runs entirely on your device with
the same data detectors Mail uses (nothing is stored or transmitted, and
the page is only read when you open the popup), which is also why the
extension now declares the `nativeMessaging` capability.

Also incorporates the quality batch originally staged as 1.0.1 (folded
in unreleased). No behavior changes to links that worked —
only new coverage, richer fidelity, and a lighter bundle.

- **HERE route shares rewrite to real directions.** A
  `share.here.com/r/<from>/<to>` link becomes Apple Maps directions;
  routes with more than two stops stay untouched (Apple Maps can't
  express them — never-worse-link rule).
- **Zoom levels carry over.** When a source link specifies one (Google
  `@…z`/`?z=`, Waze `zoom=`, Bing `lvl=`, HERE `map=` / `?z=`), the
  rewritten link opens Apple Maps at the same zoom.
- **`geo:` labels are kept** — `geo:lat,lng?q=Name` now pins with its
  name instead of an anonymous coordinate.
- **Crisper toolbar icon** — exact 16px/32px sizes added.
- Removed dead onboarding files (HTML-era resources unreferenced since
  the SwiftUI rewrite) from both app bundles.
- Declared exempt-only encryption (`ITSAppUsesNonExemptEncryption=NO`).
- Parser harness: 47/47.

## [1.0.0] - 2026-07-05

Initial public release on the App Store for Safari on macOS, iOS,
iPadOS, and visionOS. (Submitted to App Review 2026-07-05.)

### Web extension

- MV3 manifest with the minimum surface: a single content script, no
  `host_permissions`, no `webRequest`, no `declarativeNetRequest`,
  no `optional_permissions`. Just `<all_urls>` match for the rewriter
  and an `action` popup.
- Per-source link parsers for Google Maps, Waze, Bing Maps, HERE WeGo,
  `geo:` URIs, and raw coordinates. Hostname-based classification
  avoids the substring trap (`atmosphere.com` vs `here.com`), the
  Google/Apple host checks are TLD-anchored against lookalike domains,
  and Waze/HERE only rewrite on their actual map surfaces — a
  help-center search is never turned into a map link.
- Named-place searches are **anchored to the link's own coordinates**
  (`q=` + `sll=`) for Google, Bing, and HERE, so an ambiguous name
  resolves to the place the link pointed at — not whichever match is
  nearest to the user. (A "Statue of Liberty" link opens the New York
  statue, not the Las Vegas replica.)
- Google redirect wrappers from Gmail/Docs (`google.com/url?q=`) are
  unwrapped locally — no network — and rewritten when the target is a
  map link.
- Plus Codes pin their accompanying coordinates instead of dead-ending
  in a search Apple Maps can't answer; bare codes are left alone.
- Every coordinate source is range-validated; a crafted `@999,999`
  link is left untouched instead of becoming a broken URL. Multi-stop
  routes, opaque `place_id:` queries, and shorteners are deliberately
  left alone per the never-worse-link rule. Any parse failure leaves
  just that one link untouched — one malformed link can't break
  rewriting for the rest of the page.
- Parser test harness (`test/parser.test.mjs`) — fake-DOM + `vm` runner
  asserting real-world link variations rewrite (or are intentionally
  left alone). **50/50 passing**, plus a 29-link wild-harvest field
  test (Wikipedia GeoHack, venue pages, vendor docs) verified against
  real geography.
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
- **Native SwiftUI onboarding** (NavigationStack hosted via
  NS/UIHostingController; OS 26 deployment floor): one adaptive tree
  serves iPhone, iPad, Mac, and Vision Pro with Dynamic Type, dark
  mode, and platform-conditional content at compile time.
- First-run welcome leads with an orange "Important — Map Path is off
  until you flip 3 switches" callout into an illustrated Set-up steps
  screen: a "Find Map Path" tap path (from wherever Apple's public
  `openSettingsURLString` actually lands), the three switches each
  shown as a native Settings look-alike card, and a tap-to-reveal
  annotated sample screenshot (per-device asset: iPhone / iPad / Mac).
- macOS shows **live extension state** (`SFSafariExtensionManager`,
  polled while the window is open, refreshed on focus): a warning state
  with setup CTAs flips to a green "you're all set" view with Test it
  now once the extension is enabled in Safari.
- Return visits get a compact verification view instead of the full
  first-run walkthrough; "Test it now" opens the public test page for
  a behavioral self-check on every platform.
- `ViewController.swift` hardened: no force unwraps on launch path,
  error branches log via `os_log` instead of swallowing silently.
- `AppDelegate` implements `applicationSupportsSecureRestorableState`
  to silence the macOS secure-coding warning.
- macOS Info.plist sets `LSApplicationCategoryType =
  public.app-category.utilities`.

### Privacy

- `PrivacyInfo.xcprivacy` declares `NSPrivacyTracking = false`, empty
  tracking domains, empty collected data, and a single required-reason
  API entry: `UserDefaults` (reason CA92.1) for the container app's
  one on-device "first launch" flag — the only value the app stores.
- No analytics, no network calls of any kind, no data collection.
  Verifiable in source.

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
- App Store screenshots (4–5 per platform × Mac / iPhone / iPad)
  tracked in `screenshots/` so they survive fresh-Mac rebuilds and
  don't live only on the Desktop. Consistent story arc across
  platforms: onboarding welcome → Settings permission proof →
  rewrite proof (Mac hover with magnified status bar / iOS long-press
  preview) → Apple Maps payoff on Liberty Island.
- Public marketing/legal/test/support pages live in the
  `codeCraftedApps` repo at `codecraftedapps.com/extensions/map-path/`.

[1.0.0]: https://github.com/DJCastle/mapPath-Safari/releases/tag/v1.0.0
