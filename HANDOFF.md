# Map Path — Safari (`mapPath-Safari`) — HANDOFF

**What this is:** A Safari Web Extension that detects map links/addresses/coordinates on any page and routes them to **Apple Maps** instead of Google/Waze/Bing/HERE. Privacy-first: no tracking, no analytics, no network calls, fully on-device. By CodeCrafted Apps, part of the Digital Life Compass ecosystem.

**Audience for this doc:** Claude Code running in VS Code. Don is a vibe coder — generate and edit all code, explain decisions briefly, and remind him to test/verify/commit at each step.

---

## 0. Tooling reality (read first)

- **Author in VS Code.** All extension source is plain web files (manifest, JS, HTML, CSS, icons).
- **Ship via Xcode — mandatory.** Safari extensions must be wrapped in an Xcode container app and signed/archived through Xcode to reach the App Store. Use Apple's converter to generate that project from the web source; you do NOT hand-build the Xcode project.
- **Platforms:** macOS, iOS, iPadOS, visionOS. **NOT tvOS** (no Safari on Apple TV).

Build path:
1. Write web source in `extension/` (this repo).
2. Run the converter (Section 4) → generates Xcode project + container app, opens Xcode.
3. In Xcode: set signing team, build, enable Safari Develop menu, test.
4. Archive → submit to App Store Connect.

After conversion, edits to the web source in the Xcode project flow into the built extension on the next build. Keep the canonical web source here in the repo; treat the generated Xcode project as a build artifact (decide in Section 6 whether to commit it).

---

## 1. Core design decision: how the redirect works

**Recommended (Option 1): content-script link rewriting.** A content script scans the page for map links and rewrites their `href` to `https://maps.apple.com/...`. No traffic interception, no `webRequest`, no `declarativeNetRequest`, minimal permissions. Most privacy-clean, most auditable, easiest App Review story.

**Why not webRequest:** Safari MV3 does **not** support blocking `webRequest`. Don't design around it.

**Alternative (Option 2): `webNavigation.onCommitted` + `tabs.update`.** Catches navigations the content script misses (and could follow shorteners), but needs broader permissions and reads navigation events — weaker privacy story. Only reach for this if Option 1 proves insufficient. Start with Option 1.

---

## 2. Map sources to detect

- Google Maps: `google.com/maps`, `maps.google.com`, `goo.gl/maps`, `maps.app.goo.gl`
- Waze: `waze.com`, `*.waze.com`
- Bing Maps: `bing.com/maps`
- HERE WeGo: `wego.here.com`, `here.com`
- Raw coordinates in link/query (`@lat,lng`, `ll=lat,lng`, `q=lat,lng`)
- Plain addresses in known map link params (`q=`, `daddr=`, `destination=`)
- Embedded map iframes (rewrite `src` where feasible)

**Pass-through:** already-`maps.apple.com` links — leave untouched.

**Apple Maps URL targets:**
- Query/address: `https://maps.apple.com/?q=<encoded>`
- Coordinates: `https://maps.apple.com/?ll=<lat>,<lng>`
- Directions: `https://maps.apple.com/?daddr=<encoded>`

**Known limitations (document these on the site, don't hide them):**
- Opaque shorteners can't be resolved without following them (privacy cost) — best effort only.
- Coordinate edge cases and Google Plus Codes may not translate cleanly (~5% miss rate is normal for this category).

---

## 3. Repo structure

```
mapPath-Safari/
├── extension/                 # canonical web-extension source
│   ├── manifest.json
│   ├── content.js             # link detection + rewrite (Option 1)
│   ├── popup.html             # tiny about/on-off panel
│   ├── popup.js
│   ├── popup.css
│   └── icons/                 # 48/96/128/256/512 PNG, plain neutral pin/compass
├── docs/                      # GitHub Pages site (public, static, no data)
│   ├── index.html             # safari.extensions.codecraftedapps.com landing
│   ├── privacy.html
│   └── terms.html
├── HANDOFF.md
├── README.md
├── PRIVACY.md
├── LICENSE
└── CHANGELOG.md
```

---

## 4. Converter command (run from repo root after `extension/` is ready)

```bash
xcrun safari-web-extension-converter ./extension \
  --app-name "Map Path" \
  --bundle-identifier com.doncastle.mappath \
  --swift \
  --copy-resources \
  --force
```

- Omit `--macos-only` so it generates iOS + macOS (iPadOS/visionOS ride along).
- `--copy-resources` copies web files into the project (vs referencing) — pick one model and stay consistent.
- If you've installed/uninstalled a prior build and hit conflicts, add `--project-location "<new path>"`.
- Converter prints warnings for any manifest keys Safari doesn't support — read them; act on them.

Then in Xcode: select a signing Team, **⌘B** build, **⌘R** run. In Safari: Settings → Advanced → "Show Develop menu", then Develop → Allow Unsigned Extensions (for local testing only).

---

## 5. Starter files

### `extension/manifest.json` (MV3, minimal permissions)
```json
{
  "manifest_version": 3,
  "name": "Map Path",
  "version": "1.0",
  "description": "Routes map links to Apple Maps. No tracking. Built by CodeCrafted Apps.",
  "icons": {
    "48": "icons/icon-48.png",
    "96": "icons/icon-96.png",
    "128": "icons/icon-128.png",
    "256": "icons/icon-256.png",
    "512": "icons/icon-512.png"
  },
  "content_scripts": [
    {
      "matches": ["<all_urls>"],
      "js": ["content.js"],
      "run_at": "document_idle",
      "all_frames": true
    }
  ],
  "action": {
    "default_popup": "popup.html",
    "default_icon": {
      "48": "icons/icon-48.png",
      "128": "icons/icon-128.png"
    }
  }
}
```
> Note: pure content-script rewriting needs no host permissions beyond the content-script match. Keep it that way — every permission you avoid is a stronger privacy + App Review story.

### `extension/content.js` (skeleton — Claude Code to flesh out the parsers)
```js
// Map Path — rewrites map links to Apple Maps. On-device only, no network, no storage.
(() => {
  const MAP_HOSTS = [
    "google.com/maps", "maps.google.com", "goo.gl/maps", "maps.app.goo.gl",
    "waze.com", "bing.com/maps", "wego.here.com", "here.com"
  ];

  function isMapLink(url) {
    if (!url) return false;
    if (url.includes("maps.apple.com")) return false; // already Apple Maps
    return MAP_HOSTS.some(h => url.includes(h));
  }

  // TODO(Claude Code): extract query/address/coords from each source's URL shape
  // and build the right maps.apple.com target (?q= / ?ll= / ?daddr=).
  function toAppleMaps(url) {
    try {
      const u = new URL(url, location.href);
      const q = u.searchParams.get("q")
        || u.searchParams.get("destination")
        || u.searchParams.get("daddr");
      if (q) return "https://maps.apple.com/?q=" + encodeURIComponent(q);
      return null; // fall through = leave original link untouched
    } catch {
      return null;
    }
  }

  function rewrite(root = document) {
    root.querySelectorAll("a[href]").forEach(a => {
      if (!isMapLink(a.href)) return;
      const target = toAppleMaps(a.href);
      if (target) a.href = target;
    });
  }

  rewrite();
  // Re-run on DOM changes (SPAs, lazy-loaded results)
  new MutationObserver(() => rewrite()).observe(
    document.documentElement, { childList: true, subtree: true }
  );
})();
```

### `extension/popup.html` (tiny, no-fuss)
```html
<!DOCTYPE html>
<html><head><meta charset="utf-8"><link rel="stylesheet" href="popup.css"></head>
<body>
  <h1>Map Path</h1>
  <p>Map links route to Apple Maps. Nothing is tracked.</p>
  <p class="by">CodeCrafted Apps · Digital Life Compass</p>
</body></html>
```

---

## 6. Notes / decisions to lock in with Claude Code

1. **Icon:** plain neutral pin or compass needle, single flat color, no badge, no animation. Reuse the `sharp` rasterization approach from the GPQ icon pipeline.
2. **No storage** in v1.0 unless an on/off toggle is added — and if added, use `storage.local` only, never sync.
3. **Generated Xcode project:** decide whether to commit it or `.gitignore` it. Recommended: gitignore the generated project, keep `extension/` as the source of truth, regenerate via converter. (One change at a time — confirm before committing the big Xcode tree.)
4. **Bundle ID:** `com.doncastle.mappath` (matches your existing `com.doncastle.*` convention — verify against App Store Connect before first archive).
5. **App Review differentiation (vs the dozen clones):** on-device only, zero telemetry, open-source + auditable, explicit privacy guarantee, US-developed. Put this in the App Store review notes, not just marketing.
6. **Site:** `docs/` is public GitHub Pages → `safari.extensions.codecraftedapps.com`. Static only, zero personal data, zero backend. Parallel subdomains planned: `chrome.` / `firefox.` / `opera.`
7. **Test before every commit:** build in Xcode, load in Safari, verify a Google Maps search-result link and an embedded map both route to Apple Maps; verify a non-map page does nothing.

---

## 7. Cross-browser parallel (future repos)

Map Path is also planned for Chrome and Firefox in their own repos (`map-path-chrome`, `map-path-firefox`). The link-detection logic in `content.js` is the shared brain — if it stabilizes, consider extracting it into a small standalone module the three repos pull in, but only once it's proven. Don't pre-build that abstraction.
