#!/usr/bin/env bash
# sim.sh — deterministic iOS/iPadOS Simulator harness for leanwheel.
#
# One shell command per intent. The caller (human or agent) runs a subcommand and
# reads the resulting PNGs / text — never reasons from a screenshot to a tap
# coordinate. There are NO coordinate taps anywhere in this script, and none are
# permitted in any flow it runs.
#
# Navigation is ALWAYS by named route, never by tapping. Unattended runs deliver the
# route as a `--route <name>` launch argument, dispatched in-process to the same route
# table `.onOpenURL` uses — because iOS 26 gates every externally-opened custom-scheme
# URL behind an "Open in <App>?" system alert that no unattended run can tap.
# `sim.sh open` still uses simctl openurl: it targets a running app with a human
# watching, who can tap Open. Data state is set by the `--seed` launch argument. Both
# halves of that contract live in docs/setup/swift/testability.md; the host-side
# reference is docs/setup/swift/simulator.md.
#
# Subcommands:
#   doctor                    Check toolchain, config, device, scheme, URL scheme.
#   boot [--fresh]            Boot the simulator (idempotent) + open Simulator.app.
#                             --fresh restarts it first, clearing wedged system alerts.
#   install                   Build for the simulator and install the app.
#   open <route>              Deep-link the RUNNING app (ATTENDED — iOS 26 shows an
#                             "Open in …?" alert a human must tap).
#   launch [--seed S] [--route R] [--orientation O]   Cold launch, optionally seeded,
#                             routed, and rotated (O: portrait|landscape|landscape-left|
#                             landscape-right).
#   shots <name> [--route R] [--orientation O]  Screenshot matrix: appearance x text
#                             size x device. Orientation is a single flag per
#                             invocation, not a matrix axis.
#   dump [--route R] [--orientation O]   Dump the accessibility hierarchy (identifiers).
#   flow <Name> [--orientation O]        Run one named XCUITest flow, export its
#                             screenshots.
#   privacy grant|reset [svc] Pre-grant permission alerts so a run doesn't stall.
#   erase                     Wipe the simulator (destructive) when it is wedged.
#   clean                     Remove captured artifacts.
#
# Config is cached in .leanwheel/sim.json on first run (deriving it needs a slow
# xcodebuild call). It holds only project-scoped values — no absolute paths — so it is
# safe to commit; delete it to re-derive. Artifacts land in .leanwheel/sim/, which
# self-ignores via its own .gitignore.
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
# Screenshots are downscaled to this longest edge (2.9MB -> ~0.4MB) so an agent can
# read them back cheaply. Set SHOT_MAX_PX=native in the environment to keep the raw
# capture — marketing/App Store assets need the native pixels, agents do not.
SHOT_MAX_PX="${SHOT_MAX_PX:-1000}"
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
  #
  # REGRESSION GUARD — search RELATIVE to PROJECT_DIR, never absolute. `find` matches
  # -path against the WHOLE path, so `find "$PROJECT_DIR" … -not -path "*/.*"` with an
  # absolute PROJECT_DIR excludes every project living under ANY hidden ancestor —
  # including .claude/worktrees/<slug>, which is exactly where this framework's own Git
  # Workflow tells you to work. Symptom was a wrong-looking hard error ("no .xcodeproj
  # or .xcworkspace found") in a directory that plainly contains one. Searching from `.`
  # keeps the real intent — skip ./.build, ./.git — without swallowing the tree.
  local ws proj
  ws=$(cd "$PROJECT_DIR" 2>/dev/null && /usr/bin/find . -maxdepth 3 -name "*.xcworkspace" -not -path "*/.*" -not -path "*xcodeproj*" 2>/dev/null | head -1)
  if [ -n "$ws" ]; then echo "-workspace|${ws#./}"; return 0; fi
  proj=$(cd "$PROJECT_DIR" 2>/dev/null && /usr/bin/find . -maxdepth 3 -name "*.xcodeproj" -not -path "*/.*" 2>/dev/null | head -1)
  if [ -n "$proj" ]; then echo "-project|${proj#./}"; return 0; fi
  return 1
}

container_path() {
  # sim.json stores a PROJECT_DIR-relative container so the file carries no
  # machine-specific value and can be committed. Tolerate an absolute path written by
  # an older sim.sh.
  local c; c=$(cfg container)
  [ -n "$c" ] || return 1
  case "$c" in /*) echo "$c" ;; *) echo "$PROJECT_DIR/$c" ;; esac
}

derive_config() {
  require_xcode
  local pair flag container_rel container scheme uitest bundle_id product plist srcroot url_scheme
  local tmp list_json bs_json root

  pair=$(find_container) || die "no .xcodeproj or .xcworkspace found under $PROJECT_DIR"
  flag="${pair%%|*}"; container_rel="${pair#*|}"; container="$PROJECT_DIR/$container_rel"

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

  # Every value written here is project-scoped, never machine-scoped: `container` is
  # relative to the repo root and the build output path is derived at use time from
  # $ART_DIR. That is deliberate — simulator.md tells you to edit `devices` here, which
  # only makes sense if the file is shareable. An absolute container path or a
  # DerivedData path would break on every other machine, and on the very next merge.
  mkdir -p "$(dirname "$CONFIG")"
  cat > "$CONFIG" <<EOF
{
  "container_flag": "$flag",
  "container": "$container_rel",
  "scheme": "$scheme",
  "bundle_id": "$bundle_id",
  "product": "$product",
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

ensure_config() {
  if [ ! -f "$CONFIG" ]; then derive_config; return; fi
  # Self-heal a config that no longer points at anything — an absolute container path
  # written by an older sim.sh (or one recorded inside a worktree that has since been
  # removed). Re-deriving is ~20s; a stale path is a confusing hard failure.
  local c; c=$(container_path || true)
  if [ -z "$c" ] || [ ! -e "$c" ]; then
    note "config container '$(cfg container)' no longer exists — re-deriving"
    rm -f "$CONFIG"; derive_config
  fi
}

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
  # sim.sh always builds into its own DerivedData under $ART_DIR, so the .app location
  # is derivable and does not need to be recorded (a recorded DerivedData path is
  # machine-specific and goes stale the moment Xcode rehashes the project).
  local product; product=$(cfg product)
  [ -n "$product" ] || die "product missing from $CONFIG — delete it and re-run to re-derive"
  echo "$ART_DIR/DerivedData/Build/Products/Debug-iphonesimulator/$product"
}

build_and_install() {
  local udid="$1" flag container scheme app
  flag=$(cfg container_flag); container=$(container_path); scheme=$(cfg scheme)
  note "building $scheme..."
  xcodebuild "$flag" "$container" -scheme "$scheme" \
    -destination "platform=iOS Simulator,id=$udid" \
    -derivedDataPath "$ART_DIR/DerivedData" \
    build >"$ART_DIR/build.log" 2>&1 || {
      echo "sim: build FAILED. Last 40 lines of $ART_DIR/build.log:" >&2
      tail -40 "$ART_DIR/build.log" >&2
      exit 1
    }
  app="$(app_path)"
  [ -d "$app" ] || die "built, but no .app found at $app"
  xcrun simctl install "$udid" "$app" || die "simctl install failed for $app"
  note "installed $(cfg bundle_id)"

  # Absorb the first launch. The app seeds `AppSettings` synchronously precisely so the
  # onboarding cover never latches, but that is a race and a *cold* first launch after an
  # install is the slowest startup there is — which is when it loses. The result is a
  # perfectly clean screenshot of the Welcome screen, and nothing in the output says so.
  # This is not hypothetical: `app-route-light.png` shipped to the marketing site that way.
  #
  # A throwaway launch costs a couple of seconds and moves every subsequent capture off the
  # cold path. It does not *fix* the race — that belongs in the app (see docs/deferred-items,
  # onboarding-latch race) — it just stops the harness from being the thing that triggers it.
  local bundle; bundle=$(cfg bundle_id)
  xcrun simctl launch "$udid" "$bundle" --uitest --seed typical >/dev/null 2>&1 || true
  sleep 3
  xcrun simctl terminate "$udid" "$bundle" >/dev/null 2>&1 || true
}

# ---------------------------------------------------------------- orientation
#
# There is NO host-side orientation control. `xcrun simctl ui` supports only
# appearance / increase_contrast / content_size (verified on Xcode 26.6), and no other
# simctl subcommand rotates a device. Orientation therefore rides the same two
# channels every other setting uses:
#   * shots/launch  -> `--orientation <O>` LAUNCH ARGUMENT, applied by the app's DEBUG
#                      launch-argument handler (UIWindowScene.requestGeometryUpdate) —
#                      the same contract as --seed/--route.
#   * dump/flow     -> TEST_RUNNER_LW_ORIENTATION env var; the shared launch() helper
#                      sets XCUIDevice.shared.orientation (see REGRESSION GUARD in
#                      cmd_dump for why TEST_RUNNER_ is the only working delivery).
# Both halves are documented in docs/setup/swift/simulator.md (Orientation).
#
# The app-side path can silently ignore the argument (an app that never implemented
# the handler just launches portrait), so `shots` VERIFIES every capture's aspect
# ratio against the requested orientation and dies on mismatch — a wrong-orientation
# capture must be a hard error, never a quietly-wrong artifact.

normalize_orientation() {
  # normalize_orientation <value> -> canonical token, or die.
  case "$1" in
    portrait)                       echo "portrait" ;;
    landscape|landscape-left)       echo "landscape-left" ;;
    landscape-right)                echo "landscape-right" ;;
    *) die "unknown orientation '$1' — use portrait, landscape, landscape-left, or landscape-right" ;;
  esac
}

verify_capture_orientation() {
  # verify_capture_orientation <png> <requested-orientation-or-empty>
  local png="$1" want="$2" w h
  [ -n "$want" ] || return 0
  w=$(sips -g pixelWidth  "$png" 2>/dev/null | awk '/pixelWidth/  {print $2}')
  h=$(sips -g pixelHeight "$png" 2>/dev/null | awk '/pixelHeight/ {print $2}')
  [ -n "$w" ] && [ -n "$h" ] || return 0   # unreadable image is capture()'s problem
  case "$want" in
    portrait)    [ "$h" -gt "$w" ] && return 0 ;;
    landscape-*) [ "$w" -gt "$h" ] && return 0 ;;
  esac
  die "requested --orientation $want but the capture is $( [ "$w" -gt "$h" ] && echo landscape || echo portrait ) ($png).

  The app did not honor the --orientation launch argument. There is no simctl command
  that rotates a device, so orientation is an app-side contract: the DEBUG
  launch-argument handler must apply it via UIWindowScene.requestGeometryUpdate.
  See docs/setup/swift/simulator.md (Orientation) for the snippet.
  (Also check the target supports that orientation in its Info.plist / General tab.)"
}

route_url() {
  # route_url <route> — bare routes are prefixed with the app's URL scheme.
  local route="$1" scheme
  case "$route" in *://*) echo "$route"; return 0 ;; esac
  scheme=$(cfg url_scheme)
  [ -n "$scheme" ] || die "this app has no URL scheme registered, so there is no URL to open.
  See 'sim.sh doctor' for the exact Info.plist fix. (Unattended navigation uses the
  --route launch argument and does not need a URL — try 'sim.sh launch --route $route'.)"
  echo "$scheme://$route"
}

open_route() {
  # ATTENDED ONLY. iOS 26 interposes an "Open in <App>?" / Cancel / Open system alert on
  # any custom-scheme URL opened from OUTSIDE the app — including simctl openurl against
  # an already-running, foregrounded app. Until a human taps Open, the URL never reaches
  # .onOpenURL. So this is reachable from `sim.sh open` and nowhere else; unattended
  # paths (launch / shots / dump) deliver the route as a `--route` launch argument.
  local udid="$1" route="$2" url
  url=$(route_url "$route")
  xcrun simctl openurl "$udid" "$url" || die "openurl failed for $url — is the route handled in .onOpenURL?"
  note "iOS 26 will show an \"Open in …?\" alert — tap Open in the Simulator to complete the navigation."
  sleep "$SETTLE"
}

# ---------------------------------------------------------------- staleness guard

newest_source_mtime() {
  # Epoch seconds of the most recently modified source file, or empty if none found.
  # Hidden directories are pruned, which also skips .leanwheel/ artifacts and .git.
  ( cd "$PROJECT_DIR" 2>/dev/null || exit 0
    /usr/bin/find . -path './.*' -prune -o \
      \( -name '*.swift' -o -name '*.m' -o -name '*.h' -o -name '*.xcstrings' \
         -o -name '*.pbxproj' -o -name '*.storyboard' -o -name '*.xib' \) \
      -print0 2>/dev/null \
    | xargs -0 /usr/bin/stat -f '%m' 2>/dev/null | sort -rn | head -1 )
}

ensure_fresh_install() {
  # ensure_fresh_install <udid>
  #
  # `shots` and `launch` do NOT build — they launch whatever bundle is already installed
  # (`dump` and `flow` go through xcodebuild, so they are always current). When that bundle
  # is stale the failure is silent and total: every capture looks correct and shows an older
  # app. That is not hypothetical. A website screenshot run on this project produced iPad
  # captures containing a seeded customer record that had been REMOVED for privacy reasons
  # several commits earlier, and nothing in the output hinted at it — the only reason it was
  # caught is that a human recognised the name.
  #
  # Comparing the installed binary's timestamp against the newest source file is cheap and
  # catches the case that matters. It can false-positive (a `git checkout` restamps files
  # without changing them), which is why the fix is one command and there is an override —
  # but the default has to be refusing to capture rather than capturing a lie.
  [ "${SIM_SKIP_FRESHNESS_CHECK:-0}" = "1" ] && return 0
  local udid="$1" bundle product container binary bin_mtime src_mtime
  bundle=$(cfg bundle_id); product=$(cfg product)
  container=$(xcrun simctl get_app_container "$udid" "$bundle" 2>/dev/null || true)
  if [ -z "$container" ] || [ ! -d "$container" ]; then
    die "$bundle is not installed on this device — there is nothing to launch.
  Fix: scripts/sim.sh install"
  fi
  binary="$container/${product%.app}"
  [ -f "$binary" ] || binary="$container"
  bin_mtime=$(/usr/bin/stat -f '%m' "$binary" 2>/dev/null || echo 0)
  src_mtime=$(newest_source_mtime)
  [ -n "$src_mtime" ] || return 0
  if [ "$src_mtime" -gt "$bin_mtime" ]; then
    die "the installed build is OLDER than your sources — this run would capture a stale app.

  installed: $(/bin/date -r "$bin_mtime" '+%Y-%m-%d %H:%M' 2>/dev/null)
  newest source: $(/bin/date -r "$src_mtime" '+%Y-%m-%d %H:%M' 2>/dev/null)

  'shots' and 'launch' never build; they launch what is already on the device, so a stale
  bundle produces correct-looking captures of an old app.

  Fix: scripts/sim.sh install
  Override (rarely the right call): SIM_SKIP_FRESHNESS_CHECK=1 scripts/sim.sh ..."
  fi
}

launch_app() {
  # launch_app <udid> <seed> <uitest:0|1> <reset:0|1> [route] [orientation]
  local udid="$1" seed="$2" uitest="$3" reset="$4" route="${5:-}" orientation="${6:-}" bundle args grant
  bundle=$(cfg bundle_id)
  # Refuse to launch a bundle older than the sources (see ensure_fresh_install).
  ensure_fresh_install "$udid"
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
  # Route is delivered IN-PROCESS at startup, dispatched to the same route table
  # .onOpenURL uses. Not a parallel navigation mechanism — same vocabulary, same
  # handler, different delivery. Delivery had to change because iOS 26 gates every
  # externally-opened custom-scheme URL behind a system confirmation (see open_route).
  [ -n "$route" ] && args="$args --route $route"
  # Orientation is app-side by necessity — no simctl rotates a device (see the
  # orientation section above). Delivered like --seed/--route; verified by `shots`.
  [ -n "$orientation" ] && args="$args --orientation $orientation"
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
  [ "$SHOT_MAX_PX" = native ] || sips -Z "$SHOT_MAX_PX" "$out" >/dev/null 2>&1 || true
}

# ---------------------------------------------------------------- subcommands

cmd_doctor() {
  require_xcode
  echo "Xcode:       $(xcodebuild -version | head -1)  ($(xcode-select -p))"
  ensure_config
  echo "Container:   $(cfg container)   (relative to $PROJECT_DIR)"
  echo "Scheme:      $(cfg scheme)"
  echo "Bundle id:   $(cfg bundle_id)"

  local scheme uitest
  scheme=$(cfg url_scheme)
  if [ -n "$scheme" ]; then
    echo "URL scheme:  $scheme://   (route table registered)"
    echo "             Unattended navigation uses the --route launch argument, which"
    echo "             must dispatch to the same route table as .onOpenURL. On iOS 26,"
    echo "             'sim.sh open' (simctl openurl) raises an \"Open in …?\" alert a"
    echo "             human must tap — that subcommand is attended-only by design."
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
  and dispatch the `--route <name>` launch argument to the SAME route table at
  startup — that is how unattended runs navigate on iOS 26.
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
  local seed="" route="" device="iphone" uitest=0 reset=0 fresh=0 orientation=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --fresh)  fresh=1; shift ;;
      --seed)   seed="$2"; shift 2 ;;
      --route)  route="$2"; shift 2 ;;
      --device) device="$2"; shift 2 ;;
      --grant)  GRANT_OVERRIDE="$2"; shift 2 ;;
      --orientation) orientation=$(normalize_orientation "$2"); shift 2 ;;
      --uitest) uitest=1; shift ;;
      --reset)  reset=1; shift ;;
      *) die "unknown option for launch: $1" ;;
    esac
  done
  local udid; udid=$(resolve_device "$device")
  boot_device "$udid" "$fresh"
  launch_app "$udid" "$seed" "$uitest" "$reset" "$route" "$orientation"
  note "launched${seed:+ --seed $seed}${route:+ --route $route}${orientation:+ --orientation $orientation}"
  [ -n "$orientation" ] && note "orientation is applied by the app's launch-argument handler — 'launch' cannot verify it; 'shots' can (it checks the capture's aspect ratio)."
  return 0
}

cmd_shots() {
  ensure_config; ensure_artifacts_dir
  local name="${1:-}"; shift || true
  [ -n "$name" ] || die "usage: sim.sh shots <name> [--route R] [--seed S] [--devices iphone,ipad] [--orientation portrait|landscape|landscape-left|landscape-right]"

  # Orientation is deliberately a SINGLE FLAG, not a matrix axis. Doubling the matrix
  # would double every run's cost for captures most stories never look at; a landscape
  # set is one more invocation, exactly like a different route.
  local seed="typical" route="" devices="iphone" appearances="light,dark" sizes="large,accessibility-extra-large" fresh=0 orientation=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --fresh)       fresh=1; shift ;;
      --seed)        seed="$2"; shift 2 ;;
      --route)       route="$2"; shift 2 ;;
      --devices)     devices="$2"; shift 2 ;;
      --appearances) appearances="$2"; shift 2 ;;
      --sizes)       sizes="$2"; shift 2 ;;
      --grant)       GRANT_OVERRIDE="$2"; shift 2 ;;
      --orientation) orientation=$(normalize_orientation "$2"); shift 2 ;;
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
    # One cold launch per device, carrying the route. Every subsequent state change in
    # the matrix is a simctl ui toggle, never a relaunch — the appearance x text-size
    # matrix still costs 1 launch per device, not 8.
    launch_app "$udid" "$seed" 1 0 "$route" "$orientation"
    for appearance in $(echo "$appearances" | tr ',' ' '); do
      xcrun simctl ui "$udid" appearance "$appearance" >/dev/null 2>&1 || true
      for size in $(echo "$sizes" | tr ',' ' '); do
        xcrun simctl ui "$udid" content_size "$size" >/dev/null 2>&1 || true
        sleep 1
        case "$size" in accessibility-*) short="axl" ;; *) short="default" ;; esac
        # Filenames carry the orientation only when one was requested, so default
        # (portrait) runs keep the historic <name>-<device>-<appearance>-<size> shape.
        capture "$udid" "$out_dir/${name}-${dev}-${appearance}-${short}${orientation:+-$orientation}.png"
        # Fail LOUDLY if the app ignored --orientation — a portrait capture labeled
        # landscape is exactly the silently-wrong artifact this script must never emit.
        verify_capture_orientation "$out_dir/${name}-${dev}-${appearance}-${short}${orientation:+-$orientation}.png" "$orientation"
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

  local route="" device="iphone" seed="typical" orientation=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --route)  route="$2"; shift 2 ;;
      --seed)   seed="$2"; shift 2 ;;
      --device) device="$2"; shift 2 ;;
      --orientation) orientation=$(normalize_orientation "$2"); shift 2 ;;
      *) die "unknown option for dump: $1" ;;
    esac
  done

  local udid flag container scheme bundle_out
  udid=$(resolve_device "$device")
  flag=$(cfg container_flag); container=$(container_path); scheme=$(cfg scheme)
  bundle_out="$RESULTS_DIR/dump.xcresult"
  rm -rf "$bundle_out" "$DUMPS_DIR/latest"
  boot_device "$udid"

  # REGRESSION GUARD — TEST_RUNNER_<NAME> in xcodebuild's OWN environment is the only
  # supported way to get a value into the XCTest runner's ProcessInfo.environment (it
  # arrives there as <NAME>). Two things that look like they work and do not:
  #   * bare `LW_ROUTE=x` arguments to xcodebuild  -> sets a BUILD SETTING, not an env var
  #   * SIMCTL_CHILD_LW_ROUTE=x                    -> only reaches processes simctl
  #                                                   launches directly; the runner is
  #                                                   launched by xcodebuild
  # Both fail silently: the dump is of the launch screen with the default seed, and
  # nothing anywhere says the route was dropped. Do not "simplify" this back.
  # LW_ORIENTATION rides the same channel; the shared launch() helper applies it via
  # XCUIDevice.shared.orientation (see simulator.md, Orientation).
  TEST_RUNNER_LW_ROUTE="$route" TEST_RUNNER_LW_SEED="$seed" TEST_RUNNER_LW_ORIENTATION="$orientation" \
  xcodebuild "$flag" "$container" -scheme "$scheme" \
    -destination "platform=iOS Simulator,id=$udid" \
    -only-testing:"$uitest/HierarchyDumpTests" \
    -resultBundlePath "$bundle_out" \
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

  local device="iphone" orientation=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --device) device="$2"; shift 2 ;;
      --orientation) orientation=$(normalize_orientation "$2"); shift 2 ;;
      *) die "unknown option for flow: $1" ;;
    esac
  done

  local udid flag container scheme bundle_out out_dir
  udid=$(resolve_device "$device")
  flag=$(cfg container_flag); container=$(container_path); scheme=$(cfg scheme)
  bundle_out="$RESULTS_DIR/${name}Flow.xcresult"
  out_dir="$SHOTS_DIR/flow-$(echo "$name" | tr '[:upper:]' '[:lower:]')"
  rm -rf "$bundle_out" "$out_dir"
  boot_device "$udid"

  # REGRESSION GUARD — same delivery rule as cmd_dump: TEST_RUNNER_<NAME> is the ONLY
  # way a value reaches the XCTest runner's environment. The launch() helper applies
  # LW_ORIENTATION via XCUIDevice.shared.orientation (simulator.md, Orientation).
  TEST_RUNNER_LW_ORIENTATION="$orientation" \
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
  [ "$SHOT_MAX_PX" = native ] || \
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
  # Anchored on the header text, not on line numbers — editing the preamble above must
  # not silently truncate the help output.
  sed -n '/^# Subcommands:/,/^# *clean /p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
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
