# Changelog

All notable changes to Map Path are documented here.
Format loosely follows [Keep a Changelog](https://keepachangelog.com/).

## [Unreleased]

### Added

- Initial web-extension source (`extension/`): MV3 manifest, content-script link
  rewriter, and static about popup.
- Per-source link parsers for Google Maps, Waze, Bing Maps, and HERE WeGo, plus
  raw coordinate detection.
- Hostname-based source classification (avoids substring false-positives).
- Project docs: README, PRIVACY, LICENSE (MIT).
- Adaptive app icon (`app-icon/MapPath.icon`), built in Icon Composer — route-to-pin
  mark on a map grid; Light / Dark / Clear appearances.
- Extension toolbar icons (`extension/icons/icon-{48,96,128,256,512}.png`),
  generated from the app icon (placeholder downscales — replace with purpose-built
  glyphs before submission).
- Expanded parser coverage: Google path-style directions (`/maps/dir/A/B`) and
  `geo:` URIs (`geo:lat,lng`, `geo:0,0?q=label`, `;u=`/`;crs=` suffixes).
- Parser test harness (`test/parser.test.mjs`): fake-DOM + `vm` runner asserting
  22 real-world link variations rewrite (or are intentionally left alone). 22/22 passing.
- Public marketing/legal/test pages shipped in the `codeCraftedApps` repo at
  `codecraftedapps.com/extensions/map-path/` (index, privacy, terms, support,
  test.html). Map Path wired into the Safari category page + extensions hub.

### Changed

- Site plan superseded: no standalone `docs/` GitHub Pages site / `*.codecraftedapps.com`
  subdomain. The site is a product-folder subpath in the consolidated
  `codecraftedapps.com` site instead.

### Pending

- Xcode container app via `safari-web-extension-converter`.

[Unreleased]: https://github.com/DJCastle/mapPath-Safari
