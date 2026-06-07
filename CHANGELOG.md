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
- Project docs: README, PRIVACY, LICENSE (MIT), HANDOFF.

### Pending
- Icon set (48/96/128/256/512) — see `extension/icons/README.md`.
- Xcode container app via `safari-web-extension-converter`.
- GitHub Pages site in `docs/`.

[Unreleased]: https://github.com/DJCastle/mapPath-Safari
