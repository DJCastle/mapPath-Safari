// Called from ViewController.swift after the page loads. Sets platform/state
// classes on <body> so the CSS shows the right onboarding section.
// On iOS the third arg ("modern" for iOS 17+ or "legacy" for older) controls
// which Settings menu path is shown in step 1.
function show(platform, enabled, variant) {
    document.body.classList.add(`platform-${platform}`);

    if (typeof enabled === "boolean") {
        document.body.classList.toggle("state-on", enabled);
        document.body.classList.toggle("state-off", !enabled);
    } else {
        document.body.classList.remove("state-on");
        document.body.classList.remove("state-off");
    }

    if (variant) {
        document.body.classList.add(`ios-${variant}`);
    }
}

function postToController(message) {
    if (window.webkit && webkit.messageHandlers && webkit.messageHandlers.controller) {
        webkit.messageHandlers.controller.postMessage(message);
    }
}

// macOS "Quit & Open Safari Extensions Settings…" button.
const openBtn = document.querySelector("button.open-preferences");
if (openBtn) {
    openBtn.addEventListener("click", () => postToController("open-preferences"));
}

// Data-action buttons (iOS CTA + dismissed-view actions).
document.querySelectorAll("button[data-action]").forEach((btn) => {
    btn.addEventListener("click", () => {
        const action = btn.getAttribute("data-action");
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
        }
    });
});
