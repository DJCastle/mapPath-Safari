# Map Path — Safari

A Safari Web Extension that detects map links, addresses, and coordinates on any
page and routes them to **Apple Maps** instead of Google Maps, Waze, Bing Maps,
or HERE WeGo.

Privacy-first: **no tracking, no analytics, no network calls — fully on-device.**
By [CodeCrafted Apps](https://codecraftedapps.com).

**Platforms:** macOS, iOS, iPadOS, visionOS. (Not tvOS — no Safari on Apple TV.)

---

## How it works

A content script scans each page for links pointing at supported map services
and rewrites their `href` to `https://maps.apple.com/...`. No traffic
interception, no `webRequest`, no `declarativeNetRequest` — just link rewriting,
which keeps permissions minimal and the privacy story airtight.

### Sources detected

| Service       | Examples |
|---------------|----------|
| Google Maps   | `google.com/maps`, `maps.google.com`, `/maps/search`, `/maps/dir`, `@lat,lng` |
| Waze          | `waze.com/ul?ll=`, `?q=` |
| Bing Maps     | `bing.com/maps?q=`, `cp=lat~lng` |
| HERE WeGo     | `wego.here.com/?map=`, `here.com` |
| `geo:` URIs   | `geo:lat,lng`, `geo:0,0?q=Place+Name` |
| Raw coords    | `q=lat,lng`, `ll=lat,lng` |

Already-`maps.apple.com` links are left untouched.

### Known limitations

- **Opaque shorteners** (`goo.gl/maps`, `maps.app.goo.gl`) can't be resolved
  without following them — a network call we refuse to make. They're left
  untouched (best effort).
- **Embedded map widgets (iframes) are not touched.** When a page embeds a
  Google Maps iframe (real estate listings, store locators, event pages), the
  embed stays as-is. Apple ships no web-embed equivalent to Google's Maps
  Embed API, and `maps.apple.com` blocks iframe loading via `X-Frame-Options`,
  so there's nothing reliable to swap to. The navigation action — the
  separate `<a>` link to "open in maps" — still gets rewritten.
- **JavaScript-driven links** (e.g., `<button onclick="location='...'">`) bypass
  rewriting. Map Path operates on `<a href>` attributes; pages that route
  clicks through JS handlers aren't intercepted.
- Coordinate edge cases and Google Plus Codes may not translate cleanly. A small
  miss rate (~5%) is normal for this category; the extension never produces a
  worse link than the original — when in doubt, it leaves the link alone.

---

## Repo layout

```
extension/        canonical web-extension source (manifest, content.js, popup, icons)
app-icon/         Icon Composer adaptive app icon
test/             parser test harness (node test/parser.test.mjs)
PRIVACY.md        privacy policy
```

The Xcode container app is a **build artifact** generated from `extension/` via
Apple's converter — it is `.gitignore`d, not committed. The product website lives
in the separate `codeCraftedApps` repo at `codecraftedapps.com/extensions/map-path/`.

---

## Building

Safari extensions must be wrapped in an Xcode container app and signed/archived
through Xcode. From the repo root, once `extension/` is ready:

```bash
xcrun safari-web-extension-converter ./extension \
  --app-name "Map Path" \
  --bundle-identifier com.doncastle.mappath \
  --swift \
  --copy-resources \
  --force
```

Then in Xcode: select a signing Team, **⌘B** build, **⌘R** run. In Safari:
Settings → Advanced → "Show Develop menu", then Develop → Allow Unsigned
Extensions (local testing only).

---

## License

[MIT](LICENSE) © CodeCrafted Apps
