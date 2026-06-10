#!/usr/bin/env bash
# sync-container-app.sh — apply the tracked container-app customizations to the
# (gitignored) Xcode tree. Run after a fresh `safari-web-extension-converter`
# generation, or any time the canonical files change.
#
# Canonical sources:
#   container-app/Resources/         — Main.html, Script.js, Style.css
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

run() {
    if [[ "$APPLY" -eq 1 ]]; then
        "$@"
    else
        printf 'DRY-RUN: '
        printf '%q ' "$@"
        printf '\n'
    fi
}

mkdir -p "$XCODE_RESOURCES/Base.lproj"

# Resources: Main.html (localized), Script.js, Style.css.
run cp "$CONTAINER_SRC/Resources/Base.lproj/Main.html" \
       "$XCODE_RESOURCES/Base.lproj/Main.html"
run cp "$CONTAINER_SRC/Resources/Script.js" "$XCODE_RESOURCES/Script.js"
run cp "$CONTAINER_SRC/Resources/Style.css" "$XCODE_RESOURCES/Style.css"

# Hardened ViewController.swift (force-unwrap cleanup + os_log on error paths).
run cp "$CONTAINER_SRC/ViewController.swift" "$XCODE_APP_DIR/ViewController.swift"

# macOS AppDelegate with explicit secure-coding opt-in for restorable state.
run cp "$CONTAINER_SRC/AppDelegate-macOS.swift" "$REPO_ROOT/Map Path/macOS (App)/AppDelegate.swift"

# Hero icon shown in Main.html — resize from the .icon source to 512x512.
run sips -z 512 512 "$ICON_SRC/Assets/icon.png" --out "$XCODE_RESOURCES/Icon.png"

# Asset catalog: build AppIcon.appiconset from the .icon source.
# Why the legacy .appiconset format and not the newer .icon-as-asset?
# The Mac App Store validator (90236) requires a 1024x1024 entry in AppIcon.icns
# that the .icon-only pipeline doesn't reliably produce on archive. The
# .appiconset with explicit PNGs at all sizes always passes.
SRC_PNG="$ICON_SRC/Assets/icon.png"
APPICONSET="$XCODE_CATALOG/AppIcon.appiconset"
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

if [[ "$APPLY" -eq 1 ]]; then
    echo ""
    echo "✓ Container-app customizations applied."
    echo "  Build & run the macOS scheme in Xcode to verify."
else
    echo ""
    echo "Dry run only. Re-run with --apply to make changes."
fi
