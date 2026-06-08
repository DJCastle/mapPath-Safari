#!/usr/bin/env bash
# sync-container-app.sh — apply the tracked container-app customizations to the
# (gitignored) Xcode tree. Run after a fresh `safari-web-extension-converter`
# generation, or any time the canonical files change.
#
# Canonical sources:
#   container-app/Resources/         — Main.html, Script.js, Style.css
#   app-icon/MapPath.icon/           — single-layer Icon Composer source
#
# Targets in the Xcode tree:
#   Map Path/Shared (App)/Resources/
#   Map Path/Shared (App)/Assets.xcassets/AppIcon.icon/
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

# Hero icon shown in Main.html — resize from the .icon source to 512x512.
run sips -z 512 512 "$ICON_SRC/Assets/icon.png" --out "$XCODE_RESOURCES/Icon.png"

# Asset catalog: wipe legacy AppIcon formats; copy .icon source in as AppIcon.icon.
run rm -rf "$XCODE_CATALOG/AppIcon.icon" "$XCODE_CATALOG/AppIcon.appiconset"
run cp -R "$ICON_SRC" "$XCODE_CATALOG/AppIcon.icon"

if [[ "$APPLY" -eq 1 ]]; then
    echo ""
    echo "✓ Container-app customizations applied."
    echo "  Build & run the macOS scheme in Xcode to verify."
else
    echo ""
    echo "Dry run only. Re-run with --apply to make changes."
fi
