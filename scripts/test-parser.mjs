#!/usr/bin/env node
//
// test-parser.mjs — regression harness for the link parser in
// extension/content.js.
//
// WHY THIS EXISTS
//   content.js is the whole product: it decides whether a map link becomes an
//   Apple Maps link, and its governing rule is "never produce a worse link than
//   the original". Until this file existed, that rule was only ever checked by
//   hand, so a claim like "47/47 passing" could not be reproduced by anyone.
//   Run this after any change to content.js.
//
// HOW IT WORKS
//   content.js is a self-contained IIFE with no exports, and it is shipped as
//   is. Rather than alter it, the harness reads the source, splices a single
//   capture line in just before the IIFE closes, and runs that copy in a vm
//   context with a minimal fake DOM. The parser itself is pure, so the fake DOM
//   only has to be inert enough for the setup path to run.
//
// USAGE
//   node scripts/test-parser.mjs          run all cases
//   node scripts/test-parser.mjs -v       also print passing cases

import { readFileSync } from "node:fs";
import { createContext, runInContext } from "node:vm";
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";

const verbose = process.argv.includes("-v");
const here = dirname(fileURLToPath(import.meta.url));
const contentPath = join(here, "..", "extension", "content.js");
const source = readFileSync(contentPath, "utf8");

// ---- Load the parser out of the IIFE ---------------------------------------

const CLOSE = "})();";
const closeAt = source.lastIndexOf(CLOSE);
if (closeAt === -1) {
    throw new Error(`${contentPath}: could not find the IIFE close ("${CLOSE}")`);
}
const instrumented =
    source.slice(0, closeAt) +
    "  globalThis.__mapPath = { toAppleMaps, labelFallback };\n" +
    source.slice(closeAt);

// Inert DOM. The page the parser thinks it is on matters: relative hrefs
// resolve against location.href.
const sandbox = {
    URL,
    URLSearchParams,
    console,
    location: { href: "https://example.com/page" },
    window: { open() {}, location: { assign() {} } },
    document: {
        documentElement: {},
        addEventListener() {},
        querySelectorAll: () => [],
    },
    MutationObserver: class {
        observe() {}
        disconnect() {}
    },
};
runInContext(instrumented, createContext(sandbox));

const captured = sandbox.__mapPath;
if (!captured?.toAppleMaps) {
    throw new Error("harness could not capture toAppleMaps — did content.js change shape?");
}
const { toAppleMaps, labelFallback } = captured;

// A stand-in for an <a> element, which is all labelFallback touches.
const anchor = (href, text) => ({ href, textContent: text });

// ---- Cases -----------------------------------------------------------------
// `expect` asserts the exact rewritten URL. `null` asserts the link is left
// untouched — the never-worse default, and the more important half of the
// contract.

const cases = [
    // --- The never-worse rule: these must all be left alone ---
    ["already Apple Maps", "https://maps.apple.com/?ll=37.7749,-122.4194", null],
    ["Apple Maps place link", "https://maps.apple.com/place?place-id=I123", null],
    ["opaque shortener (goo.gl)", "https://goo.gl/maps/abc123", null],
    ["opaque shortener (maps.app)", "https://maps.app.goo.gl/abc123", null],
    ["plain non-map link", "https://example.com/about", null],
    ["javascript: href", "javascript:alert(1)", null],
    ["empty href", "", null],
    ["substring host trap (atmosphere.com)", "https://atmosphere.com/?map=48.85,2.29", null],
    ["substring host trap (notgoogle.com)", "https://notgoogle.com/maps?q=48.85,2.29", null],

    // --- geo: URIs ---
    ["geo: coordinates", "geo:37.7749,-122.4194", "https://maps.apple.com/?ll=37.7749,-122.4194"],
    ["geo: named place (0,0)", "geo:0,0?q=Eiffel+Tower", "https://maps.apple.com/?q=Eiffel%20Tower"],
    [
        "geo: coords keep their label",
        "geo:48.8584,2.2945?q=Eiffel+Tower",
        "https://maps.apple.com/?ll=48.8584,2.2945&q=Eiffel%20Tower",
    ],

    // --- Google ---
    [
        "Google @lat,lng,z",
        "https://www.google.com/maps/@37.7749,-122.4194,15z",
        "https://maps.apple.com/?ll=37.7749,-122.4194&z=15",
    ],
    [
        "Google redirect wrapper unwraps locally",
        "https://www.google.com/url?q=https://www.google.com/maps/@37.7749,-122.4194,15z",
        "https://maps.apple.com/?ll=37.7749,-122.4194&z=15",
    ],
    [
        "Google redirect wrapping a non-map link",
        "https://www.google.com/url?q=https://example.com/about",
        null,
    ],

    // --- Waze / Bing / HERE ---
    [
        "Waze ll + zoom",
        "https://www.waze.com/ul?ll=40.7128,-74.0060&zoom=12",
        "https://maps.apple.com/?ll=40.7128,-74.006&z=12",
    ],
    [
        "Bing cp + lvl",
        "https://www.bing.com/maps?cp=40.7128~-74.0060&lvl=12",
        "https://maps.apple.com/?ll=40.7128,-74.006&z=12",
    ],

    // --- Zoom hygiene ---
    ["out-of-range zoom is dropped", "https://www.google.com/maps/@37.7749,-122.4194,99z", "https://maps.apple.com/?ll=37.7749,-122.4194"],

    // --- Coordinate sanity ---
    // 999,999 matches the coordinate shape but fails the range check, so it is
    // not treated as a location. It stays a text query — which is what the
    // original Google link did too, so the never-worse rule still holds.
    [
        "out-of-range coords degrade to a text query",
        "https://www.google.com/maps?q=999,999",
        "https://maps.apple.com/?q=999%2C999",
    ],
    ["valid coords at the range edge", "https://www.google.com/maps?q=90,180", "https://maps.apple.com/?ll=90,180"],
];

// labelFallback cases: an opaque Google place link plus the link's visible text.
// Only a genuine street address may be promoted; generic labels must not be.
const labelCases = [
    [
        "address label on an opaque place link",
        anchor("https://www.google.com/maps/place/data=!4m2!3m1!1s0x0:0x0", "1600 Pennsylvania Ave NW, Washington, DC 20500"),
        "https://maps.apple.com/?q=1600%20Pennsylvania%20Ave%20NW%2C%20Washington%2C%20DC%2020500",
    ],
    ["generic label 'Directions'", anchor("https://www.google.com/maps/place/data=!4m2!3m1!1s0x0:0x0", "Directions"), null],
    ["review-count label", anchor("https://www.google.com/maps/place/data=!4m2!3m1!1s0x0:0x0", "1,536 Reviews"), null],
    ["business-name-only label", anchor("https://www.google.com/maps/place/data=!4m2!3m1!1s0x0:0x0", "Joe's Coffee House"), null],
    ["address label but link is not opaque", anchor("https://example.com/contact", "1600 Pennsylvania Ave NW, Washington, DC 20500"), null],
];

// ---- Run -------------------------------------------------------------------

let pass = 0;
const failures = [];

const check = (name, actual, expected) => {
    if (actual === expected) {
        pass += 1;
        if (verbose) console.log(`  ok   ${name}`);
    } else {
        failures.push({ name, expected, actual });
    }
};

for (const [name, href, expected] of cases) {
    let actual;
    try {
        actual = toAppleMaps(href);
    } catch (err) {
        // toAppleMaps swallows its own errors by contract; reaching here is a bug.
        failures.push({ name, expected, actual: `THREW: ${err.message}` });
        continue;
    }
    check(name, actual, expected);
}

for (const [name, a, expected] of labelCases) {
    let actual;
    try {
        actual = labelFallback(a);
    } catch (err) {
        failures.push({ name, expected, actual: `THREW: ${err.message}` });
        continue;
    }
    check(name, actual, expected);
}

const total = cases.length + labelCases.length;

if (failures.length) {
    console.log(`\n${failures.length} of ${total} failed:\n`);
    for (const f of failures) {
        console.log(`  ✗ ${f.name}`);
        console.log(`      expected: ${JSON.stringify(f.expected)}`);
        console.log(`      actual:   ${JSON.stringify(f.actual)}`);
    }
    console.log("");
    process.exit(1);
}

console.log(`Parser harness: ${pass}/${total} passing.`);
