// Map Path — parser test harness.
//
// Runs extension/content.js inside a fake DOM (vm sandbox) and asserts that
// each real-world map-link variation rewrites to the expected Apple Maps URL,
// or is intentionally LEFT untouched (shorteners, embeds, already-Apple links).
//
// Run:  node test/parser.test.mjs
//
// Each link points at a different US monument / patriotic site so the same
// case list can drive both this harness and the public test page.

import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";
import vm from "node:vm";

const __dirname = dirname(fileURLToPath(import.meta.url));
const SRC = readFileSync(join(__dirname, "..", "extension", "content.js"), "utf8");

const LEFT = Symbol("left-untouched");

// --- fake DOM ------------------------------------------------------------
function makeAnchor(href) {
  let _href = href;
  const attrs = Object.create(null);
  return {
    nodeType: 1,
    get href() { return _href; },
    set href(v) { _href = v; },
    getAttribute: (k) => attrs[k],
    setAttribute: (k, v) => { attrs[k] = v; },
    hasAttribute: (k) => k in attrs,
    matches: (sel) => sel === "a[href]",
    querySelectorAll: () => [],
  };
}

function runOn(href) {
  const anchor = makeAnchor(href);
  const document = {
    documentElement: {},
    querySelectorAll: (sel) => (sel === "a[href]" ? [anchor] : []),
  };
  const sandbox = {
    document,
    location: { href: "https://monuments.example/page" },
    URL,
    URLSearchParams,
    MutationObserver: class { observe() {} disconnect() {} },
    console,
  };
  vm.runInNewContext(SRC, sandbox, { timeout: 1000 });
  return anchor.href;
}

// --- cases (variation -> expected) --------------------------------------
// These are REAL-WORLD link shapes — the messy URLs people actually paste,
// share, or land on (with @coords, /data= blobs, encoded commas/tildes, and
// tracking params), not idealized canonical forms.
const A = "https://maps.apple.com/?";
const enc = encodeURIComponent;
const cases = [
  // ----- Google Maps -----
  ["Google place + @coords + data blob (address bar) — sll anchors the search", "https://www.google.com/maps/place/Statue+of+Liberty/@40.6892494,-74.0445004,17z/data=!3m1!4b1!4m6!3m5!1s0x89c25090129c363d:0x40c6a5770d25022b!8m2!3d40.6892494!4d-74.0445004!16zL20vMDdjeDQ", A + "q=" + enc("Statue of Liberty") + "&sll=40.6892494,-74.0445004"],
  ["Google search results URL — sll anchors the search", "https://www.google.com/maps/search/Lincoln+Memorial/@38.8892686,-77.0509287,17z", A + "q=" + enc("Lincoln Memorial") + "&sll=38.8892686,-77.0509287"],
  ["Google place with out-of-range @coords — name only, no sll", "https://www.google.com/maps/place/Statue+of+Liberty/@999.0,-74.0445004,17z", A + "q=" + enc("Statue of Liberty")],
  ["Google ccTLD (google.co.uk) place + @coords", "https://www.google.co.uk/maps/place/Big+Ben/@51.5007292,-0.1246254,17z", A + "q=" + enc("Big Ben") + "&sll=51.5007292,-0.1246254"],
  ["Google Plus Code place + @coords — pin the coords (Apple can't resolve codes)", "https://www.google.com/maps/place/87G8Q2XQ%2BXF/@36.1147065,-115.1728484,17z", A + "ll=36.1147065,-115.1728484"],
  ["Google short Plus Code + locality + @coords — pin the coords", "https://www.google.com/maps/place/Q2XQ%2BXF+Las+Vegas,+Nevada/@36.1147065,-115.1728484,17z", A + "ll=36.1147065,-115.1728484"],
  ["Google Plus Code with no coords — left alone (search would dead-end)", "https://www.google.com/maps/place/87G8Q2XQ%2BXF", LEFT],
  ["Google lookalike domain (google.evil.com) — left alone", "https://google.evil.com/maps/place/Fake+Bank+Branch", LEFT],
  ["Google lookalike domain (maps.google.com.evil.net) — left alone", "https://maps.google.com.evil.net/maps/place/Fake+Bank+Branch", LEFT],
  ["Google maps.google ?q with city/state", "https://maps.google.com/?q=Gateway+Arch,+St.+Louis,+MO", A + "q=" + enc("Gateway Arch, St. Louis, MO")],
  ["Google dropped pin (empty place + @coords)", "https://www.google.com/maps/place//@39.9489668,-75.1500233,18z/data=!4m2!3m1!1s0x0:0x0", A + "ll=39.9489668,-75.1500233"],
  ["Google 'Directions' button dir//destination", "https://www.google.com/maps/dir//Mount+Rushmore+National+Memorial,+Keystone,+SD/@43.879102,-103.459067,15z", A + "daddr=" + enc("Mount Rushmore National Memorial, Keystone, SD")],
  ["Google ?q raw coords (shared pin)", "https://www.google.com/maps?q=29.4259671,-98.4861419", A + "ll=29.4259671,-98.4861419"],
  ["Google classic ?daddr full address", "https://maps.google.com/maps?daddr=Liberty+Bell+Center,+526+Market+St,+Philadelphia,+PA", A + "daddr=" + enc("Liberty Bell Center, 526 Market St, Philadelphia, PA")],
  ["Google share api=1 query=coords", "https://www.google.com/maps/search/?api=1&query=38.8894838%2C-77.0352791&query_place_id=ChIJ", A + "ll=38.8894838,-77.0352791"],
  ["Google dir origin + coordinate destination (keep directions)", "https://www.google.com/maps/dir/?api=1&origin=Washington+Monument&destination=38.8893%2C-77.0502", A + "saddr=" + enc("Washington Monument") + "&daddr=" + enc("38.8893,-77.0502")],

  // ----- Waze -----
  ["Waze app share ll (encoded comma)", "https://www.waze.com/ul?ll=38.8910500%2C-77.0479700&navigate=yes&zoom=17", A + "ll=38.89105,-77.04797"],
  ["Waze live-map directions to=ll. + from", "https://www.waze.com/live-map/directions?to=ll.39.8118000,-77.2311000&from=ll.39.83,-77.23&at_load=yes", A + "daddr=" + enc("39.8118,-77.2311")],
  ["Google @coords out of range (crafted) — left alone", "https://www.google.com/maps/@999.0,999.0,15z", LEFT],
  ["Waze to=ll out of range (crafted) — left alone", "https://www.waze.com/live-map/directions?to=ll.999.0,999.0", LEFT],

  // ----- Bing Maps -----
  ["Bing share ?q + FORM", "https://www.bing.com/maps?q=Thomas+Jefferson+Memorial&FORM=HDRSC6", A + "q=" + enc("Thomas Jefferson Memorial")],
  ["Bing cp center (encoded tilde) + lvl", "https://www.bing.com/maps?cp=38.7293%7E-77.0861&lvl=16.0&style=r", A + "ll=38.7293,-77.0861"],
  ["Bing q + cp center — sll anchors the search", "https://www.bing.com/maps?q=Washington+Monument&cp=38.8895%7E-77.0353&lvl=17", A + "q=" + enc("Washington Monument") + "&sll=38.8895,-77.0353"],

  // ----- HERE WeGo -----
  ["HERE map center + msg", "https://wego.here.com/?map=36.0160250,-114.7376790,15,normal&msg=Hoover%20Dam", A + "ll=36.016025,-114.737679"],
  ["HERE ?q", "https://wego.here.com/?q=Arlington+National+Cemetery", A + "q=" + enc("Arlington National Cemetery")],
  ["HERE q + map center — sll anchors the search", "https://wego.here.com/?map=38.8977,-77.0365,16,normal&q=White+House", A + "q=" + enc("White House") + "&sll=38.8977,-77.0365"],

  // ----- Google redirect wrappers (Gmail web, Docs) -----
  ["Gmail-wrapped Google Maps link (google.com/url?q=)", "https://www.google.com/url?q=https%3A%2F%2Fmaps.google.com%2F%3Fq%3DGateway%2BArch%2C%2BSt.%2BLouis%2C%2BMO&sa=D&source=docs", A + "q=" + enc("Gateway Arch, St. Louis, MO")],
  ["Wrapped Apple Maps link is lifted out of the redirect", "https://www.google.com/url?q=https%3A%2F%2Fmaps.apple.com%2F%3Fll%3D38.6247%2C-90.1848&sa=D", "https://maps.apple.com/?ll=38.6247,-90.1848"],
  ["Wrapped non-map link — left alone", "https://www.google.com/url?q=https%3A%2F%2Fwww.nps.gov%2Fjeff%2F&sa=D", LEFT],

  // ----- geo: URI (Android intents / some web pages) -----
  ["geo coords + q label", "geo:43.8366,-103.6232?q=Crazy+Horse+Memorial", A + "ll=43.8366,-103.6232"],
  ["geo plain coords", "geo:40.1018,-75.4566", A + "ll=40.1018,-75.4566"],
  ["geo 0,0?q label only", "geo:0,0?q=Plymouth+Rock,+Pilgrim+Memorial+State+Park", A + "q=" + enc("Plymouth Rock, Pilgrim Memorial State Park")],

  // ----- intentionally LEFT untouched -----
  ["Google malformed percent-encoding (must not throw / break the page)", "https://www.google.com/maps/place/100%zz-Main+St", LEFT],
  ["Google multi-stop directions (Apple Maps can't express stops)", "https://www.google.com/maps/dir/Boston,+MA/Hartford,+CT/New+York,+NY/@41.5,-72.7,9z", LEFT],
  ["Apple Maps share (address+ll+q) pass-through", "https://maps.apple.com/?address=1+Lincoln+Memorial+Cir+NW,+Washington,+DC&ll=38.8893,-77.0502&q=Lincoln+Memorial", LEFT],
  ["Google app shortener (not followed)", "https://maps.app.goo.gl/8xQqA6Yz2bExmp", LEFT],
  ["Old goo.gl/maps shortener", "https://goo.gl/maps/Xv9bExmpLE2", LEFT],
  ["NPS directions page (not a map link)", "https://www.nps.gov/stli/planyourvisit/directions.htm", LEFT],
  ["here.com substring trap (atmosphere.com)", "https://atmosphere.com/maps?q=not-here-maps", LEFT],
  ["Waze help-center search (not a map link)", "https://support.waze.com/hc/search?q=account+help", LEFT],
  ["HERE corporate-site search (not a map link)", "https://www.here.com/search?q=careers", LEFT],
];

// --- run ----------------------------------------------------------------
let pass = 0;
const fails = [];
for (const [name, href, expect] of cases) {
  let got;
  try { got = runOn(href); } catch (e) { got = "THREW: " + e.message; }
  const want = expect === LEFT ? href : expect;
  if (got === want) { pass++; }
  else { fails.push({ name, href, want, got }); }
}

console.log(`\nMap Path parser: ${pass}/${cases.length} passed`);
if (fails.length) {
  console.log("\nFAILURES:");
  for (const f of fails) {
    console.log(`  ✗ ${f.name}`);
    console.log(`      link: ${f.href}`);
    console.log(`      want: ${f.want}`);
    console.log(`      got:  ${f.got}`);
  }
  process.exit(1);
} else {
  console.log("All variations covered. ✓\n");
}
