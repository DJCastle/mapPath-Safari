// Map Path — rewrites map links to Apple Maps.
// On-device only: no network calls, no storage, no analytics. (Option 1: content-script rewrite.)
(() => {
  "use strict";

  // ---- Coordinate parsing -------------------------------------------------
  // A "lat,lng" string with sane ranges. Returns "lat,lng" (normalized) or null.
  const COORD_RE = /^\s*(-?\d{1,3}(?:\.\d+)?)\s*,\s*(-?\d{1,3}(?:\.\d+)?)\s*$/;

  // The services' web-mercator zoom scales map 1:1 onto Apple Maps' z=
  // (2-21). Out-of-range or non-numeric values are dropped, not clamped.
  function asZoom(s) {
    if (!s) return null;
    const z = parseFloat(s);
    return isFinite(z) && z >= 2 && z <= 21 ? String(Math.round(z * 100) / 100) : null;
  }

  // Open Location Code (Plus Code), full or short-with-locality:
  // "87G8Q2XQ+XF" or "Q2XQ+XF Las Vegas". The 20-char OLC alphabet excludes
  // vowels and lookalikes, so ordinary place names don't match.
  const PLUS_CODE_RE = /^[23456789CFGHJMPQRVWX]{4,8}\+[23456789CFGHJMPQRVWX]{2,}([\s,]|$)/i;
  function asCoords(s) {
    if (!s) return null;
    const m = COORD_RE.exec(s);
    if (!m) return null;
    const lat = parseFloat(m[1]);
    const lng = parseFloat(m[2]);
    if (!isFinite(lat) || !isFinite(lng)) return null;
    if (lat < -90 || lat > 90 || lng < -180 || lng > 180) return null;
    return lat + "," + lng;
  }

  // ---- Apple Maps URL builder --------------------------------------------
  // Build params by hand so the comma in `ll` / `sll` stays literal (Apple Maps
  // is happiest with ll=lat,lng rather than ll=lat%2Clng).
  function appleURL({ ll, q, sll, saddr, daddr, z }) {
    const parts = [];
    if (ll) parts.push("ll=" + ll);
    if (q) parts.push("q=" + encodeURIComponent(q));
    if (sll) parts.push("sll=" + sll);
    if (saddr) parts.push("saddr=" + encodeURIComponent(saddr));
    if (daddr) parts.push("daddr=" + encodeURIComponent(daddr));
    if (z) parts.push("z=" + z);
    if (!parts.length) return null;
    return "https://maps.apple.com/?" + parts.join("&");
  }

  // A destination/origin may itself be coordinates; prefer the literal form.
  function place(s) {
    if (!s) return null;
    const c = asCoords(s);
    return c || s.trim();
  }

  // ---- Per-source extractors ---------------------------------------------
  // Each returns an {ll|q|saddr|daddr} descriptor, or null to leave the link
  // untouched (the safe default — never produce a worse link than the original).

  function fromGoogle(u) {
    const sp = u.searchParams;

    // Directions: /maps/dir/?api=1&origin=...&destination=... or saddr/daddr.
    const dest = sp.get("destination") || sp.get("daddr");
    if (dest) {
      const orig = sp.get("origin") || sp.get("saddr");
      const saddr = orig ? place(orig) : undefined;
      // A coordinate destination with no origin reads best as a dropped pin
      // (ll). But if an origin is present it's a directions request — keep the
      // destination as daddr (place() preserves literal coords) so Apple Maps
      // actually routes, instead of emitting ll+saddr and silently dropping the
      // origin (which would be a worse link than the original).
      const c = asCoords(dest);
      if (c && !saddr) return { ll: c };
      return { daddr: place(dest), saddr };
    }

    // Path-style directions: /maps/dir/<origin>/<destination>[/@viewport].
    const dir = u.pathname.match(/\/maps\/dir\/(.+)/);
    if (dir) {
      // Waypoint segments end at the @coords viewport suffix; a trailing
      // slash leaves an empty last segment we drop.
      let segs = dir[1].split("/");
      const at = segs.findIndex((s) => s.startsWith("@"));
      if (at !== -1) segs = segs.slice(0, at);
      while (segs.length && segs[segs.length - 1] === "") segs.pop();
      // Apple Maps URLs can't express intermediate stops. Rewriting a
      // multi-stop route would silently drop stops and route to the wrong
      // destination — worse than the original — so leave it untouched.
      if (segs.length > 2) return null;
      if (segs.length === 2) {
        const decode = (s) => decodeURIComponent(s.replace(/\+/g, " "));
        const saddr = segs[0] ? place(decode(segs[0])) : undefined;
        return { saddr, daddr: place(decode(segs[1])) };
      }
      // A single segment falls through to the /maps/dir/<query> handling below.
    }

    // Explicit query params.
    let q = sp.get("q") || sp.get("query");

    // Path forms: /maps/search/<query>, /maps/place/<name>, /maps/dir/<a>/<b>.
    if (!q) {
      const m = u.pathname.match(/\/maps\/(?:search|place|dir)\/([^/@]+)/);
      if (m && m[1]) q = decodeURIComponent(m[1].replace(/\+/g, " "));
    }

    if (q) {
      // Google's documented ?q=place_id:ChIJ... form — an opaque ID only
      // Google can resolve. Searching the literal string in Apple Maps
      // dead-ends, so leave the link alone (same rationale as shorteners).
      if (/^place_id:/i.test(q)) return null;
      const c = asCoords(q);
      if (c) return { ll: c };
      const vp = u.pathname.match(/@(-?\d+(?:\.\d+)?),(-?\d+(?:\.\d+)?)(?:,(\d+(?:\.\d+)?)z)?/);
      const sll = vp ? asCoords(vp[1] + "," + vp[2]) : null;
      const z = asZoom((vp && vp[3]) || sp.get("z") || sp.get("zoom"));
      // Plus Codes ("87G8Q2XQ+XF"): Apple Maps can't resolve them, so a q=
      // search dead-ends at No Results. The @coords are the same location —
      // pin them directly; without coords, leave the original link (Google
      // resolves the code, we can't).
      if (PLUS_CODE_RE.test(q)) return sll ? { ll: sll, z } : null;
      // A named place plus @lat,lng viewport coords: keep the name for the
      // place card but anchor the search at those coordinates (sll), so an
      // ambiguous name resolves to the linked place — not whichever match is
      // nearest to the user. (A "Statue of Liberty" link must open the New
      // York statue, not the Las Vegas replica.)
      return sll ? { q, sll, z } : { q };
    }

    // Bare coordinate params.
    const ll = asCoords(sp.get("ll"));
    if (ll) return { ll };

    // Map-center coords in the path: @lat,lng,zoom — range-checked like
    // every other coordinate source, so a crafted @999,999 link is left
    // alone instead of becoming a broken Apple Maps URL.
    const at = u.pathname.match(/@(-?\d+(?:\.\d+)?),(-?\d+(?:\.\d+)?)(?:,(\d+(?:\.\d+)?)z)?/);
    if (at) {
      const c = asCoords(at[1] + "," + at[2]);
      if (c) return { ll: c, z: asZoom(at[3] || sp.get("z") || sp.get("zoom")) };
    }

    return null;
  }

  function fromWaze(u) {
    const sp = u.searchParams;
    // waze.com/ul?ll=lat,lng | ?ll=lat%2Clng (searchParams.get already decodes
    // the %2C, so a single asCoords call covers both forms).
    const zw = asZoom(sp.get("zoom") || sp.get("z"));
    const ll = asCoords(sp.get("ll"));
    if (ll) return { ll, z: zw };
    // Legacy livemap form (Wikipedia's GeoHack emits it): ?lat=..&lon=..
    const lat = sp.get("lat"), lon = sp.get("lon");
    if (lat && lon) {
      const c = asCoords(lat + "," + lon);
      if (c) return { ll: c, z: zw };
    }
    // livemap "to=ll.lat,lng" — range-checked like every other coord source.
    const to = sp.get("to") || sp.get("navigate");
    if (to) {
      const m = to.match(/ll\.(-?\d+(?:\.\d+)?),(-?\d+(?:\.\d+)?)/);
      if (m) {
        const c = asCoords(m[1] + "," + m[2]);
        if (c) return { daddr: c };
      }
    }
    const q = sp.get("q");
    if (q) {
      const c = asCoords(q);
      return c ? { ll: c } : { q };
    }
    return null;
  }

  function fromBing(u) {
    const sp = u.searchParams;
    // Center: cp=lat~lng
    let sll = null;
    const cp = sp.get("cp");
    if (cp) {
      const m = cp.match(/(-?\d+(?:\.\d+)?)~(-?\d+(?:\.\d+)?)/);
      if (m) sll = asCoords(m[1] + "," + m[2]);
    }
    const zb = asZoom(sp.get("lvl"));
    const q = sp.get("q") || sp.get("where1");
    if (q) {
      const c = asCoords(q);
      if (c) return { ll: c };
      // Name + map center: keep the name for the place card, anchor the
      // search at the center so an ambiguous name resolves to the linked
      // place rather than the match nearest to the user.
      return sll ? { q, sll, z: zb } : { q };
    }
    if (sll) return { ll: sll, z: zb };
    return null;
  }

  function fromHere(u) {
    const sp = u.searchParams;
    // share.here.com/l/lat,lng[,label] — HERE's primary share format is
    // path-based. The label (when present) rides as q, which Apple Maps
    // treats as the pin's name alongside ll.
    const l = u.pathname.match(/^\/l\/(-?\d+(?:\.\d+)?),(-?\d+(?:\.\d+)?)(?:,([^/]+))?/);
    if (l) {
      const c = asCoords(l[1] + "," + l[2]);
      const zl = asZoom(sp.get("z"));
      if (c) return l[3] ? { ll: c, q: decodeURIComponent(l[3]), z: zl } : { ll: c, z: zl };
    }
    // share.here.com/r/<from>/<to> — HERE's path-based directions share.
    // Each leg is lat,lng[,label]. More than two legs is a multi-stop route
    // Apple Maps can't express, so it's left untouched.
    const r = u.pathname.match(/^\/r\/(.+)/);
    if (r) {
      const legs = r[1].split("/").filter(Boolean);
      if (legs.length === 2) {
        const coords = legs.map((leg) => {
          const m = leg.match(/^(-?\d+(?:\.\d+)?),(-?\d+(?:\.\d+)?)/);
          return m ? asCoords(m[1] + "," + m[2]) : null;
        });
        if (coords[0] && coords[1]) return { saddr: coords[0], daddr: coords[1] };
      }
      return null;
    }
    // wego.here.com/?map=lat,lng,zoom,type
    let sll = null, zh = null;
    const map = sp.get("map");
    if (map) {
      const m = map.match(/(-?\d+(?:\.\d+)?),(-?\d+(?:\.\d+)?)(?:,(\d+(?:\.\d+)?))?/);
      if (m) { sll = asCoords(m[1] + "," + m[2]); zh = asZoom(m[3]); }
    }
    const q = sp.get("q");
    if (q) {
      const c = asCoords(q);
      if (c) return { ll: c };
      // Name + map center: same anchoring rationale as fromGoogle/fromBing.
      return sll ? { q, sll, z: zh } : { q };
    }
    if (sll) return { ll: sll, z: zh };
    return null;
  }

  // ---- Host classification (hostname-based, not substring) ----------------
  // Substring matching ("here.com" inside "sphere.com") would mis-fire, so we
  // classify on the parsed hostname + path instead.

  // TLD shape is anchored: google.com, google.de, google.co.uk — but not
  // google.evil.com (a dot-accepting class would match lookalike domains).
  function isGoogleHost(host) {
    return host === "maps.google.com" || /(^|\.)google\.(com|[a-z]{2,3})(\.[a-z]{2})?$/.test(host);
  }

  function isAppleMapsHost(host) {
    return host === "maps.apple.com" || host.endsWith(".maps.apple.com");
  }

  function classify(u) {
    const host = u.hostname.toLowerCase();
    const path = u.pathname.toLowerCase();

    if (host === "maps.google.com" || (isGoogleHost(host) && path.startsWith("/maps"))) return fromGoogle;

    // Waze: only its map surfaces. A bare host match would also capture
    // support.waze.com/search?q=... and turn a help-center search into an
    // Apple Maps search — a strictly worse link.
    const isWazeHost = host === "waze.com" || host === "www.waze.com" || host === "ul.waze.com";
    // Live-map share links can carry a locale prefix (waze.com/en/live-map/,
    // /en-US/ul) — allow one optional segment before the map path.
    const isWazeMapPath = /^\/(?:[a-z]{2}(?:-[a-z]{2,4})?\/)?(?:ul|live-map|livemap|ll)(?:\/|$)/.test(path);
    if (isWazeHost && isWazeMapPath) return fromWaze;

    if ((host === "bing.com" || host.endsWith(".bing.com")) && path.startsWith("/maps")) return fromBing;

    // HERE: the map product lives on wego.here.com / share.here.com. The
    // corporate site (www.here.com) also uses ?q= for site search — leave it.
    if (host === "wego.here.com" || host === "share.here.com") return fromHere;

    // Opaque shorteners can't be resolved client-side without following them
    // (a network call we refuse to make). Best effort = leave them untouched.
    // goo.gl/maps, maps.app.goo.gl → no handler.

    return null;
  }

  // ---- Link rewriting -----------------------------------------------------
  // Any parse failure — malformed percent-encoding throwing inside
  // decodeURIComponent, a hostile href, a parser bug — must leave the link
  // untouched rather than throw: one bad link must never break rewriting for
  // the rest of the page or abort a MutationObserver batch.
  function toAppleMaps(href) {
    try {
      return parseLink(href);
    } catch {
      return null;
    }
  }

  function parseLink(href) {
    const u = new URL(href, location.href); // throws on invalid hrefs — caught in toAppleMaps
    const host = u.hostname.toLowerCase();
    if (isAppleMapsHost(host)) return null; // already Apple Maps

    // Google redirect wrappers (Gmail web, Docs): google.com/url?q=<target>.
    // The target rides inside the URL itself — no network needed to unwrap.
    // Rewrite only when the target is a map link we'd rewrite anyway, or lift
    // out a wrapped Apple Maps link; any other wrapped link is left alone.
    if (isGoogleHost(host) && u.pathname === "/url") {
      const target = u.searchParams.get("q") || u.searchParams.get("url");
      if (!target) return null;
      const inner = new URL(target); // absolute or bust — throws are caught above
      // Lift out only a clean https Apple Maps link; oddities (http, userinfo)
      // fall through to parseLink, which passes Apple hosts through untouched.
      if (isAppleMapsHost(inner.hostname.toLowerCase()) &&
          inner.protocol === "https:" && !inner.username) return inner.href;
      return parseLink(inner.href);
    }

    // geo: URIs — geo:lat,lng[;crs/u=..][?q=label]. No host, so handle before classify.
    if (u.protocol === "geo:") {
      const body = href.slice(href.indexOf(":") + 1);
      const [coordPart, queryPart] = body.split("?");
      const q = queryPart ? new URLSearchParams(queryPart).get("q") : null;
      const ll = asCoords((coordPart || "").split(";")[0]);
      // geo:0,0?q=Label is the "named place" convention — prefer the label.
      if (q && (!ll || ll === "0,0")) return appleURL(asCoords(q) ? { ll: asCoords(q) } : { q });
      if (ll) {
        // A real coordinate plus a ?q= label: keep both — Apple Maps shows
        // q as the pin's name at ll.
        const label = q && !asCoords(q) ? q : null;
        return appleURL(label ? { ll, q: label } : { ll });
      }
      return null;
    }

    const handler = classify(u);
    if (!handler) return null;
    const desc = handler(u);
    if (!desc) return null;
    // Drop undefined keys so the builder stays clean.
    const clean = {};
    for (const k of ["ll", "q", "sll", "saddr", "daddr", "z"]) if (desc[k]) clean[k] = desc[k];
    return appleURL(clean);
  }

  const REWRITTEN = "data-mappath-rewritten";

  function rewriteLink(a) {
    if (a.hasAttribute(REWRITTEN)) return;
    const target = toAppleMaps(a.href);
    if (target) {
      a.href = target;
      a.setAttribute(REWRITTEN, "1");
    }
  }

  function rewrite(root) {
    const scope = root && root.querySelectorAll ? root : document;
    scope.querySelectorAll("a[href]").forEach(rewriteLink);
  }

  // ---- Popup bridge --------------------------------------------------------
  // The popup asks for the page's visible text so the native handler can run
  // on-device address detection. Strictly user-initiated: nothing is read
  // until the user opens the popup, and the text is scanned and discarded —
  // never stored, never transmitted. Payload is capped so huge pages stay
  // cheap. (Guarded: the extension API doesn't exist in the test harness.)
  if (typeof browser !== "undefined" && browser.runtime && browser.runtime.onMessage) {
    browser.runtime.onMessage.addListener((msg) => {
      if (msg && msg.type === "mappath.collectText") {
        const text = (document.body && document.body.innerText) || "";
        return Promise.resolve({ text: text.slice(0, 200000) });
      }
      return undefined;
    });
  }

  rewrite(document);

  // Re-run on DOM changes (SPAs, lazy-loaded results). Scoped to added nodes,
  // plus href changes on existing anchors — SPAs often swap an anchor's href
  // in place to a map URL without replacing the node. Our own rewrite sets the
  // href once and marks the anchor, so the resulting attribute mutation is a
  // no-op (rewriteLink early-returns on the REWRITTEN marker) — no loop.
  const observer = new MutationObserver((mutations) => {
    for (const mut of mutations) {
      if (mut.type === "attributes") {
        const t = mut.target;
        if (t && t.nodeType === 1 && t.matches && t.matches("a[href]")) rewriteLink(t);
        continue;
      }
      for (const node of mut.addedNodes) {
        if (node.nodeType !== 1) continue;
        if (node.matches && node.matches("a[href]")) rewriteLink(node);
        if (node.querySelectorAll) rewrite(node);
      }
    }
  });
  observer.observe(document.documentElement, {
    childList: true,
    subtree: true,
    attributes: true,
    attributeFilter: ["href"],
  });
})();
