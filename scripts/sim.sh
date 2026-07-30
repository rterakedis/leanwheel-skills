#!/usr/bin/env bash
# sim.sh — deterministic iOS/iPadOS Simulator harness for leanwheel.
#
# One shell command per intent. The caller (human or agent) runs a subcommand and
# reads the resulting PNGs / text — never reasons from a screenshot to a tap
# coordinate. There are NO coordinate taps anywhere in this script, and none are
# permitted in any flow it runs.
#
# Navigation is ALWAYS by deep link (`<scheme>://<route>`), never by tapping.
# Data state is set by the `--seed` launch argument. Both halves of that contract
# live in docs/setup/swift/testability.md; the host-side reference is
# docs/setup/swift/simulator.md.
#
# Subcommands:
#   doctor                    Check toolchain, config, device, scheme, URL scheme.
#   boot [--fresh]            Boot the simulator (idempotent) + open Simulator.app.
#                             --fresh restarts it first, clearing wedged system alerts.
#   install                   Build for the simulator and install the app.
#   open <route>              Deep-link the RUNNING app to a route (no relaunch).
#   launch [--seed S] [--route R]   Cold launch, optionally seeded, then route.
#   shots <name> [--route R]  Screenshot matrix: appearance x text size x device.
#   dump [--route R]          Dump the accessibility hierarchy (identifiers).
#   flow <Name>               Run one named XCUITest flow, export its screenshots.
#   privacy grant|reset [svc] Pre-grant permission alerts so a run doesn't stall.
#   erase                     Wipe the simulator (destructive) when it is wedged.
#   clean                     Remove captured artifacts.
#
# Config is cached in .leanwheel/sim.json on first run (deriving it needs a slow
# xcodebuild call). Delete that file to re-derive. Artifacts land in .leanwheel/sim/,
# which self-ignores via its own .gitignore.
#
# Degrades loudly, never silently: every failure prints the cause and the fix.

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG="$PROJECT_DIR/.leanwheel/sim.json"
ART_DIR="$PROJECT_DIR/.leanwheel/sim"
SHOTS_DIR="$ART_DIR/shots"
DUMPS_DIR="$ART_DIR/dumps"
RESULTS_DIR="$ART_DIR/results"

SETTLE=2          # seconds to let the UI settle before a capture
SHOT_MAX_PX=1000  # screenshots are downscaled to this longest edge (2.9MB -> ~0.4MB)
GRANT_OVERRIDE="" # --grant on launch/shots; else config's privacy_grant

die() { echo "sim: $*" >&2; exit 1; }
note() { echo "sim: $*" >&2; }

# ---------------------------------------------------------------- config

cfg() {
  # cfg <key.path> — prints the value, empty string if absent.
  [ -f "$CONFIG" ] || return 0
  plutil -extract "$1" raw -o - "$CONFIG" 2>/dev/null || true
}

require_xcode() {
  command -v xcrun >/dev/null 2>&1 || die "xcrun not found. Install Xcode from the App Store, then run: xcode-select --install"
  xcodebuild -version >/dev/null 2>&1 || die "xcodebuild is not usable. Xcode may be missing or xcode-select points at the CLT only.
  Fix (needs your password): sudo xcode-select -s /Applications/Xcode.app/Contents/Developer"
}

find_container() {
  # Prefer a workspace over a bare project, matching Xcode's own resolution order.
  local ws proj
  ws=$(/usr/bin/find "$PROJECT_DIR" -maxdepth 3 -name "*.xcworkspace" -not -path "*/.*" -not -path "*xcodeproj*" 2>/dev/null | head -1)
  if [ -n "$ws" ]; then echo "-workspace|$ws"; return 0; fi
  proj=$(/usr/bin/find "$PROJECT_DIR" -maxdepth 3 -name "*.xcodeproj" -not -path "*/.*" 2>/dev/null | head -1)
  if [ -n "$proj" ]; then echo "-project|$proj"; return 0; fi
  return 1
}

derive_config() {
  require_xcode
  local pair flag container scheme uitest bundle_id product build_dir plist srcroot url_scheme
  local tmp list_json bs_json root

  pair=$(find_container) || die "no .xcodeproj or .xcworkspace found under $PROJECT_DIR"
  flag="${pair%%|*}"; container="${pair#*|}"

  note "deriving config from $(basename "$container") (one-time, ~20s)..."

  tmp=$(mktemp -d)
  list_json="$tmp/list.json"; bs_json="$tmp/bs.json"

  xcodebuild "$flag" "$container" -list -json > "$list_json" 2>/dev/null \
    || die "xcodebuild -list failed for $container"
  # A workspace nests under "workspace", a bare project under "project".
  if plutil -extract workspace raw -o - "$list_json" >/dev/null 2>&1; then root="workspace"; else root="project"; fi

  # Scheme: prefer the one named after the container, else the first listed.
  local base i s
  base=$(basename "$container"); base="${base%.*}"
  i=0
  while s=$(plutil -extract "$root.schemes.$i" raw -o - "$list_json" 2>/dev/null); do
    [ "$s" = "$base" ] && scheme="$s" && break
    [ -z "${scheme:-}" ] && scheme="$s"
    i=$((i + 1))
  done
  [ -n "${scheme:-}" ] || die "could not determine a scheme. Run: xcodebuild $flag \"$container\" -list"

  # UI test target, if one exists (absent until a project adopts flows).
  uitest=""
  i=0
  while s=$(plutil -extract "$root.targets.$i" raw -o - "$list_json" 2>/dev/null); do
    case "$s" in *UITests) uitest="$s"; break ;; esac
    i=$((i + 1))
  done

  # A destination is REQUIRED here — without it -showBuildSettings prints nothing.
  xcodebuild "$flag" "$container" -scheme "$scheme" \
    -destination 'generic/platform=iOS Simulator' -showBuildSettings -json > "$bs_json" 2>/dev/null || true
  [ -s "$bs_json" ] || die "xcodebuild -showBuildSettings failed for scheme '$scheme'"

  bs() { plutil -extract "0.buildSettings.$1" raw -o - "$bs_json" 2>/dev/null || true; }
  bundle_id=$(bs PRODUCT_BUNDLE_IDENTIFIER)
  product=$(bs FULL_PRODUCT_NAME)
  build_dir=$(bs CONFIGURATION_BUILD_DIR)
  plist=$(bs INFOPLIST_FILE)
  srcroot=$(bs SRCROOT)
  [ -n "$bundle_id" ] || die "could not read PRODUCT_BUNDLE_IDENTIFIER from build settings"

  # URL scheme — the navigation contract. INFOPLIST_FILE is relative to SRCROOT
  # (which is the .xcodeproj's directory, not necessarily the repo root).
  url_scheme=""
  if [ -n "$plist" ] && [ -f "$srcroot/$plist" ]; then
    url_scheme=$(plutil -extract CFBundleURLTypes.0.CFBundleURLSchemes.0 raw -o - "$srcroot/$plist" 2>/dev/null || true)
  fi
  # Projects using a generated Info.plist carry the schemes as a build setting instead.
  [ -z "$url_scheme" ] && url_scheme=$(bs INFOPLIST_KEY_CFBundleURLSchemes | tr ' ' '\n' | head -1)

  mkdir -p "$(dirname "$CONFIG")"
  cat > "$CONFIG" <<EOF
{
  "container_flag": "$flag",
  "container": "$container",
  "scheme": "$scheme",
  "bundle_id": "$bundle_id",
  "product": "$product",
  "build_dir": "$build_dir",
  "url_scheme": "$url_scheme",
  "ui_test_target": "$uitest",
  "privacy_grant": "$(suggest_privacy_services "$srcroot/$plist" "$bs_json")",
  "privacy_blocked": "$(unpregrantable_services "$srcroot/$plist" "$bs_json")",
  "devices": { "iphone": "iPhone 17", "ipad": "iPad Pro 11-inch (M5)" }
}
EOF
  rm -rf "$tmp"
  note "wrote $CONFIG"
}

ensure_config() { [ -f "$CONFIG" ] || derive_config; }

# Map the app's declared NS*UsageDescription keys to `simctl privacy` services, so a
# seeded run doesn't stall behind a system permission alert. NOTE: there is NO simctl
# service for camera, Face ID, Bluetooth, tracking (ATT), or notifications — those
# alerts cannot be pre-granted and must be handled in-flow with an interruption
# monitor, or screenshotted deliberately as the state they are.
suggest_privacy_services() {
  # A usage string can live in EITHER the Info.plist file OR, for the generated-plist
  # projects Xcode now defaults to, an INFOPLIST_KEY_* build setting. Checking only
  # one misses most modern projects — the same dual-location gotcha /appstore-preflight
  # documents for purpose strings.
  local plist="$1" bs_json="${2:-}" out=""
  has() {
    [ -f "$plist" ] && plutil -extract "$1" raw -o - "$plist" >/dev/null 2>&1 && return 0
    [ -n "$bs_json" ] && [ -f "$bs_json" ] && \
      plutil -extract "0.buildSettings.INFOPLIST_KEY_$1" raw -o - "$bs_json" >/dev/null 2>&1 && return 0
    return 1
  }
  add() { case " $out " in *" $1 "*) ;; *) out="$out $1" ;; esac; }
  has NSContactsUsageDescription                    && add contacts
  has NSCalendarsUsageDescription                   && add calendar
  has NSCalendarsFullAccessUsageDescription         && add calendar
  has NSRemindersUsageDescription                   && add reminders
  has NSRemindersFullAccessUsageDescription         && add reminders
  has NSPhotoLibraryUsageDescription                && add photos
  has NSPhotoLibraryAddUsageDescription             && add photos-add
  has NSMicrophoneUsageDescription                  && add microphone
  has NSMotionUsageDescription                      && add motion
  has NSAppleMusicUsageDescription                  && add media-library
  has NSSiriUsageDescription                        && add siri
  has NSLocationWhenInUseUsageDescription           && add location
  has NSLocationAlwaysAndWhenInUseUsageDescription  && add location-always
  echo "${out# }"
}

# Declared permissions that simctl CANNOT pre-grant — report them so the user knows
# why a run still stalls. Camera/FaceID/Bluetooth/tracking/notifications alerts must
# be handled by an XCUITest interruption monitor, or captured as the state they are.
unpregrantable_services() {
  local plist="$1" bs_json="${2:-}" out=""
  has() {
    [ -f "$plist" ] && plutil -extract "$1" raw -o - "$plist" >/dev/null 2>&1 && return 0
    [ -n "$bs_json" ] && [ -f "$bs_json" ] && \
      plutil -extract "0.buildSettings.INFOPLIST_KEY_$1" raw -o - "$bs_json" >/dev/null 2>&1 && return 0
    return 1
  }
  has NSCameraUsageDescription                && out="$out camera"
  has NSFaceIDUsageDescription                && out="$out face-id"
  has NSBluetoothAlwaysUsageDescription       && out="$out bluetooth"
  has NSUserTrackingUsageDescription          && out="$out tracking(ATT)"
  echo "${out# }"
}

apply_privacy() {
  # apply_privacy <udid> <services...> — grant so an automated run isn't blocked.
  local udid="$1"; shift
  local bundle svc; bundle=$(cfg bundle_id)
  for svc in "$@"; do
    [ -n "$svc" ] || continue
    xcrun simctl privacy "$udid" grant "$svc" "$bundle" >/dev/null 2>&1 || \
      note "could not grant '$svc' (unknown service, or the app must be reinstalled)"
  done
}

ensure_artifacts_dir() {
  mkdir -p "$SHOTS_DIR" "$DUMPS_DIR" "$RESULTS_DIR"
  # Self-ignoring: no edit to the project's own .gitignore required.
  [ -f "$ART_DIR/.gitignore" ] || printf '*\n' > "$ART_DIR/.gitignore"
}

# ---------------------------------------------------------------- devices

resolve_device() {
  # resolve_device <iphone|ipad|exact device name> -> UDID
  local key="$1" name
  case "$key" in
    iphone) name=$(cfg devices.iphone) ;;
    ipad)   name=$(cfg devices.ipad) ;;
    *)      name="$key" ;;
  esac
  [ -n "$name" ] || die "no device configured for '$key'. Edit devices in $CONFIG"

  local udid
  udid=$(xcrun simctl list devices available | sed -n "s/^ *${name} (\([0-9A-Fa-f-]*\)) (.*/\1/p" | head -1)
  if [ -z "$udid" ]; then
    echo "sim: no available simulator named '$name'." >&2
    echo "     Available devices:" >&2
    xcrun simctl list devices available | sed -n 's/^ *\([^(]*\) ([0-9A-Fa-f-]*) (.*/       \1/p' | sort -u >&2
    echo "     Fix: edit \"devices\" in $CONFIG, or add one in Xcode > Window > Devices and Simulators." >&2
    exit 1
  fi
  echo "$udid"
}

boot_device() {
  # boot_device <udid> [fresh:0|1]
  local udid="$1" fresh="${2:-0}"
  # A wedged system alert (a permission prompt left on screen by an earlier run)
  # survives app terminate+relaunch and silently poisons every subsequent capture —
  # you get four screenshots of the alert instead of the app. Only a device restart
  # clears it. That is what --fresh is for.
  if [ "$fresh" = "1" ]; then
    note "restarting device to clear any wedged system UI..."
    xcrun simctl shutdown "$udid" >/dev/null 2>&1 || true
  fi
  # bootstatus -b is the idempotent form. Plain `simctl boot` ERRORS when the
  # device is already booted (exit 149) — do not use it here.
  xcrun simctl bootstatus "$udid" -b >/dev/null 2>&1 || die "failed to boot simulator $udid"
  open -a Simulator >/dev/null 2>&1 || true   # so the supervising human can watch
  # Deterministic status bar — otherwise clock/battery churn makes every
  # screenshot differ from the last for no real reason.
  xcrun simctl status_bar "$udid" override \
    --time "9:41" --dataNetwork wifi --wifiMode active --wifiBars 3 \
    --cellularMode active --cellularBars 4 --batteryState charged --batteryLevel 100 \
    >/dev/null 2>&1 || true
}

# ---------------------------------------------------------------- app

app_path() {
  local build_dir product
  build_dir=$(cfg build_dir); product=$(cfg product)
  [ -n "$build_dir" ] && [ -n "$product" ] || die "build_dir/product missing from $CONFIG — delete it and re-run to re-derive"
  echo "$build_dir/$product"
}

build_and_install() {
  local udid="$1" flag container scheme app
  flag=$(cfg container_flag); container=$(cfg container); scheme=$(cfg scheme)
  note "building $scheme..."
  xcodebuild "$flag" "$container" -scheme "$scheme" \
    -destination "platform=iOS Simulator,id=$udid" \
    -derivedDataPath "$ART_DIR/DerivedData" \
    build >"$ART_DIR/build.log" 2>&1 || {
      echo "sim: build FAILED. Last 40 lines of $ART_DIR/build.log:" >&2
      tail -40 "$ART_DIR/build.log" >&2
      exit 1
    }
  app="$ART_DIR/DerivedData/Build/Products/Debug-iphonesimulator/$(cfg product)"
  [ -d "$app" ] || app="$(app_path)"
  [ -d "$app" ] || die "built, but no .app found at $app"
  xcrun simctl install "$udid" "$app" || die "simctl install failed for $app"
  note "installed $(cfg bundle_id)"
}

route_url() {
  # route_url <route> — bare routes are prefixed with the app's URL scheme.
  local route="$1" scheme
  case "$route" in *://*) echo "$route"; return 0 ;; esac
  scheme=$(cfg url_scheme)
  [ -n "$scheme" ] || die "this app has no URL scheme registered, so it cannot be navigated.
  Navigation in this harness is deep-link only — see 'sim.sh doctor' for the exact Info.plist fix."
  echo "$scheme://$route"
}

open_route() {
  local udid="$1" route="$2" url
  url=$(route_url "$route")
  xcrun simctl openurl "$udid" "$url" || die "openurl failed for $url — is the route handled in .onOpenURL?"
  sleep "$SETTLE"
}

launch_app() {
  # launch_app <udid> <seed> <uitest:0|1> <reset:0|1>
  local udid="$1" seed="$2" uitest="$3" reset="$4" bundle args grant
  bundle=$(cfg bundle_id)
  # Pre-grant declared permissions, or the very first launch stalls behind a system
  # alert and every capture is a screenshot of that alert. GRANT_OVERRIDE wins;
  # otherwise use whatever `derive_config` inferred from the Info.plist.
  grant="${GRANT_OVERRIDE:-$(cfg privacy_grant)}"
  # shellcheck disable=SC2086
  [ -n "$grant" ] && apply_privacy "$udid" $(echo "$grant" | tr ',' ' ')
  args=""
  [ "$uitest" = "1" ] && args="$args --uitest"
  [ "$reset" = "1" ] && args="$args --reset"
  [ -n "$seed" ] && args="$args --seed $seed"
  xcrun simctl terminate "$udid" "$bundle" >/dev/null 2>&1 || true
  # shellcheck disable=SC2086
  xcrun simctl launch "$udid" "$bundle" $args >/dev/null || die "launch failed for $bundle — is it installed? Run: sim.sh install"
  sleep "$SETTLE"
}

capture() {
  # capture <udid> <output.png>
  local udid="$1" out="$2"
  mkdir -p "$(dirname "$out")"
  xcrun simctl io "$udid" screenshot "$out" >/dev/null 2>&1 || die "screenshot failed"
  # Downscale in place: a native-resolution capture is ~2.9MB, which is expensive
  # for an agent to read back. ~1000px longest edge keeps text legible at ~0.4MB.
  sips -Z "$SHOT_MAX_PX" "$out" >/dev/null 2>&1 || true
}

# ---------------------------------------------------------------- subcommands

cmd_doctor() {
  require_xcode
  echo "Xcode:       $(xcodebuild -version | head -1)  ($(xcode-select -p))"
  ensure_config
  echo "Container:   $(cfg container)"
  echo "Scheme:      $(cfg scheme)"
  echo "Bundle id:   $(cfg bundle_id)"

  local scheme uitest
  scheme=$(cfg url_scheme)
  if [ -n "$scheme" ]; then
    echo "URL scheme:  $scheme://   (navigation OK)"
  else
    cat >&2 <<'EOF'
URL scheme:  MISSING — this is a hard stop for navigation.

  This harness navigates only by deep link; it never taps coordinates. The app
  needs a URL scheme registered once. In the target's Info.plist add:

    <key>CFBundleURLTypes</key>
    <array>
      <dict>
        <key>CFBundleTypeRole</key><string>Editor</string>
        <key>CFBundleURLName</key><string>$(PRODUCT_BUNDLE_IDENTIFIER)</string>
        <key>CFBundleURLSchemes</key><array><string>yourapp</string></array>
      </dict>
    </array>

  Then handle it in the root view:  .onOpenURL { url in router.handle(url) }
  See docs/setup/swift/testability.md (Deep-Link Route Contract).
EOF
  fi

  uitest=$(cfg ui_test_target)
  if [ -n "$uitest" ]; then
    echo "UI tests:    $uitest  (flows runnable)"
  else
    echo "UI tests:    none — 'sim.sh flow' and 'sim.sh dump' need a UI test target."
    echo "             Add one in Xcode > File > New > Target > UI Testing Bundle."
  fi

  local grant blocked
  grant=$(cfg privacy_grant); blocked=$(cfg privacy_blocked)
  if [ -n "$grant" ]; then
    echo "Permissions: auto-granted before launch — $grant"
  else
    echo "Permissions: none declared (nothing to pre-grant)"
  fi
  if [ -n "$blocked" ]; then
    echo "             NOT pre-grantable: $blocked — simctl has no service for these."
    echo "             They will still prompt. Handle with an XCUITest interruption"
    echo "             monitor, or screenshot the prompt deliberately as a real state."
  fi

  local udid
  udid=$(resolve_device "${1:-iphone}")
  echo "Device:      $(cfg devices.iphone) ($udid)"
  echo "Artifacts:   $ART_DIR"
}

cmd_boot() {
  ensure_config; ensure_artifacts_dir
  local device="iphone" fresh=0
  while [ $# -gt 0 ]; do
    case "$1" in
      --fresh)  fresh=1; shift ;;
      --device) device="$2"; shift 2 ;;
      *) device="$1"; shift ;;
    esac
  done
  local udid; udid=$(resolve_device "$device")
  boot_device "$udid" "$fresh"
  note "booted $udid"
}

cmd_erase() {
  # Destructive: wipes the simulator's contents. The nuclear option when a device
  # is wedged past what --fresh clears (corrupt store, stale keychain, bad TCC state).
  ensure_config
  local udid; udid=$(resolve_device "${1:-iphone}")
  note "erasing simulator $udid (all apps and data on it will be lost)..."
  xcrun simctl shutdown "$udid" >/dev/null 2>&1 || true
  xcrun simctl erase "$udid" || die "erase failed for $udid"
  note "erased. Run 'sim.sh install' to reinstall the app."
}

cmd_install() {
  ensure_config; ensure_artifacts_dir
  local udid; udid=$(resolve_device "${1:-iphone}")
  boot_device "$udid"
  build_and_install "$udid"
}

cmd_open() {
  ensure_config
  local route="${1:-}" udid
  [ -n "$route" ] || die "usage: sim.sh open <route>"
  udid=$(resolve_device "${2:-iphone}")
  open_route "$udid" "$route"
  note "opened $(route_url "$route")"
}

cmd_launch() {
  ensure_config; ensure_artifacts_dir
  local seed="" route="" device="iphone" uitest=0 reset=0 fresh=0
  while [ $# -gt 0 ]; do
    case "$1" in
      --fresh)  fresh=1; shift ;;
      --seed)   seed="$2"; shift 2 ;;
      --route)  route="$2"; shift 2 ;;
      --device) device="$2"; shift 2 ;;
      --grant)  GRANT_OVERRIDE="$2"; shift 2 ;;
      --uitest) uitest=1; shift ;;
      --reset)  reset=1; shift ;;
      *) die "unknown option for launch: $1" ;;
    esac
  done
  local udid; udid=$(resolve_device "$device")
  boot_device "$udid" "$fresh"
  launch_app "$udid" "$seed" "$uitest" "$reset"
  [ -n "$route" ] && open_route "$udid" "$route"
  note "launched${seed:+ --seed $seed}${route:+ -> $route}"
}

cmd_shots() {
  ensure_config; ensure_artifacts_dir
  local name="${1:-}"; shift || true
  [ -n "$name" ] || die "usage: sim.sh shots <name> [--route R] [--seed S] [--devices iphone,ipad]"

  local seed="typical" route="" devices="iphone" appearances="light,dark" sizes="large,accessibility-extra-large" fresh=0
  while [ $# -gt 0 ]; do
    case "$1" in
      --fresh)       fresh=1; shift ;;
      --seed)        seed="$2"; shift 2 ;;
      --route)       route="$2"; shift 2 ;;
      --devices)     devices="$2"; shift 2 ;;
      --appearances) appearances="$2"; shift 2 ;;
      --sizes)       sizes="$2"; shift 2 ;;
      --grant)       GRANT_OVERRIDE="$2"; shift 2 ;;
      *) die "unknown option for shots: $1" ;;
    esac
  done

  local stamp out_dir count=0
  stamp=$(date +%Y%m%d-%H%M%S)
  out_dir="$SHOTS_DIR/$stamp"
  mkdir -p "$out_dir"

  local dev udid appearance size short
  for dev in $(echo "$devices" | tr ',' ' '); do
    udid=$(resolve_device "$dev")
    boot_device "$udid" "$fresh"
    # One cold launch per device. Every subsequent state change is a deep link or
    # a simctl ui toggle — no relaunch. That is the whole point of the deep-link
    # contract: a 24-capture matrix costs 1 launch, not 24.
    launch_app "$udid" "$seed" 1 0
    [ -n "$route" ] && open_route "$udid" "$route"
    for appearance in $(echo "$appearances" | tr ',' ' '); do
      xcrun simctl ui "$udid" appearance "$appearance" >/dev/null 2>&1 || true
      for size in $(echo "$sizes" | tr ',' ' '); do
        xcrun simctl ui "$udid" content_size "$size" >/dev/null 2>&1 || true
        sleep 1
        case "$size" in accessibility-*) short="axl" ;; *) short="default" ;; esac
        capture "$udid" "$out_dir/${name}-${dev}-${appearance}-${short}.png"
        count=$((count + 1))
      done
    done
    # Leave the device in a sane state for the human watching.
    xcrun simctl ui "$udid" appearance light >/dev/null 2>&1 || true
    xcrun simctl ui "$udid" content_size large >/dev/null 2>&1 || true
  done

  echo "$count screenshots -> $out_dir"
  ls "$out_dir"
}

cmd_dump() {
  ensure_config; ensure_artifacts_dir
  local uitest; uitest=$(cfg ui_test_target)
  [ -n "$uitest" ] || die "no UI test target — the hierarchy dump needs one (see 'sim.sh doctor').

  There is NO xcrun/simctl command that dumps a running app's accessibility tree.
  Apple ships no such CLI. The supported equivalent is an XCUITest that attaches
  app.debugDescription, which is what this subcommand runs. See
  docs/setup/swift/simulator.md (Hierarchy Dump)."

  local route="" device="iphone" seed="typical"
  while [ $# -gt 0 ]; do
    case "$1" in
      --route)  route="$2"; shift 2 ;;
      --seed)   seed="$2"; shift 2 ;;
      --device) device="$2"; shift 2 ;;
      *) die "unknown option for dump: $1" ;;
    esac
  done

  local udid flag container scheme bundle_out
  udid=$(resolve_device "$device")
  flag=$(cfg container_flag); container=$(cfg container); scheme=$(cfg scheme)
  bundle_out="$RESULTS_DIR/dump.xcresult"
  rm -rf "$bundle_out" "$DUMPS_DIR/latest"
  boot_device "$udid"

  SIMCTL_CHILD_LW_ROUTE="$route" \
  xcodebuild "$flag" "$container" -scheme "$scheme" \
    -destination "platform=iOS Simulator,id=$udid" \
    -only-testing:"$uitest/HierarchyDumpTests" \
    -resultBundlePath "$bundle_out" \
    LW_ROUTE="$route" LW_SEED="$seed" \
    test >"$ART_DIR/dump.log" 2>&1 || {
      echo "sim: dump test FAILED. Last 40 lines of $ART_DIR/dump.log:" >&2
      tail -40 "$ART_DIR/dump.log" >&2
      exit 1
    }

  mkdir -p "$DUMPS_DIR/latest"
  xcrun xcresulttool export attachments --path "$bundle_out" --output-path "$DUMPS_DIR/latest" >/dev/null 2>&1 \
    || die "could not export attachments from $bundle_out"
  echo "hierarchy dump -> $DUMPS_DIR/latest"
  ls "$DUMPS_DIR/latest"
}

cmd_flow() {
  ensure_config; ensure_artifacts_dir
  local name="${1:-}"; shift || true
  [ -n "$name" ] || die "usage: sim.sh flow <Name>   (e.g. 'sim.sh flow Invoice' runs InvoiceFlow)"
  local uitest; uitest=$(cfg ui_test_target)
  [ -n "$uitest" ] || die "no UI test target — flows need one (see 'sim.sh doctor')"

  local device="iphone"
  while [ $# -gt 0 ]; do
    case "$1" in
      --device) device="$2"; shift 2 ;;
      *) die "unknown option for flow: $1" ;;
    esac
  done

  local udid flag container scheme bundle_out out_dir
  udid=$(resolve_device "$device")
  flag=$(cfg container_flag); container=$(cfg container); scheme=$(cfg scheme)
  bundle_out="$RESULTS_DIR/${name}Flow.xcresult"
  out_dir="$SHOTS_DIR/flow-$(echo "$name" | tr '[:upper:]' '[:lower:]')"
  rm -rf "$bundle_out" "$out_dir"
  boot_device "$udid"

  xcodebuild "$flag" "$container" -scheme "$scheme" \
    -destination "platform=iOS Simulator,id=$udid" \
    -only-testing:"$uitest/${name}Flow" \
    -resultBundlePath "$bundle_out" \
    test >"$ART_DIR/flow.log" 2>&1 || {
      echo "sim: flow ${name}Flow FAILED. Last 40 lines of $ART_DIR/flow.log:" >&2
      tail -40 "$ART_DIR/flow.log" >&2
      # Still export what was captured — the screenshots up to the failure are
      # usually the fastest way to see what went wrong.
      mkdir -p "$out_dir"
      xcrun xcresulttool export attachments --path "$bundle_out" --output-path "$out_dir" >/dev/null 2>&1 || true
      echo "sim: partial captures -> $out_dir" >&2
      exit 1
    }

  mkdir -p "$out_dir"
  xcrun xcresulttool export attachments --path "$bundle_out" --output-path "$out_dir" >/dev/null 2>&1 \
    || die "flow passed but attachments could not be exported from $bundle_out"
  for f in "$out_dir"/*.png; do [ -f "$f" ] && sips -Z "$SHOT_MAX_PX" "$f" >/dev/null 2>&1 || true; done
  echo "${name}Flow green -> $out_dir"
  ls "$out_dir"
}

cmd_privacy() {
  ensure_config
  local action="${1:-}" ; shift || true
  case "$action" in
    grant|revoke|reset) ;;
    *) die "usage: sim.sh privacy grant|revoke|reset [services] [--device D]" ;;
  esac
  local services="" device="iphone"
  while [ $# -gt 0 ]; do
    case "$1" in
      --device) device="$2"; shift 2 ;;
      *) services="$services $1"; shift ;;
    esac
  done
  [ -n "${services// }" ] || services=$(cfg privacy_grant)
  [ -n "${services// }" ] || services="all"
  local udid bundle svc; udid=$(resolve_device "$device"); bundle=$(cfg bundle_id)
  for svc in $(echo "$services" | tr ',' ' '); do
    xcrun simctl privacy "$udid" "$action" "$svc" "$bundle" >/dev/null 2>&1 \
      && note "$action $svc" || note "could not $action '$svc'"
  done
}

cmd_clean() {
  rm -rf "$SHOTS_DIR" "$DUMPS_DIR" "$RESULTS_DIR" "$ART_DIR"/*.log
  note "cleaned captures (config and DerivedData kept)"
}

usage() {
  sed -n '14,27p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
  exit 1
}

# ---------------------------------------------------------------- dispatch

[ $# -gt 0 ] || usage
sub="$1"; shift
case "$sub" in
  doctor)  cmd_doctor "$@" ;;
  boot)    cmd_boot "$@" ;;
  install) cmd_install "$@" ;;
  open)    cmd_open "$@" ;;
  launch)  cmd_launch "$@" ;;
  shots)   cmd_shots "$@" ;;
  dump)    cmd_dump "$@" ;;
  flow)    cmd_flow "$@" ;;
  privacy) cmd_privacy "$@" ;;
  erase)   cmd_erase "$@" ;;
  clean)   cmd_clean "$@" ;;
  -h|--help|help) usage ;;
  *) die "unknown subcommand: $sub (try: sim.sh help)" ;;
esac
