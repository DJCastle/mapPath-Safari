# Map Path — Safari · project rules for Claude Code

Shared craft rules — imported so every surface loads them, including Xcode's sandboxed agent:

@Agentic_Developer.md

A Safari Web Extension that rewrites map links (Google / Waze / Bing / HERE) to
**Apple Maps**. Privacy-first: on-device only, no network, no storage, no
analytics. By CodeCrafted Apps, part of the Digital Life Compass ecosystem.

**This file is the spec of record.** The longer design/handoff document and the
running session log are private and so are deliberately absent from this public
repo — anything durable about the project belongs here instead.

## Architecture (don't drift from this)

- **Option 1 only: content-script link rewriting.** `extension/content.js`
  scans for map links and rewrites `href` → `https://maps.apple.com/...`.
  No `webRequest` (Safari MV3 doesn't support blocking it), no
  `declarativeNetRequest`, no host permissions beyond the content-script match.
- **Canonical sources are `extension/`, `container-app/`, and `app-icon/`.** The
  Xcode tree (`Map Path/`) is a generated build artifact (`safari-web-extension-converter`)
  and is `.gitignore`d — it embeds the Apple Team ID and must not land in the
  public repo. **Don't treat the Xcode tree as source of truth.** Edit the
  canonical files, then run `scripts/sync-container-app.sh --apply` to push them
  into the Xcode tree. Fresh-Mac flow: `safari-web-extension-converter extension/`
  → set dev team in Xcode → `scripts/sync-container-app.sh --apply` → build.
- **Build settings live only in the un-committed Xcode tree, so re-apply them
  after regenerating it.** The converter emits its own defaults; these are
  deliberate and are lost on regeneration:
  `SWIFT_VERSION = 6.0` (Swift 6 language mode — Swift 5 hid a real actor
  isolation bug), deployment targets `26.0` for iOS and macOS (floor is OS 26
  even though we build against the 27 SDK), and `MARKETING_VERSION` /
  `CURRENT_PROJECT_VERSION` matching `extension/manifest.json` and CHANGELOG.
- **Call SafariServices through its `async` forms, never with a completion
  closure.** Handlers such as `getStateOfSafariExtension` are declared
  `NS_SWIFT_UI_ACTOR`, but Safari calls them on a background XPC queue. Swift 6
  gives the closure main-actor isolation from the parameter type — marking it
  `@Sendable` doesn't change that — and its runtime check traps. That shipped as
  a launch crash in 1.2.1 build 21. `try await …` resumes a continuation instead.
- **Classify sources by hostname, not substring.** `"here.com".includes` matches
  `atmosphere.com`; the parser uses parsed `u.hostname` + path instead. Keep it
  that way.
- **Never produce a worse link than the original.** When a parser is unsure, it
  returns null and leaves the link untouched. Pass-through `maps.apple.com` links.
- **Shorteners** (`goo.gl/maps`, `maps.app.goo.gl`) are detected but left alone —
  resolving them needs a network call, which breaks the privacy promise.

## Constraints

- **No storage** in v1.0. If a toggle is added, `storage.local` only, never sync.
- **Platforms:** macOS, iOS, iPadOS, visionOS. **Not tvOS.**
- **Bundle ID:** `com.doncastle.mappath` (verify against App Store Connect
  before first archive).
- **Public repo** → no personal data. Contact via
  `support@codecraftedapps.com` / `contact@codecraftedapps.com`. No gmail, no
  `/Users` paths, no Team IDs in committed files.
- **Marketing/legal site lives in the `codeCraftedApps` repo**, not here. Pages
  are product-folder subpaths at `codecraftedapps.com/extensions/map-path/`
  (index, privacy, terms, support, test.html), mirroring `go-private-quickly/`.
  The old plan for a standalone `docs/` site on a `*.codecraftedapps.com`
  subdomain is **superseded** — don't build `docs/` here. (Site was consolidated
  to one domain with subpaths + Cloudflare 301s; subdomains just redirect.)

## Working agreement

- Don is an agentic coder: generate/edit the code, explain decisions briefly, remind
  him to **test → verify → commit** at each step.
- One change at a time; verify before moving on.
- **After touching `content.js`, run `node scripts/test-parser.mjs`.** It loads the
  shipped parser in a fake-DOM `vm` context and asserts the never-worse rule. It
  must be green before you commit; add a case for whatever you changed.

## Status

Latest release: **1.2.1** (build 22, submitted 2026-09-24, live on iOS and macOS).
No cycle is open — bump the version when the next one starts. Deployment floor is OS 26 on
all platforms, built against the Xcode 27 SDK. See [CHANGELOG.md](CHANGELOG.md) for
the release history.
