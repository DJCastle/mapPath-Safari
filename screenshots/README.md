# App Store screenshots

Captured for the v1.0 App Store submission. Resolutions match Apple's
requirements at the time of capture; Apple may revise required sizes
over time, so verify before uploading future versions.

Consistent story arc across all three platforms:

1. **Onboarding** — what is this app?
2. **Settings (iOS / iPadOS) or Conversion proof (macOS)** — proof
   that the extension is doing what it claims.
3. **Popup (macOS) or long-press preview (iOS / iPadOS)** — the
   Map Path UI surface that confirms it's at work.
4. **Apple Maps result** — the payoff.

## Files

| File | What it shows |
|---|---|
| `macos-1.png` | Container app onboarding window (Welcome to Map Path) |
| `macos-2.png` | Safari hovering a Google Maps link on the test page; status bar at bottom shows `maps.apple.com/...` (rewrite proof) |
| `macos-3.png` | Map Path toolbar popup open over the test page (the extension's UI surface) |
| `macos-4.png` | Apple Maps showing Statue of Liberty after the click (the payoff) |
| `iphone-1.png` | Container app onboarding (iOS) |
| `iphone-2.png` | Settings → Apps → Safari → Extensions → Map Path showing the extension enabled with All Websites allowed (permission proof) |
| `iphone-3.png` | Safari long-press preview on a Google Maps link; preview card shows `maps.apple.com/...` (rewrite proof) |
| `iphone-4.png` | Apple Maps showing Statue of Liberty after the tap (the payoff) |
| `ipad-1.png` | Container app onboarding (iPadOS) |
| `ipad-2.png` | iPad Settings → Apps → Map Path showing the extension enabled with All Websites allowed |
| `ipad-3.png` | Safari long-press preview; preview card shows `maps.apple.com/...` |
| `ipad-4.png` | Apple Maps showing Statue of Liberty (the payoff) |

## Capture notes

- macOS shots captured on Don's MacBook at retina resolution via
  `⌘⇧4 SPACE click-window`.
- iOS / iPadOS shots captured in Simulator (iPhone 16 Pro Max,
  iPad Pro 13") via `File → Save Screen` (`⌘S`) so the image is exact
  device resolution with no simulator chrome.
- Clean 9:41 AM status bar on iOS/iPadOS via
  `xcrun simctl status_bar booted override --time "9:41" ...`.
- All shots were privacy-audited before publishing: no Apple ID,
  no personal Maps history, no usernames, no filesystem paths visible.
