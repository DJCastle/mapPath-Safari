// Map Path — rewrites map links to Apple Maps.
// On-device only: no network calls, no storage, no analytics. (Option 1: content-script rewrite.)
(() => {
  "use strict";

  // ---- Coordinate parsing -------------------------------------------------
  // A "lat,lng" string with sane ranges. Returns "lat,lng" (normalized) or null.
  const COORD_RE = /^\s*(-?\d{1,3}(?:\.\d+)?)\s*,\s*(-?\d{1,3}(?:\.\d+)?)\s*$/;
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
  function appleURL({ ll, q, saddr, daddr }) {
    const parts = [];
    if (ll) parts.push("ll=" + ll);
    if (q) parts.push("q=" + encodeURIComponent(q));
    if (saddr) parts.push("saddr=" + encodeURIComponent(saddr));
    if (daddr) parts.push("daddr=" + encodeURIComponent(daddr));
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
      const d = place(dest);
      const c = asCoords(dest);
      return { daddr: c ? null : d, ll: c || undefined, saddr: orig ? place(orig) : undefined };
    }

    // Explicit query params.
    let q = sp.get("q") || sp.get("query");

    // Path forms: /maps/search/<query>, /maps/place/<name>, /maps/dir/<a>/<b>.
    if (!q) {
      const m = u.pathname.match(/\/maps\/(?:search|place|dir)\/([^/@]+)/);
      if (m && m[1]) q = decodeURIComponent(m[1].replace(/\+/g, " "));
    }

    if (q) {
      const c = asCoords(q);
      return c ? { ll: c } : { q };
    }

    // Bare coordinate params.
    const ll = asCoords(sp.get("ll"));
    if (ll) return { ll };

    // Map-center coords in the path: @lat,lng,zoom
    const at = u.pathname.match(/@(-?\d+(?:\.\d+)?),(-?\d+(?:\.\d+)?)/);
    if (at) return { ll: at[1] + "," + at[2] };

    return null;
  }

  function fromWaze(u) {
    const sp = u.searchParams;
    // waze.com/ul?ll=lat,lng | ?ll=lat%2Clng
    const ll = asCoords(sp.get("ll")) || asCoords((sp.get("ll") || "").replace("%2C", ","));
    if (ll) return { ll };
    // livemap "to=ll.lat,lng"
    const to = sp.get("to") || sp.get("navigate");
    if (to) {
      const m = to.match(/ll\.(-?\d+(?:\.\d+)?),(-?\d+(?:\.\d+)?)/);
      if (m) return { daddr: m[1] + "," + m[2] };
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
    const cp = sp.get("cp");
    if (cp) {
      const m = cp.match(/(-?\d+(?:\.\d+)?)~(-?\d+(?:\.\d+)?)/);
      if (m) {
        const c = asCoords(m[1] + "," + m[2]);
        if (c) return { ll: c };
      }
    }
    const q = sp.get("q") || sp.get("where1");
    if (q) {
      const c = asCoords(q);
      return c ? { ll: c } : { q };
    }
    return null;
  }

  function fromHere(u) {
    const sp = u.searchParams;
    // wego.here.com/?map=lat,lng,zoom,type
    const map = sp.get("map");
    if (map) {
      const m = map.match(/(-?\d+(?:\.\d+)?),(-?\d+(?:\.\d+)?)/);
      if (m) {
        const c = asCoords(m[1] + "," + m[2]);
        if (c) return { ll: c };
      }
    }
    const q = sp.get("q");
    if (q) {
      const c = asCoords(q);
      return c ? { ll: c } : { q };
    }
    return null;
  }

  // ---- Host classification (hostname-based, not substring) ----------------
  // Substring matching ("here.com" inside "sphere.com") would mis-fire, so we
  // classify on the parsed hostname + path instead.
  function classify(u) {
    const host = u.hostname.toLowerCase();
    const path = u.pathname.toLowerCase();

    const isGoogleHost = host === "maps.google.com" || /(^|\.)google\.[a-z.]+$/.test(host);
    if (host === "maps.google.com" || (isGoogleHost && path.startsWith("/maps"))) return fromGoogle;

    if (host === "waze.com" || host.endsWith(".waze.com")) return fromWaze;

    if ((host === "bing.com" || host.endsWith(".bing.com")) && path.startsWith("/maps")) return fromBing;

    if (host === "here.com" || host === "wego.here.com" || host.endsWith(".here.com")) return fromHere;

    // Opaque shorteners can't be resolved client-side without following them
    // (a network call we refuse to make). Best effort = leave them untouched.
    // goo.gl/maps, maps.app.goo.gl → no handler.

    return null;
  }

  // ---- Link rewriting -----------------------------------------------------
  function toAppleMaps(href) {
    let u;
    try {
      u = new URL(href, location.href);
    } catch {
      return null;
    }
    if (u.hostname.toLowerCase().endsWith("maps.apple.com")) return null; // already Apple Maps
    const handler = classify(u);
    if (!handler) return null;
    const desc = handler(u);
    if (!desc) return null;
    // Drop undefined keys so the builder stays clean.
    const clean = {};
    for (const k of ["ll", "q", "saddr", "daddr"]) if (desc[k]) clean[k] = desc[k];
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

  rewrite(document);

  // Re-run on DOM changes (SPAs, lazy-loaded results), scoped to added nodes.
  const observer = new MutationObserver((mutations) => {
    for (const mut of mutations) {
      for (const node of mut.addedNodes) {
        if (node.nodeType !== 1) continue;
        if (node.matches && node.matches("a[href]")) rewriteLink(node);
        if (node.querySelectorAll) rewrite(node);
      }
    }
  });
  observer.observe(document.documentElement, { childList: true, subtree: true });
})();
