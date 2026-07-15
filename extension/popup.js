// Map Path popup — the address finder plus the about card.
//
// The scan is user-initiated: opening this popup is what triggers it. The
// content script hands over the page's visible text, the native handler runs
// Apple's on-device data detectors, and the text is discarded. No storage,
// no network, no scanning while you browse.
(() => {
  "use strict";
  const api = typeof browser !== "undefined" ? browser : chrome;

  const headerEl = document.getElementById("finder-header");
  const listEl = document.getElementById("finder-list");
  const moreBtn = document.getElementById("finder-more");
  const VISIBLE = 10;

  try {
    const v = api?.runtime?.getManifest?.()?.version;
    if (v) document.getElementById("version").textContent = v;
  } catch {
    /* keep the hardcoded fallback */
  }

  function mapsURL(addr) {
    // Prefer the structured pieces when present — a precise address= query —
    // and fall back to the full matched string.
    const structured = [addr.street, addr.city, addr.state, addr.zip, addr.country]
      .filter(Boolean)
      .join(", ");
    return (
      "https://maps.apple.com/?address=" + encodeURIComponent(structured || addr.full)
    );
  }

  function render(addresses) {
    if (!addresses.length) {
      headerEl.textContent = "No addresses found on this page";
      return;
    }
    headerEl.textContent =
      addresses.length === 1
        ? "1 potential address on this page"
        : addresses.length + " potential addresses on this page";

    addresses.forEach((addr, i) => {
      const li = document.createElement("li");
      if (i >= VISIBLE) li.hidden = true;
      const btn = document.createElement("button");
      btn.type = "button";
      btn.className = "addr";
      btn.textContent = addr.full;
      btn.setAttribute("aria-label", "Open " + addr.full + " in Apple Maps");
      btn.addEventListener("click", () => {
        api.tabs.create({ url: mapsURL(addr) });
        window.close();
      });
      li.appendChild(btn);
      listEl.appendChild(li);
    });

    if (addresses.length > VISIBLE) {
      moreBtn.hidden = false;
      moreBtn.textContent = "Show " + (addresses.length - VISIBLE) + " more";
      moreBtn.addEventListener(
        "click",
        () => {
          for (const li of listEl.children) li.hidden = false;
          moreBtn.hidden = true;
        },
        { once: true }
      );
    }
  }

  async function scan() {
    try {
      const [tab] = await api.tabs.query({ active: true, currentWindow: true });
      if (!tab || tab.id == null) throw new Error("no active tab");
      const page = await api.tabs.sendMessage(tab.id, { type: "mappath.collectText" });
      // Safari ignores the application id argument; Apple's samples pass a
      // placeholder string exactly like this.
      const reply = await api.runtime.sendNativeMessage("application.id", {
        command: "findAddresses",
        text: (page && page.text) || "",
      });
      if (!reply || reply.ok !== true) throw new Error("native scan failed");
      render(reply.addresses || []);
    } catch {
      // System pages, the start page, and anywhere the content script can't
      // run all land here. Honest, quiet, done.
      headerEl.textContent = "Can’t look for addresses on this page";
    }
  }

  scan();
})();
