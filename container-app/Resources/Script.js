// Called from ViewController.swift after the page loads. Sets platform/state
// classes on <body> so the CSS shows the right onboarding section.
function show(platform, enabled) {
    document.body.classList.add(`platform-${platform}`);

    if (typeof enabled === "boolean") {
        document.body.classList.toggle("state-on", enabled);
        document.body.classList.toggle("state-off", !enabled);
    } else {
        document.body.classList.remove("state-on");
        document.body.classList.remove("state-off");
    }
}

function openPreferences() {
    webkit.messageHandlers.controller.postMessage("open-preferences");
}

const openBtn = document.querySelector("button.open-preferences");
if (openBtn) {
    openBtn.addEventListener("click", openPreferences);
}
