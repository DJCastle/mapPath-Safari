#!/usr/bin/env bash
# sync-container-app.sh — apply the tracked container-app customizations to the
# (gitignored) Xcode tree. Run after a fresh `safari-web-extension-converter`
# generation, or any time the canonical files change.
#
# Canonical sources:
#   app-icon/MapPath.icon/           — single-layer Icon Composer source
#   PrivacyInfo.xcprivacy            — App Store privacy manifest (shared by both targets)
#
# Targets in the Xcode tree:
#   Map Path/Shared (App)/Resources/
#   Map Path/Shared (App)/Assets.xcassets/AppIcon.icon/
#   Map Path/Shared (App)/PrivacyInfo.xcprivacy
#   Map Path/Shared (Extension)/PrivacyInfo.xcprivacy
#
# Defaults to dry-run. Use --apply to actually write.

set -euo pipefail

APPLY=0
for arg in "$@"; do
    case "$arg" in
        --apply) APPLY=1 ;;
        -h|--help)
            cat <<'USAGE'
Usage: scripts/sync-container-app.sh [--apply]

Applies tracked container-app customizations to the gitignored Xcode tree.

Without --apply, runs in dry-run mode and prints the commands that would
execute. Pass --apply to actually copy files.
USAGE
            exit 0
            ;;
        *)
            echo "Unknown argument: $arg" >&2
            echo "See --help for usage." >&2
            exit 1
            ;;
    esac
done

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
XCODE_APP_DIR="$REPO_ROOT/Map Path/Shared (App)"
XCODE_RESOURCES="$XCODE_APP_DIR/Resources"
XCODE_CATALOG="$XCODE_APP_DIR/Assets.xcassets"
ICON_SRC="$REPO_ROOT/app-icon/MapPath.icon"
CONTAINER_SRC="$REPO_ROOT/container-app"
PRIVACY_SRC="$REPO_ROOT/PrivacyInfo.xcprivacy"

# Old releases of this script also wrote a copy at Shared (Extension)/
# PrivacyInfo.xcprivacy. The Xcode project now references the Shared (App)
# copy from all 4 targets, so the extension-side file is orphaned. Clear
# it on each apply to keep the tree clean.
ORPHAN_PRIVACY="$REPO_ROOT/Map Path/Shared (Extension)/PrivacyInfo.xcprivacy"

if [[ ! -d "$XCODE_APP_DIR" ]]; then
    echo "Error: Xcode container app dir not found at:" >&2
    echo "  $XCODE_APP_DIR" >&2
    echo "Run 'xcrun safari-web-extension-converter extension/' first." >&2
    exit 1
fi

if [[ ! -d "$CONTAINER_SRC" || ! -d "$ICON_SRC" ]]; then
    echo "Error: canonical sources missing. Expected:" >&2
    echo "  $CONTAINER_SRC" >&2
    echo "  $ICON_SRC" >&2
    exit 1
fi

# The canonical icon source became a 4-layer Icon Composer file on
# 2026-07-13; the flat Assets/icon.png that several steps consume no longer
# exists. Until the v1.1 icon-pipeline rework lands (flat companion export +
# .icon adoption), skip icon-derived steps instead of erroring.
FLAT_ICON="$ICON_SRC/Assets/icon.png"
HAVE_FLAT_ICON=0
[[ -f "$FLAT_ICON" ]] && HAVE_FLAT_ICON=1
if [[ "$HAVE_FLAT_ICON" -eq 0 ]]; then
    echo "NOTE: $FLAT_ICON missing (layered .icon source) — skipping" >&2
    echo "      LargeIcon/AppIcon generation; existing generated PNGs in the" >&2
    echo "      Xcode tree are left as-is. See CLAUDE-LOG (v1.1 icon rework)." >&2
fi

run() {
    if [[ "$APPLY" -eq 1 ]]; then
        "$@"
    else
        printf 'DRY-RUN: '
        printf '%q ' "$@"
        printf '\n'
    fi
}



# Hardened ViewController.swift (force-unwrap cleanup + os_log on error paths).
run cp "$CONTAINER_SRC/ViewController.swift" "$XCODE_APP_DIR/ViewController.swift"

# Native extension handler — the address finder's on-device DataDetector side
# (canonical since 1.1; before that it was the converter's untracked echo stub).
run cp "$CONTAINER_SRC/SafariWebExtensionHandler.swift" \
       "$REPO_ROOT/Map Path/Shared (Extension)/SafariWebExtensionHandler.swift"

# macOS AppDelegate with explicit secure-coding opt-in for restorable state.
run cp "$CONTAINER_SRC/AppDelegate-macOS.swift" "$REPO_ROOT/Map Path/macOS (App)/AppDelegate.swift"

# iOS LaunchScreen storyboard — cream paper background + auto-layout centering
# (the converter template ships a fixed-frame layout on a white system
# background, which leaves the icon off-center on iPhone/iPad sizes outside
# the iPhone 11 default).
run cp "$CONTAINER_SRC/LaunchScreen.storyboard" \
       "$REPO_ROOT/Map Path/iOS (App)/Base.lproj/LaunchScreen.storyboard"

# Main storyboards — the onboarding UI is now SwiftUI hosted in ViewController
# (see ViewController.swift). These storyboards keep only the app/window/scene
# scaffold; the converter template's WKWebView and its `webView` outlet are
# removed (the controller hosts a SwiftUI view instead), and the macOS window
# is made resizable so the UI flexes to the window.
run cp "$CONTAINER_SRC/iOS-Main.storyboard" \
       "$REPO_ROOT/Map Path/iOS (App)/Base.lproj/Main.storyboard"
run cp "$CONTAINER_SRC/macOS-Main.storyboard" \
       "$REPO_ROOT/Map Path/macOS (App)/Base.lproj/Main.storyboard"

# LaunchBackground colorset — the named color the launch storyboard references
# for its background (light cream paper / dark slate to mirror the onboarding).
run mkdir -p "$XCODE_CATALOG/LaunchBackground.colorset"
run cp "$CONTAINER_SRC/Assets.xcassets/LaunchBackground.colorset/Contents.json" \
       "$XCODE_CATALOG/LaunchBackground.colorset/Contents.json"

# LargeIcon imageset — the image the launch storyboard renders centered.
# Generated via scripts/shadow-icon.swift so the icon arrives with a soft
# drop shadow baked in (depth on the launch screen). Output is transparent;
# the cream/map background behind it shows through around the edges.
run mkdir -p "$XCODE_CATALOG/LargeIcon.imageset"
run cp "$CONTAINER_SRC/Assets.xcassets/LargeIcon.imageset/Contents.json" \
       "$XCODE_CATALOG/LargeIcon.imageset/Contents.json"
if [[ "$HAVE_FLAT_ICON" -eq 1 ]]; then
run swift "$REPO_ROOT/scripts/shadow-icon.swift" \
        "$ICON_SRC/Assets/icon.png" \
        "$XCODE_CATALOG/LargeIcon.imageset/LargeIcon@1x.png" \
        160
run swift "$REPO_ROOT/scripts/shadow-icon.swift" \
        "$ICON_SRC/Assets/icon.png" \
        "$XCODE_CATALOG/LargeIcon.imageset/LargeIcon@2x.png" \
        320
run swift "$REPO_ROOT/scripts/shadow-icon.swift" \
        "$ICON_SRC/Assets/icon.png" \
        "$XCODE_CATALOG/LargeIcon.imageset/LargeIcon@3x.png" \
        480
fi
# Remove the converter template's stale icon-256.png to avoid mixing.
run rm -f "$XCODE_CATALOG/LargeIcon.imageset/icon-256.png"

# LaunchMapBackground imageset — the abstract street-network image rendered
# edge-to-edge behind the LargeIcon. iPhone @3x and iPad @2x crops live in
# the canonical container-app source (pre-cropped from a licensed Adobe
# Stock asset; the raw source is not redistributed). Just mirror them.
run mkdir -p "$XCODE_CATALOG/LaunchMapBackground.imageset"
run cp "$CONTAINER_SRC/Assets.xcassets/LaunchMapBackground.imageset/Contents.json" \
       "$XCODE_CATALOG/LaunchMapBackground.imageset/Contents.json"
run cp "$CONTAINER_SRC/Assets.xcassets/LaunchMapBackground.imageset/LaunchBg-iphone@3x.png" \
       "$XCODE_CATALOG/LaunchMapBackground.imageset/LaunchBg-iphone@3x.png"
run cp "$CONTAINER_SRC/Assets.xcassets/LaunchMapBackground.imageset/LaunchBg-ipad@2x.png" \
       "$XCODE_CATALOG/LaunchMapBackground.imageset/LaunchBg-ipad@2x.png"

# SetupScreenshot imageset — annotated Settings screenshots (arrows on the
# exact switches) shown on the Set-up steps screen. Device-idiom variants:
# iPhone, iPad, and Mac each get their own platform's capture. Same source
# images as the website support page's illustrated guide.
run mkdir -p "$XCODE_CATALOG/SetupScreenshot.imageset"
for f in Contents.json setup-iphone@2x.png setup-ipad@2x.png setup-mac@2x.png; do
  run cp "$CONTAINER_SRC/Assets.xcassets/SetupScreenshot.imageset/$f" \
         "$XCODE_CATALOG/SetupScreenshot.imageset/$f"
done


# Asset catalog: build AppIcon.appiconset from the .icon source.
# Why the legacy .appiconset format and not the newer .icon-as-asset?
# The Mac App Store validator (90236) requires a 1024x1024 entry in AppIcon.icns
# that the .icon-only pipeline doesn't reliably produce on archive. The
# .appiconset with explicit PNGs at all sizes always passes.
SRC_PNG="$ICON_SRC/Assets/icon.png"
APPICONSET="$XCODE_CATALOG/AppIcon.appiconset"
if [[ "$HAVE_FLAT_ICON" -eq 1 ]]; then
run rm -rf "$XCODE_CATALOG/AppIcon.icon" "$APPICONSET"
run mkdir -p "$APPICONSET"

# Mac sizes (16, 32, 128, 256, 512 pt at 1x and 2x) + iOS universal 1024.
# All app-icon PNGs MUST be opaque — the Mac App Store validator (error
# 90717) rejects any large app icon with an alpha channel. Use the Swift
# flattener to composite the transparent source onto a solid white
# background before resizing. Toolbar icons under extension/icons/ stay
# transparent (different render context — Safari toolbar).
FLATTEN="$REPO_ROOT/scripts/flatten-icon.swift"
run swift "$FLATTEN" "$SRC_PNG" "$APPICONSET/mac-icon-16@1x.png"          16
run swift "$FLATTEN" "$SRC_PNG" "$APPICONSET/mac-icon-16@2x.png"          32
run swift "$FLATTEN" "$SRC_PNG" "$APPICONSET/mac-icon-32@1x.png"          32
run swift "$FLATTEN" "$SRC_PNG" "$APPICONSET/mac-icon-32@2x.png"          64
run swift "$FLATTEN" "$SRC_PNG" "$APPICONSET/mac-icon-128@1x.png"        128
run swift "$FLATTEN" "$SRC_PNG" "$APPICONSET/mac-icon-128@2x.png"        256
run swift "$FLATTEN" "$SRC_PNG" "$APPICONSET/mac-icon-256@1x.png"        256
run swift "$FLATTEN" "$SRC_PNG" "$APPICONSET/mac-icon-256@2x.png"        512
run swift "$FLATTEN" "$SRC_PNG" "$APPICONSET/mac-icon-512@1x.png"        512
run swift "$FLATTEN" "$SRC_PNG" "$APPICONSET/mac-icon-512@2x.png"       1024
run swift "$FLATTEN" "$SRC_PNG" "$APPICONSET/universal-icon-1024@1x.png" 1024

# Contents.json maps each PNG to its size/idiom/scale slot.
run cp "$CONTAINER_SRC/Assets.xcassets/AppIcon.appiconset/Contents.json" \
       "$APPICONSET/Contents.json"
fi

# Privacy manifest: one canonical copy in Shared (App). The Xcode project
# references this single PBXFileReference from all 4 targets' Copy Bundle
# Resources phases, so it ships inside both the App and the Extension
# bundles without needing a separate file under Shared (Extension).
run cp "$PRIVACY_SRC" "$XCODE_APP_DIR/PrivacyInfo.xcprivacy"
if [[ -f "$ORPHAN_PRIVACY" ]]; then
    run rm "$ORPHAN_PRIVACY"
fi

# Patch macOS Info.plist with LSApplicationCategoryType (required by Mac App
# Store — error 90242 without it). Idempotent: skips if already present.
INFO_PLIST_MAC="$REPO_ROOT/Map Path/macOS (App)/Info.plist"
if [[ -f "$INFO_PLIST_MAC" ]]; then
    if ! /usr/libexec/PlistBuddy -c "Print :LSApplicationCategoryType" "$INFO_PLIST_MAC" >/dev/null 2>&1; then
        run /usr/libexec/PlistBuddy \
            -c "Add :LSApplicationCategoryType string public.app-category.utilities" \
            "$INFO_PLIST_MAC"
    fi
fi

# ITSAppUsesNonExemptEncryption=NO on both app Info.plists — the app uses
# only exempt encryption (HTTPS), and declaring it skips App Store Connect's
# export-compliance question on every upload. Idempotent.
INFO_PLIST_IOS="$REPO_ROOT/Map Path/iOS (App)/Info.plist"
for plist in "$INFO_PLIST_MAC" "$INFO_PLIST_IOS"; do
    if [[ -f "$plist" ]] && \
       ! /usr/libexec/PlistBuddy -c "Print :ITSAppUsesNonExemptEncryption" "$plist" >/dev/null 2>&1; then
        run /usr/libexec/PlistBuddy \
            -c "Add :ITSAppUsesNonExemptEncryption bool false" "$plist"
    fi
done

if [[ "$APPLY" -eq 1 ]]; then
    echo ""
    echo "✓ Container-app customizations applied."
    echo "  Build & run the macOS scheme in Xcode to verify."
else
    echo ""
    echo "Dry run only. Re-run with --apply to make changes."
fi
