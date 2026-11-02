#!/usr/bin/env bash
# release-asc.sh — drive a Map Path release through App Store Connect from
# the command line: upload the archives, create the versions, upload every
# screenshot set (iPhone, iPad, iPhone Duo, Mac), set What's New, attach
# the build, and submit for review.
#
#   scripts/release-asc.sh plan                 # read-only: what exists, what would change
#   scripts/release-asc.sh upload-builds --apply  # export + upload today's Map Path archives
#   scripts/release-asc.sh versions --apply       # create 1.2.2 on iOS and macOS if missing
#   scripts/release-asc.sh screenshots --apply    # replace every slot from screenshots/
#   scripts/release-asc.sh whats-new --apply      # set the release notes on both platforms
#   scripts/release-asc.sh attach-build --apply   # attach the processed build to each version
#   scripts/release-asc.sh submit --apply         # submit both platforms for review
#
# Every subcommand is a dry run without --apply: it prints what it found and
# what it would send, and changes nothing. Order of work mirrors the web
# flow; each step checks the previous one's result rather than assuming it.
#
# The App Store Connect key is read only by devConfig/bin/asc-api and by
# xcodebuild; this script never prints it. Screenshot bytes go by HTTPS PUT
# to the pre-signed apple.com URLs Apple returns, nothing else. The version,
# build number and copy come from the repo (manifest.json, CHANGELOG.md),
# so the listing cannot drift from what was built.
set -euo pipefail

ROOT="/Users/doncastle/Developer/Projects/mapPath-Safari"
ASC="/Users/doncastle/Developer/devConfig/bin/asc-api"
ASC_DIR="/Users/doncastle/.private/asc"
PY="/usr/bin/python3"
APP_ID="6777889296"                       # Map Path: Open in Apple Maps
BUNDLE_ID="com.doncastle.mappath"
SHOTS="$ROOT/screenshots"
ARCHIVES="/Users/doncastle/Library/Developer/Xcode/Archives"
WHATS_NEW="$ROOT/work/whats-new.txt"

# Which framed files fill which App Store Connect slot. One set per platform
# localization; the Duo slot takes the closed set first, then the open set.
IOS_SLOTS=(
  "APP_IPHONE_67|iphone-1 iphone-2 iphone-3 iphone-4 iphone-5 iphone-6"
  "APP_IPAD_PRO_3GEN_129|ipad-1 ipad-2 ipad-3 ipad-4 ipad-5 ipad-6"
  "APP_IPHONE_DUO|duo-1 duo-2 duo-3 duo-4 duo-5 duo-6 duo-7 duo-8 duo-9 duo-10"
)
MAC_SLOTS=(
  "APP_DESKTOP|macos-1 macos-2 macos-3 macos-4 macos-5"
)

CMD="${1:-plan}"; shift || true
APPLY=0
for a in "$@"; do [[ "$a" == "--apply" ]] && APPLY=1 || { echo "unknown argument: $a" >&2; exit 64; }; done

say()  { printf '%s\n' "$*"; }
die()  { echo "release-asc: $*" >&2; exit 1; }
json() { "$PY" -I -c "import json,sys; d=json.load(sys.stdin); $1"; }
WORK=$(mktemp -d); trap 'rm -rf "$WORK"' EXIT

VERSION=$("$PY" -I -c 'import json,sys; print(json.load(open(sys.argv[1]))["version"])' "$ROOT/extension/manifest.json")
BUILD=$(grep -m1 -oE 'CURRENT_PROJECT_VERSION = [0-9]+' "$ROOT/Map Path/Map Path.xcodeproj/project.pbxproj" | grep -oE '[0-9]+$')
[[ -n "$VERSION" && -n "$BUILD" ]] || die "could not read version/build from the repo"
say "Map Path $VERSION (build $BUILD) — $CMD $([[ $APPLY -eq 1 ]] && echo APPLY || echo 'dry run')"

# ---------------------------------------------------------------- helpers

# version_id <IOS|MAC_OS> → id of the $VERSION entry for that platform, or ""
version_id() {
  "$ASC" GET "/v1/apps/$APP_ID/appStoreVersions?filter[platform]=$1&filter[versionString]=$VERSION&fields[appStoreVersions]=versionString,appVersionState" 2>/dev/null \
    | json 'print(d["data"][0]["id"] if d["data"] else "")'
}
version_state() {
  "$ASC" GET "/v1/appStoreVersions/$1?fields[appStoreVersions]=appVersionState" 2>/dev/null | json 'print(d["data"]["attributes"]["appVersionState"])'
}
# localization_id <versionId> → the en-US localization id
localization_id() {
  "$ASC" GET "/v1/appStoreVersions/$1/appStoreVersionLocalizations?fields[appStoreVersionLocalizations]=locale" 2>/dev/null \
    | json 'print(next((l["id"] for l in d["data"] if l["attributes"]["locale"]=="en-US"), d["data"][0]["id"] if d["data"] else ""))'
}
post_json() { # post_json <path> <json-string> → response on stdout (dry run prints and returns "")
  printf '%s' "$2" >"$WORK/body.json"
  if [[ $APPLY -eq 1 ]]; then "$ASC" POST "$1" "$WORK/body.json" --apply 2>/dev/null
  else say "   would POST $1 $(cat "$WORK/body.json")"; fi
}
patch_json() {
  printf '%s' "$2" >"$WORK/body.json"
  if [[ $APPLY -eq 1 ]]; then "$ASC" PATCH "$1" "$WORK/body.json" --apply 2>/dev/null >/dev/null
  else say "   would PATCH $1 $(cat "$WORK/body.json" | cut -c1-160)"; fi
}

# ---------------------------------------------------------------- upload-builds

find_archives() { # prints "<platform>|<path>" for every Map Path archive with this build number
  find "$ARCHIVES" -maxdepth 2 -name "*.xcarchive" -newermt "-14 days" 2>/dev/null | while read -r a; do
    bid=$("$PY" -I -c 'import plistlib,sys; p=plistlib.load(open(sys.argv[1],"rb"))["ApplicationProperties"]; print(p["CFBundleIdentifier"], p["CFBundleVersion"], p["CFBundleShortVersionString"])' "$a/Info.plist" 2>/dev/null) || continue
    read -r ident ver short <<<"$bid"
    [[ "$ident" == "$BUNDLE_ID" && "$ver" == "$BUILD" && "$short" == "$VERSION" ]] || continue
    if [[ -d "$a/Products/Applications" && -e "$a/Products/Applications/Map Path.app/Contents/MacOS" ]]; then echo "macOS|$a"; else echo "iOS|$a"; fi
  done
}

cmd_upload_builds() {
  [[ -r "$ASC_DIR/config" ]] || die "no $ASC_DIR/config"
  # shellcheck disable=SC1090
  source "$ASC_DIR/config"
  local key="$ASC_DIR/AuthKey_${KEY_ID}.p8"; [[ -r "$key" ]] || die "API key file missing"
  local team; team=$(grep -m1 -oE 'DEVELOPMENT_TEAM = [A-Z0-9]+' "$ROOT/Map Path/Map Path.xcodeproj/project.pbxproj" | awk '{print $3}')
  [[ -n "$team" ]] || die "DEVELOPMENT_TEAM not set in the Xcode project"
  local found=0
  while IFS='|' read -r plat path; do
    [[ -n "$path" ]] || continue; found=1
    say "== $plat archive: $path"
    cat >"$WORK/export-$plat.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>method</key><string>app-store-connect</string>
  <key>destination</key><string>upload</string>
  <key>teamID</key><string>$team</string>
  <key>signingStyle</key><string>automatic</string>
  <key>uploadSymbols</key><true/>
  <key>manageAppVersionAndBuildNumber</key><false/>
</dict></plist>
PLIST
    if [[ $APPLY -eq 1 ]]; then
      if xcodebuild -exportArchive -archivePath "$path" -exportOptionsPlist "$WORK/export-$plat.plist" \
           -exportPath "$WORK/export-$plat" -allowProvisioningUpdates \
           -authenticationKeyPath "$key" -authenticationKeyID "$KEY_ID" -authenticationKeyIssuerID "$ISSUER_ID" >"$WORK/export-$plat.log" 2>&1; then
        say "   uploaded $plat build $BUILD — App Store Connect processes it for ~10–30 minutes."
      else
        grep -E "error" "$WORK/export-$plat.log" | sort -u | sed 's/^/   /' >&2
        # "Cloud signing permission error" means the API key lacks "Access to
        # Cloud Managed Distribution Certificate" (Users and Access →
        # Integrations → the key). Grant it, or upload from Xcode's Organizer.
        die "$plat export failed"
      fi
    else
      say "   would export with method=app-store-connect destination=upload (uploads straight to App Store Connect)"
    fi
  done < <(find_archives)
  [[ $found -eq 1 ]] || die "no Map Path archives for $VERSION ($BUILD) under $ARCHIVES — archive in Xcode first"
}

# ---------------------------------------------------------------- versions

cmd_versions() {
  for plat in IOS MAC_OS; do
    local vid; vid=$(version_id "$plat")
    if [[ -n "$vid" ]]; then say "== $plat $VERSION exists: $vid ($(version_state "$vid"))"; continue; fi
    say "== $plat $VERSION missing — creating"
    post_json /v1/appStoreVersions "{\"data\":{\"type\":\"appStoreVersions\",\"attributes\":{\"platform\":\"$plat\",\"versionString\":\"$VERSION\"},\"relationships\":{\"app\":{\"data\":{\"type\":\"apps\",\"id\":\"$APP_ID\"}}}}}" \
      | json 'print("   created", d["data"]["id"])' || true
  done
}

# ---------------------------------------------------------------- screenshots

# ensure_set <locId> <displayType> → set id (creates when missing)
ensure_set() {
  local sid
  sid=$("$ASC" GET "/v1/appStoreVersionLocalizations/$1/appScreenshotSets?filter[screenshotDisplayType]=$2" 2>/dev/null | json 'print(d["data"][0]["id"] if d["data"] else "")')
  if [[ -z "$sid" ]]; then
    sid=$(post_json /v1/appScreenshotSets "{\"data\":{\"type\":\"appScreenshotSets\",\"attributes\":{\"screenshotDisplayType\":\"$2\"},\"relationships\":{\"appStoreVersionLocalization\":{\"data\":{\"type\":\"appStoreVersionLocalizations\",\"id\":\"$1\"}}}}}" \
      | json 'print(d["data"]["id"])' 2>/dev/null || true)
  fi
  echo "$sid"
}

upload_one() { # upload_one <setId> <file> → new screenshot id (verified)
  local set="$1" p="$2" f; f=$(basename "$p")
  local size sum w h id state
  size=$(stat -f %z "$p"); sum=$(md5 -q "$p")
  w=$(sips -g pixelWidth "$p" | awk '/pixelWidth/{print $2}'); h=$(sips -g pixelHeight "$p" | awk '/pixelHeight/{print $2}')
  "$PY" -I -c 'import json,sys; print(json.dumps({"data":{"type":"appScreenshots","attributes":{"fileName":sys.argv[1],"fileSize":int(sys.argv[2])},"relationships":{"appScreenshotSet":{"data":{"type":"appScreenshotSets","id":sys.argv[3]}}}}}))' "$f" "$size" "$set" >"$WORK/reserve.json"
  "$ASC" POST /v1/appScreenshots "$WORK/reserve.json" --apply 2>/dev/null >"$WORK/res.json" || { cat "$WORK/res.json" >&2; die "reserve failed for $f"; }
  id=$(json 'print(d["data"]["id"])' <"$WORK/res.json") || die "reserve returned no id for $f"
  "$PY" -I - "$WORK/res.json" "$p" <<'PYEOF'
import json, subprocess, sys, urllib.parse
ops = json.load(open(sys.argv[1]))["data"]["attributes"]["uploadOperations"]
data = open(sys.argv[2], "rb").read()
for op in ops:
    u = urllib.parse.urlparse(op["url"])
    if u.scheme != "https" or not (u.hostname == "apple.com" or u.hostname.endswith(".apple.com")):
        sys.exit(f"refusing upload URL host {u.hostname}")
    chunk = data[op["offset"]:op["offset"] + op["length"]]
    args = ["/usr/bin/curl", "--silent", "--show-error", "--fail", "--max-time", "300",
            "-X", op["method"], "--data-binary", "@-", "-o", "/dev/null"]
    for hd in op.get("requestHeaders") or []:
        args += ["-H", f'{hd["name"]}: {hd["value"]}']
    subprocess.run(args + [op["url"]], input=chunk, check=True)
PYEOF
  "$PY" -I -c 'import json,sys; print(json.dumps({"data":{"type":"appScreenshots","id":sys.argv[1],"attributes":{"uploaded":True,"sourceFileChecksum":sys.argv[2]}}}))' "$id" "$sum" >"$WORK/commit.json"
  "$ASC" PATCH "/v1/appScreenshots/$id" "$WORK/commit.json" --apply 2>/dev/null >/dev/null
  state=""
  for _ in $(seq 1 200); do
    "$ASC" GET "/v1/appScreenshots/$id" 2>/dev/null >"$WORK/shot.json"
    state=$(json 'print((d["data"]["attributes"].get("assetDeliveryState") or {}).get("state"))' <"$WORK/shot.json")
    [[ "$state" == "COMPLETE" || "$state" == "FAILED" ]] && break
    /bin/sleep 3
  done
  [[ "$state" == "COMPLETE" ]] || die "$f ended in state $state — old shots left in place"
  local check; check=$(json 'a=d["data"]["attributes"]; print(a["imageAsset"]["width"], a["imageAsset"]["height"], a["sourceFileChecksum"])' <"$WORK/shot.json")
  [[ "$check" == "$w $h $sum" ]] || die "$f verify failed: ASC '$check' vs local '$w $h $sum'"
  echo "$id"
}

do_slots() { # do_slots <locId> slots...
  local loc="$1"; shift
  for slot in "$@"; do
    IFS='|' read -r TYPE NAMES <<<"$slot"
    say "-- $TYPE"
    for n in $NAMES; do
      local p="$SHOTS/$n.png"; [[ -r "$p" ]] || die "missing $p"
      [[ "$(sips -g hasAlpha "$p" | awk '/hasAlpha/{print $2}')" == "no" ]] || die "$p has an alpha channel"
    done
    local sid; sid=$(ensure_set "$loc" "$TYPE")
    if [[ -z "$sid" ]]; then say "   (set would be created, then $(wc -w <<<"$NAMES" | tr -d ' ') files uploaded)"; continue; fi
    # Existing shots as "id|fileName|checksum|state" so a re-run after an
    # interrupted upload reuses what already completed instead of duplicating it.
    "$ASC" GET "/v1/appScreenshotSets/$sid/appScreenshots?fields[appScreenshots]=fileName,sourceFileChecksum,assetDeliveryState" 2>/dev/null \
      | json 'print("\n".join("%s|%s|%s|%s" % (x["id"], x["attributes"]["fileName"], x["attributes"].get("sourceFileChecksum") or "", (x["attributes"].get("assetDeliveryState") or {}).get("state") or "") for x in d["data"]))' >"$WORK/existing.txt"
    local existing_count; existing_count=$(grep -c . "$WORK/existing.txt" || true)
    say "   set $sid — currently $existing_count shot(s); new: $NAMES"
    [[ $APPLY -eq 1 ]] || continue
    # A set holds at most 10 shots, so anything that is not an exact,
    # completed match for a new file goes first; the version is still in
    # PREPARE_FOR_SUBMISSION, so a briefly thin slot costs nothing.
    local keep=() removed=0
    for n in $NAMES; do
      local sum; sum=$(md5 -q "$SHOTS/$n.png")
      local r; r=$(awk -F'|' -v f="$n.png" -v c="$sum" '$2==f && $3==c && $4=="COMPLETE" {print $1; exit}' "$WORK/existing.txt")
      [[ -z "$r" ]] || keep+=("$r")
    done
    while IFS='|' read -r oid _; do
      [[ -n "$oid" ]] || continue
      [[ " ${keep[*]:-} " == *" $oid "* ]] && continue
      "$ASC" DELETE "/v1/appScreenshots/$oid" --apply 2>/dev/null >/dev/null; removed=$((removed+1))
    done <"$WORK/existing.txt"
    [[ $removed -eq 0 ]] || say "   removed $removed old/duplicate shot(s)"
    local new=()
    for n in $NAMES; do
      local sum reuse; sum=$(md5 -q "$SHOTS/$n.png")
      reuse=$(awk -F'|' -v f="$n.png" -v c="$sum" '$2==f && $3==c && $4=="COMPLETE" {print $1; exit}' "$WORK/existing.txt")
      if [[ -n "$reuse" ]]; then new+=("$reuse"); say "   kept already-complete $n.png"
      else
        local id; id=$(upload_one "$sid" "$SHOTS/$n.png") || die "stopping at $n.png"
        new+=("$id"); say "   uploaded + verified $n.png"
      fi
    done
    "$PY" -I -c 'import json,sys; print(json.dumps({"data":[{"type":"appScreenshots","id":i} for i in sys.argv[1:]]}))' "${new[@]}" >"$WORK/order.json"
    "$ASC" PATCH "/v1/appScreenshotSets/$sid/relationships/appScreenshots" "$WORK/order.json" --apply 2>/dev/null >/dev/null
    say "   ordered ${#new[@]} shot(s)"
  done
}

cmd_screenshots() {
  for plat in IOS MAC_OS; do
    local vid; vid=$(version_id "$plat"); [[ -n "$vid" ]] || die "$plat $VERSION does not exist yet — run 'versions' first"
    local loc; loc=$(localization_id "$vid"); [[ -n "$loc" ]] || die "no localization on $plat $VERSION"
    say "== $plat $VERSION → localization $loc"
    if [[ "$plat" == "IOS" ]]; then do_slots "$loc" "${IOS_SLOTS[@]}"; else do_slots "$loc" "${MAC_SLOTS[@]}"; fi
  done
}

# ---------------------------------------------------------------- whats-new

cmd_whats_new() {
  [[ -r "$WHATS_NEW" ]] || die "write the release notes to $WHATS_NEW first"
  local text; text=$("$PY" -I -c 'import json,sys; print(json.dumps(open(sys.argv[1]).read().strip()))' "$WHATS_NEW")
  say "== What's New ($(wc -c <"$WHATS_NEW" | tr -d ' ') chars): $(head -c 90 "$WHATS_NEW")…"
  for plat in IOS MAC_OS; do
    local vid; vid=$(version_id "$plat"); [[ -n "$vid" ]] || die "$plat $VERSION does not exist yet"
    local loc; loc=$(localization_id "$vid")
    patch_json "/v1/appStoreVersionLocalizations/$loc" "{\"data\":{\"type\":\"appStoreVersionLocalizations\",\"id\":\"$loc\",\"attributes\":{\"whatsNew\":$text}}}"
    [[ $APPLY -eq 1 ]] && say "   set on $plat"
  done
}

# ---------------------------------------------------------------- attach-build

cmd_attach_build() {
  for plat in IOS MAC_OS; do
    local vid; vid=$(version_id "$plat"); [[ -n "$vid" ]] || die "$plat $VERSION does not exist yet"
    local bid state
    read -r bid state < <("$ASC" GET "/v1/builds?filter[app]=$APP_ID&filter[version]=$BUILD&filter[preReleaseVersion.platform]=$plat&fields[builds]=version,processingState&limit=1" 2>/dev/null \
      | json 'b=d["data"]; print(b[0]["id"], b[0]["attributes"]["processingState"]) if b else print("", "MISSING")')
    say "== $plat build $BUILD: ${bid:-none} ($state)"
    [[ "$state" == "VALID" ]] || { say "   not ready to attach yet"; continue; }
    patch_json "/v1/appStoreVersions/$vid/relationships/build" "{\"data\":{\"type\":\"builds\",\"id\":\"$bid\"}}"
    [[ $APPLY -eq 1 ]] && say "   attached to $plat $VERSION"
  done
}

# ---------------------------------------------------------------- submit

cmd_submit() {
  for plat in IOS MAC_OS; do
    local vid; vid=$(version_id "$plat"); [[ -n "$vid" ]] || die "$plat $VERSION does not exist yet"
    say "== $plat $VERSION ($(version_state "$vid"))"
    local rs
    rs=$(post_json /v1/reviewSubmissions "{\"data\":{\"type\":\"reviewSubmissions\",\"attributes\":{\"platform\":\"$plat\"},\"relationships\":{\"app\":{\"data\":{\"type\":\"apps\",\"id\":\"$APP_ID\"}}}}}" | json 'print(d["data"]["id"])' 2>/dev/null || true)
    [[ $APPLY -eq 1 ]] || { say "   would add $VERSION to the submission and submit it"; continue; }
    [[ -n "$rs" ]] || die "could not create a review submission for $plat"
    post_json /v1/reviewSubmissionItems "{\"data\":{\"type\":\"reviewSubmissionItems\",\"relationships\":{\"reviewSubmission\":{\"data\":{\"type\":\"reviewSubmissions\",\"id\":\"$rs\"}},\"appStoreVersion\":{\"data\":{\"type\":\"appStoreVersions\",\"id\":\"$vid\"}}}}}" >/dev/null
    patch_json "/v1/reviewSubmissions/$rs" "{\"data\":{\"type\":\"reviewSubmissions\",\"id\":\"$rs\",\"attributes\":{\"submitted\":true}}}"
    say "   submitted $plat — now $(version_state "$vid")"
  done
}

# ---------------------------------------------------------------- plan

cmd_plan() {
  say "== archives for $VERSION ($BUILD)"; find_archives | sed 's/^/   /' || true
  [[ -n "$(find_archives)" ]] || say "   none yet — archive both schemes in Xcode"
  for plat in IOS MAC_OS; do
    local vid; vid=$(version_id "$plat")
    if [[ -n "$vid" ]]; then say "== $plat $VERSION: $vid ($(version_state "$vid"))"; else say "== $plat $VERSION: not created yet"; fi
  done
  say "== builds seen by App Store Connect for $BUILD"
  "$ASC" GET "/v1/builds?filter[app]=$APP_ID&filter[version]=$BUILD&fields[builds]=version,processingState&include=preReleaseVersion&fields[preReleaseVersions]=platform" 2>/dev/null \
    | json 'inc={x["id"]:x for x in d.get("included",[])}
for b in d["data"]:
    pr=b["relationships"]["preReleaseVersion"]["data"]; print("  ", inc[pr["id"]]["attributes"]["platform"] if pr and pr["id"] in inc else "?", b["attributes"]["processingState"])
if not d["data"]: print("   none")'
  say "== screenshots to upload"
  for slot in "${IOS_SLOTS[@]}" "${MAC_SLOTS[@]}"; do IFS='|' read -r TYPE NAMES <<<"$slot"; say "   $TYPE ← $NAMES"; done
  say "== What's New: $([[ -r "$WHATS_NEW" ]] && echo "$(wc -c <"$WHATS_NEW" | tr -d ' ') chars in work/whats-new.txt" || echo "missing — write work/whats-new.txt")"
  say
  say "Run in this order, each with --apply once its dry run looks right:"
  say "   upload-builds → versions → screenshots → whats-new → attach-build (after processing) → submit"
}

case "$CMD" in
  plan) cmd_plan ;;
  upload-builds) cmd_upload_builds ;;
  versions) cmd_versions ;;
  screenshots) cmd_screenshots ;;
  whats-new) cmd_whats_new ;;
  attach-build) cmd_attach_build ;;
  submit) cmd_submit ;;
  *) sed -n '2,24p' "$0" | sed 's/^# \{0,1\}//' >&2; exit 64 ;;
esac
