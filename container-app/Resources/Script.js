// Called from ViewController.swift after the page loads. Sets platform/state
// classes on <body> so the CSS shows the right onboarding section.
//
// Args:
//   platform — "ios" or "mac"
//   enabled  — boolean, null (don't change), or undefined (clear). Drives the
//              state-on / state-off visibility on the macOS card.
//   variant  — "modern" (iOS 17+) or "legacy" (iOS 15-16); controls which
//              Settings menu path is shown in step 1.
//   verify   — true on return visits, false on first open. Adds state-verify
//              to <body>, which CSS uses to swap the full onboarding (CTA +
//              steps cards) for the compact verification view.
function show(platform, enabled, variant, verify) {
    if (platform) document.body.classList.add(`platform-${platform}`);

    if (typeof enabled === "boolean") {
        document.body.classList.toggle("state-on", enabled);
        document.body.classList.toggle("state-off", !enabled);
    } else if (enabled !== null && typeof enabled !== "undefined") {
        // Explicit reset (anything other than boolean or null clears).
        document.body.classList.remove("state-on");
        document.body.classList.remove("state-off");
    }
    // null = don't touch state-on/state-off (lets the SF state callback
    // update the macOS status without the initial show() call wiping it).

    if (variant) {
        document.body.classList.add(`ios-${variant}`);
    }

    if (verify === true) {
        document.body.classList.add("state-verify");
    } else if (verify === false) {
        document.body.classList.remove("state-verify");
    }
}

function postToController(message) {
    if (window.webkit && webkit.messageHandlers && webkit.messageHandlers.controller) {
        webkit.messageHandlers.controller.postMessage(message);
    }
}

// macOS "Quit & Open Safari Extensions Settings…" buttons.
// Both the first-open onboarding card AND the verification view have a button
// with this class. Use querySelectorAll + forEach so both get the handler;
// querySelector alone would only wire up the first one and the verify-view
// button would silently do nothing.
document.querySelectorAll("button.open-preferences").forEach((btn) => {
    btn.addEventListener("click", () => postToController("open-preferences"));
});

// Data-action handlers. Match any element with [data-action], not just
// <button>, so the "Show me the setup steps again" <p class="text-link">
// element in the verification view also gets a click handler.
document.querySelectorAll("[data-action]").forEach((el) => {
    el.addEventListener("click", () => {
        const action = el.getAttribute("data-action");
        switch (action) {
            case "open-ios-settings":
                postToController("open-ios-settings");
                break;
            case "open-test-page":
                postToController("open-test-page");
                break;
            case "dismiss-onboarding":
                document.body.classList.add("state-dismissed");
                break;
            case "show-steps-again":
                document.body.classList.remove("state-dismissed");
                break;
            case "show-setup-steps":
                // From the verification view, reveal the full onboarding
                // (CTA + steps) one more time. Does not change UserDefaults
                // — next launch returns to the verification view.
                document.body.classList.remove("state-verify");
                break;
        }
    });
});
