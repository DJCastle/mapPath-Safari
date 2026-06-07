// Map Path popup — static about panel. Reads the version from the manifest so
// the displayed number never drifts from the build. No storage, no messaging.
(() => {
  "use strict";
  try {
    const api = typeof browser !== "undefined" ? browser : chrome;
    const v = api?.runtime?.getManifest?.()?.version;
    if (v) {
      const el = document.getElementById("version");
      if (el) el.textContent = v;
    }
  } catch {
    /* leave the hardcoded fallback in the markup */
  }
})();
