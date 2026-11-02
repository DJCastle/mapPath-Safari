# App Store screenshots

Resolutions match Apple's requirements at the time of capture; Apple may
revise required sizes over time, so verify before uploading future versions.

## iPhone, iPad, iPhone Duo and Mac (1.2.2 set, framed)

Redone for 1.2.2 on the same template as ContactTap's App Store set
(`contactTap-Safari/work/screenshots/compose.swift`): SF Rounded two-line
headline, raw capture inside a black-bezel device running off the bottom.
The palette is the app's own, not ContactTap's — the popup's Apple Maps
"paper" cream, near-black ink, warm grey, and the blue→green accent as a
short rule under the headline. The framed PNGs are generated, never
hand-edited:

- `raw/iphone/*.png` — iPhone 18 Pro Max, 1320×2868, iOS 27.2.
- `raw/ipad/*.png` — iPad Pro 13-inch (M5), 2064×2752, portrait.
  `maps.png` had a simulator Liquid Glass smear removed with
  `work/retouch-ipad-maps.swift`.
- `raw/duo/*.png` — iPhone Duo **closed** (outer display), 1398×2034, via
  `xcrun simctl io <udid> screenshot --display=1`.
- `raw/duo-inner/*.png` — iPhone Duo **open** (inner display, landscape),
  2853×2007, via `--display=3`; four shots (welcome, Safari preview, Maps,
  popup) become `duo-7`…`duo-10`. The simulator must be unfolded in
  Xcode's Device Hub first — `simctl` has no fold command. App Store
  Connect has one Duo slot that takes either size, so both sets upload
  into it, closed first.
- `raw/macos/*.png` — window captures on this Mac (`⌘⇧4`, Space,
  Option-click to drop the shadow), composed landscape at 2880×1800.
- `frames.json` — which raw capture becomes which output, with its headline.
- `scripts/frame-screenshots.swift` — the renderer. Dry-run by default;
  `swift scripts/frame-screenshots.swift screenshots/frames.json --apply`
  rewrites every output. Output is opaque RGB at the exact slot size.

Same order and copy on every device (`iphone-N`, `ipad-N`, `duo-N`; the inner-display `duo-7…10` reuse headlines 1–4):

| N | Headline | Raw capture |
|---|---|---|
| 1 | Any map link. / Apple Maps. | Welcome screen |
| 2 | Already Apple Maps, / before you tap. | Safari touch-and-hold preview of the Statue of Liberty link, `maps.apple.com` header |
| 3 | Lands exactly / where you expected. | Apple Maps on Liberty Island, place card open |
| 4 | Finds addresses / on any page. | Popup over the test bench, "2 potential addresses" |
| 5 | Three switches. / Done. | Settings → Map Path: Allow Extension on, Private Browsing on, All Websites: Allow |
| 6 | Private by design. / Nothing leaves your device. | Privacy page |

macOS (`macos-1`…`5`): welcome, hover (status bar reads `maps.apple.com`),
Apple Maps, popup, and the green "enabled" state — "One switch in Safari.
Done." replaces the iOS three-switch line.

Capture notes: every app was launched from the Home screen (`simctl launch`
/ `openurl`) so no "◀ App" back-breadcrumb sits under the clock; Maps was
opened by URL with location pre-granted via `simctl privacy grant`;
status bar via `simctl status_bar … --batteryState discharging` (the
`charged` state draws a charging bolt). The Duo outer display shows no
battery glyph at all in the closed pose. Re-apply the status bar override
if it drops mid-session — it did once on the iPad.

## macOS (v1.0–1.2 set, unframed — superseded once raw/macos/ is captured)

Story arc:

1. **Onboarding** — what is this app?
2. **Conversion proof** — the extension doing what it claims.
3. **Popup** — the Map Path UI surface that confirms it's at work.
4. **Apple Maps result** — the payoff.

## Files

| File | What it shows |
|---|---|
| `macos-1.png` | First-run welcome with the orange "Important — 3 switches" callout (2026-07-04 set) |
| `macos-2.png` | Green "Map Path is enabled — you're all set" state |
| `macos-3.png` | Safari hovering a Google Maps link on the test page; zoom-inset callout magnifies the status-bar `maps.apple.com/?q=...&sll=...` URL (rewrite proof) |
| `macos-4.png` | v1.2 address finder: toolbar popup over the test bench — "2 potential addresses" (2026-07-23, 5K capture cropped to the window) |
| `macos-5.png` | Apple Maps on Liberty Island after the click (the payoff; account avatar retouched out) |

## Capture notes

- macOS shots (2026-07-04 set) captured full-screen via `⌘⇧3` at
  3024×1964 with the Dock hidden and desktop icons off, then cropped to
  2880×1800 (center crop removes the menu bar; the Maps shot instead
  crops vertically and downscales so the full window width survives).
  The hover shot's zoom-inset callout and the Maps avatar retouch were
  scripted (CoreGraphics; see session log 2026-07-04).
- All shots were privacy-audited before publishing: no Apple ID,
  no personal Maps history, no usernames, no filesystem paths visible.
