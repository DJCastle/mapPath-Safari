# Privacy Policy — Map Path

**Effective date:** October 6, 2026

Map Path is built privacy-first. The short version: **it collects nothing.**

## What Map Path does

Map Path runs entirely on your device. When you view a web page, it looks for
links that point to map services (Google Maps, Waze, Bing Maps, HERE WeGo) and
rewrites them to open in Apple Maps instead. When you open the popup, its
address finder scans the page's visible text for addresses. Both happen
entirely on your device.

To redirect a map link, the extension has to be able to see that link on the
page you're viewing — read its destination, recognize it as a Google Maps /
Waze / Bing / HERE link, and replace it with the equivalent `maps.apple.com`
address. That reading and rewriting happens on the page, in the moment, and
then it's over. Nothing about the link, the page, or you is recorded, copied
off the page, or sent anywhere — not to us, not to Apple, not to anyone.

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

## What the extension can access, and why

To rewrite map links, Safari runs Map Path's content script on the web pages
you view so it can read the page's links and change the ones that point at
supported map services. That is why Map Path asks for website access. For one
narrow case — Google search-result place links that carry no address in their
web address — it also reads that link's own visible label (the text you see on
the link), and only rewrites when the label is itself a street address. When
you open the Map Path popup, the same access lets the address finder read the
page's visible text for an on-device scan. Page access is used for those two
purposes and nothing else. Map Path does not:

- Record, store, or transmit page content (the address finder reads visible
  text only while the popup is open)
- Track which pages you open or which links you click
- Access your browsing history, bookmarks, tabs, cookies, or downloads
- Access your location, microphone, camera, or any other sensor
- Communicate with any server, other app, or other extension (it talks only
  to its own app, on your device, via native messaging)
- Store any personal information, on your device or anywhere else

You can confirm this in Safari's extension settings, which show exactly what
Map Path is allowed to do, and in this repository's source code.

## Apple Maps

When you click a link that Map Path has rewritten, your browser or device
opens Apple Maps with the address or coordinates from that link. From that
point on, Apple Maps is handling your request under
[Apple's privacy policy](https://www.apple.com/legal/privacy/), not this one.
Map Path's involvement ends the moment the link is rewritten; it is not part
of the navigation and sees nothing about your route or destination.

## Third parties

There are no third parties. No analytics provider, no error-reporting
service, no payment processor, no ad network, no CDN. Map Path is a single
self-contained extension with no external dependencies at runtime.

## Children

Map Path doesn't collect anything from anyone, so there's nothing
child-specific to disclose. It's safe for any age group old enough to use a
web browser.

## Changes

If this policy ever changes, the updated version will be published in this
repository and at the same URL on the Map Path website
([codecraftedapps.com/extensions/map-path/privacy.html](https://codecraftedapps.com/extensions/map-path/privacy.html))
with a new effective date at the top. Material changes will be called out in
the changelog of any release that introduces them.

## Contact

Questions: **support@codecraftedapps.com**

— CodeCrafted Apps
