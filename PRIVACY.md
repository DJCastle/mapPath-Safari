# Privacy Policy — Map Path

**Effective date:** 2026-06-07

Map Path is built privacy-first. The short version: **it collects nothing.**

## What Map Path does

Map Path runs entirely on your device. When you view a web page, it looks for
links that point to map services (Google Maps, Waze, Bing Maps, HERE WeGo) and
rewrites them to open in Apple Maps instead.

## What Map Path collects

**Nothing.** Map Path has:

- **No tracking** — it does not record what pages you visit or what links you click.
- **No analytics** — no usage metrics, no telemetry, no crash reporting.
- **No network calls** — it never contacts any server, ours or anyone else's.
- **No storage** — it does not save your browsing data, history, or any
  personal information.

All link detection and rewriting happens locally, in the page, in real time.

The address finder (v1.2) reads the page's visible text **only when you
open the Map Path popup** — opening it is what triggers the scan. The
text is checked on your device with Apple's built-in data detectors and
immediately discarded. It is never stored, logged, or transmitted, and
nothing scans in the background while you browse.

The companion app (the one you open to set the extension up) stores a single
on-device yes/no value — whether you've launched it before — so the setup
walkthrough only shows once. It contains no personal data and never leaves
your device.

## Data sharing

Because Map Path collects no data, there is no data to share, sell, or disclose
— to us or to any third party.

## Permissions

Map Path requests only the ability to read and modify links on the pages you
visit, which is required to rewrite map links. For one narrow case — Google
search-result place links that carry no address in their web address — it also
reads that link's own visible label (the text you see on the link), and only
rewrites when the label is itself a street address. It requests no host permissions
beyond that and makes no outbound connections.

## Changes

If this policy ever changes, the updated version will be published in this
repository and on the Map Path website.

## Contact

Questions: **support@codecraftedapps.com**

— CodeCrafted Apps
