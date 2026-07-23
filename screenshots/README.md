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
| `macos-1.png` | First-run welcome with the orange "Important — 3 switches" callout (2026-07-04 set) |
| `macos-2.png` | Green "Map Path is enabled — you're all set" state |
| `macos-3.png` | Safari hovering a Google Maps link on the test page; zoom-inset callout magnifies the status-bar `maps.apple.com/?q=...&sll=...` URL (rewrite proof) |
| `macos-4.png` | v1.2 address finder: toolbar popup over the test bench — "2 potential addresses" (2026-07-23, 5K capture cropped to the window) |
| `macos-5.png` | Apple Maps on Liberty Island after the click (the payoff; account avatar retouched out) |
| `iphone-1.png` | First-run welcome with the orange "Important — 3 switches" callout (2026-07-04 set, NYC sim location) |
| `iphone-2.png` | Settings → Map Path page: Allow Extension on, Private Browsing on, All Websites: Allow (permission proof; clean, unannotated) |
| `iphone-3.png` | Safari long-press preview on the Statue of Liberty link; preview card shows the real NYC statue via `sll` (rewrite proof) |
| `iphone-4.png` | Apple Maps on Liberty Island after the tap (the payoff) |
| `iphone-5.png` | v1.2 address finder: popup sheet over the test bench — "2 potential addresses," bait line visibly excluded |
| `ipad-1.png` | First-run welcome with the orange "Important — 3 switches" callout (2026-07-04 set, NYC sim location) |
| `ipad-2.png` | Settings split view → Map Path page: Allow Extension on, Private Browsing on, All Websites: Allow (clean, unannotated) |
| `ipad-3.png` | Safari long-press preview on the Statue of Liberty link with the maps.apple.com preview card |
| `ipad-4.png` | Apple Maps on Liberty Island with the Statue of Liberty place card (the payoff) |
| `ipad-5.png` | v1.2 address finder: toolbar popover over the test bench (landscape) |

## Capture notes

- macOS shots (2026-07-04 set) captured full-screen via `⌘⇧3` at
  3024×1964 with the Dock hidden and desktop icons off, then cropped to
  2880×1800 (center crop removes the menu bar; the Maps shot instead
  crops vertically and downscales so the full window width survives).
  The hover shot's zoom-inset callout and the Maps avatar retouch were
  scripted (CoreGraphics; see session log 2026-07-04).
- iOS / iPadOS shots captured in Simulator (iPhone 16 Pro Max,
  iPad Pro 13") via `File → Save Screen` (`⌘S`) so the image is exact
  device resolution with no simulator chrome.
- Clean 9:41 AM status bar on iOS/iPadOS via
  `xcrun simctl status_bar booted override --time "9:41" ...`.
- All shots were privacy-audited before publishing: no Apple ID,
  no personal Maps history, no usernames, no filesystem paths visible.
