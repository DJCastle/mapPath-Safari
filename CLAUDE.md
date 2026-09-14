# Map Path — Safari · project rules for Claude Code

A Safari Web Extension that rewrites map links (Google / Waze / Bing / HERE) to
**Apple Maps**. Privacy-first: on-device only, no network, no storage, no
analytics. By CodeCrafted Apps, part of the Digital Life Compass ecosystem.

**Read [HANDOFF.md](HANDOFF.md) first** — it is the canonical build + design
spec. This file is the short operating guide; HANDOFF has the full reasoning.

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
- There is a parser test harness pattern (fake-DOM + `vm.runInThisContext`) used
  during scaffolding — re-run an equivalent check after touching `content.js`.

## Status

See [CLAUDE-LOG.md](CLAUDE-LOG.md) for the running session log and current state.
