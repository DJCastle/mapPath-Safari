# App Store screenshots

Captured for the v1.0 App Store submission. Resolutions match Apple's
requirements at the time of capture; Apple may revise required sizes
over time, so verify before uploading future versions.

## Files

| File | What it shows |
|---|---|
| `macos-1.png` | Apple Maps showing Statue of Liberty after a click from the test page (post-click result) |
| `macos-2.png` | Safari hovering a Google Maps link on the test page; status bar shows `maps.apple.com/...` (rewrite proof) |
| `macos-3.png` | Map Path toolbar popup open over the test page (trust signal) |
| `macos-4.png` | Container app onboarding window (welcome) |
| `iphone-1.png` | Container app onboarding (iOS) |
| `iphone-2.png` | Settings → Apps → Safari → Extensions → Map Path showing the extension enabled with All Websites allowed (permission proof) |
| `iphone-3.png` | Apple Maps showing Statue of Liberty after a tap from the test page (post-tap result) |
| `iphone-4.png` | Safari long-press preview on a Google Maps link; preview card shows `maps.apple.com/...` (rewrite proof) |
| `ipad-1.png` | Container app onboarding (iPadOS) |
| `ipad-2.png` | Apple Maps showing Statue of Liberty after a tap |
| `ipad-3.png` | Safari long-press preview; preview card shows `maps.apple.com/...` |
| `ipad-4.png` | iPad Settings → Apps → Map Path showing the extension enabled with All Websites allowed |

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
