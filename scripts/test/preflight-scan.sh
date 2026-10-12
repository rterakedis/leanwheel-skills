#!/usr/bin/env bash
# preflight-scan.sh — self-test for appstore-preflight/preflight-scan.sh. Zero model tokens.
#
# The scan replaced four steps of model-run greps, so a rule that silently stops matching is a
# submission blocker nobody hears about. Three synthetic fixtures pin it:
#   clean   generated-Info.plist, every check passes — the negative state of every rule
#   faulty  file Info.plist, every flag on and almost every rule firing at a pinned location
#   sparse  generated + partial file plist: no manifest, no icon, an unmanifested Pod
# Every rule in preflight-facts.tsv must fire on at least one fixture (known-positive control,
# DD-77), every flag must be seen both on and off, and a facts file that drifts from the script
# must stop the scan rather than run it with a dead pattern.
#
# Usage:  bash scripts/test/preflight-scan.sh
# Exit:   0 all checks pass · 1 any check failed

set -uo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SKILL="$ROOT/.claude/skills/appstore-preflight"
S="$SKILL/preflight-scan.sh"
F="$SKILL/preflight-facts.tsv"
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
PASS=0; FAIL=0
TAB="$(printf '\t')"

check() {
  local desc="$1"; shift
  if "$@" >/dev/null 2>&1; then PASS=$((PASS + 1)); echo "ok     $desc"
  else FAIL=$((FAIL + 1)); echo "NOT OK $desc"; fi
}
has()     { printf '%s\n' "$OUT" | grep -qF -- "$1"; }
lacks()   { ! printf '%s\n' "$OUT" | grep -qF -- "$1"; }
fires()   { printf '%s\n' "$OUT" | grep -qE "^FINDING\|[A-Z]+\|[A-Z]+\|$1\|${2:-}"; }   # fires <rule> [loc-prefix]
silent()  { ! printf '%s\n' "$OUT" | grep -qE "^FINDING\|[A-Z]+\|[A-Z]+\|$1\|"; }
judged()  { printf '%s\n' "$OUT" | grep -qE "^JUDGE\|$1\|${2:-}"; }
eq()      { [ "$1" = "$2" ]; }
scan()    { OUT="$(bash "$S" "$W/fx/$1" --xcode-version "$2" 2>"$W/err")"; CODE=$?; printf '%s\n' "$OUT" > "$W/$1.out"; }

# Every line is one of the contract's six shapes, FLAGS appears once, SCAN is last and adds up.
contract() {
  local bad n b h m l
  bad="$(printf '%s\n' "$OUT" | grep -vE '^(INVENTORY\|[a-z-]+\||FINDING\|(BLOCKER|HIGH|MEDIUM|LOW)\|(PLIST|MANIFEST|SIGNING|ASSET|CODE|BEHAVIOR)\|[a-z0-9-]+\|[^|]+\|.|JUDGE\|[a-z-]+\|[^|]+\|.|VERIFY-BY-HAND\|[a-z-]+(:[A-Za-z0-9._-]+)?\|.|FLAGS\||SCAN: )')"
  [ -z "$bad" ] || return 1
  [ "$(printf '%s\n' "$OUT" | grep -c '^FLAGS|')" -eq 1 ] || return 1
  printf '%s\n' "$OUT" | tail -1 | grep -q '^SCAN: ' || return 1
  n="$(printf '%s\n' "$OUT" | grep -c '^FINDING|')"
  b="$(printf '%s\n' "$OUT" | grep -c '^FINDING|BLOCKER|')"; h="$(printf '%s\n' "$OUT" | grep -c '^FINDING|HIGH|')"
  m="$(printf '%s\n' "$OUT" | grep -c '^FINDING|MEDIUM|')";  l="$(printf '%s\n' "$OUT" | grep -c '^FINDING|LOW|')"
  printf '%s\n' "$OUT" | tail -1 | grep -qF "SCAN: $n findings — $b/$h/$m/$l B/H/M/L;"
}
# BLOCKER first: severity ranks never decrease down the FINDING block.
sorted() {
  printf '%s\n' "$OUT" | awk -F'|' '/^FINDING\|/ { r = ($2 == "BLOCKER") ? 1 : ($2 == "HIGH") ? 2 : ($2 == "MEDIUM") ? 3 : 4; if (r < last) exit 1; last = r }'
}
FLAGS_KEYS="cloudkit storekit universal permission-requests account-creation third-party-login att ai-endpoint webview-primary ugc remote-config"
flags_all() { local v="$1" line="FLAGS" k; for k in $FLAGS_KEYS; do line="$line|$k=$v"; done; has "$line"; }

# ---- fixtures + icons (1×1 PNGs scaled to 1024² by sips: one opaque, one with alpha) -----
cp -R "$ROOT/scripts/test/fixtures/preflight" "$W/fx"
printf '%s' 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAADElEQVR4nGMQUDAAAACkAGE0Zn1yAAAAAElFTkSuQmCC' | base64 --decode > "$W/rgb.png"
printf '%s' 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR4nGMQUDD4DwACBAFgjby7cQAAAABJRU5ErkJggg==' | base64 --decode > "$W/rgba.png"
I_CLEAN="$W/fx/clean/App/Assets.xcassets/AppIcon.appiconset"; I_FAULTY="$W/fx/faulty/App/Assets.xcassets/AppIcon.appiconset"
sips -z 1024 1024 "$W/rgb.png"  --out "$I_CLEAN/icon.png"       >/dev/null 2>&1
sips -z 1024 1024 "$W/rgba.png" --out "$I_CLEAN/icon-dark.png"  >/dev/null 2>&1
sips -z 1024 1024 "$W/rgba.png" --out "$I_FAULTY/icon.png"      >/dev/null 2>&1
check "setup: sips produced an opaque and an alpha 1024² icon" \
  sh -c "sips -g hasAlpha '$I_CLEAN/icon.png' | grep -q 'hasAlpha: no' && sips -g hasAlpha '$I_FAULTY/icon.png' | grep -q 'hasAlpha: yes'"

# ---- clean: the negative state of every rule ---------------------------------------------
scan clean 26.1
check "clean: exits 0"                                   eq "$CODE" 0
check "clean: output matches the contract"               contract
check "clean: zero findings"                             has "SCAN: 0 findings — 0/0/0/0 B/H/M/L;"
check "clean: every flag off"                            flags_all no
check "clean: generated-plist key satisfies the camera API" silent purpose-key-missing
check "clean: generated key is listed for judgment"      judged purpose-string "Clean.xcodeproj/project.pbxproj:[0-9]+\|NSCameraUsageDescription"
check "clean: inherited project build number matches the app" lacks "build-number-mismatch"
check "clean: test target's build 99 is not inventoried"  has "INVENTORY|versions|marketing=1.2; build=7;"
check "clean: test target's 9.9-test marketing version ignored" silent marketing-version-shape
check "clean: declared UserDefaults reason satisfies 3b" silent reason-api-undeclared
check "clean: opaque icon passes, alpha dark variant skipped" silent icon-alpha
check "clean: test-dir location/request/web code ignored" lacks "CLLocationManager"
check "clean: #if DEBUG print and shake handler not judged" lacks "JUDGE|log-pii"
check "clean: #if DEBUG shake handler not judged"        lacks "JUDGE|debug-gate"
check "clean: commented UIWebView is not a use"          silent uiwebview
check "clean: entitlement becomes a VERIFY-BY-HAND line" has "VERIFY-BY-HAND|entitlement:com.apple.security.application-groups|"
check "clean: toolchain at the floor passes"             silent sdk-floor

# ---- faulty: every rule it can carry, at a pinned location --------------------------------
scan faulty 15.4
check "faulty: exits 0 (findings are data)"              eq "$CODE" 0
check "faulty: output matches the contract"              contract
check "faulty: BLOCKER first"                            sorted
check "faulty: every flag on"                            flags_all yes
check "faulty: API used + key in neither plist nor settings → BLOCKER" fires purpose-key-missing "App/TripView.swift:12\|CLLocationManager"
check "faulty: IDFA read without the tracking key → BLOCKER" fires purpose-key-missing "App/TripView.swift:17\|advertisingIdentifier"
check "faulty: short purpose string → MEDIUM"            fires purpose-string-generic 'App/Info.plist:11\|NSCameraUsageDescription="Camera"'
check "faulty: unused key → MEDIUM"                      fires purpose-key-unused "App/Info.plist:13\|NSContactsUsageDescription"
check "faulty: required-reason API undeclared → BLOCKER" fires reason-api-undeclared "App/TripView.swift:23\|UserDefaults"
check "faulty: app/extension build mismatch → BLOCKER"   fires build-number-mismatch "Faulty.xcodeproj/project.pbxproj:[0-9]+\|values: App=3, Widget=1 —"
check "faulty: UI-test target's build 9 kept out of it"  lacks "AppUITests=9"
check "faulty: malformed marketing version → BLOCKER"    fires marketing-version-shape 'Faulty.xcodeproj/project.pbxproj:[0-9]+\|"1.0-beta"'
check "faulty: no launch screen → BLOCKER"               fires launch-screen-missing
check "faulty: iPad orientations incomplete → BLOCKER"   fires ipad-orientations "App/Info.plist:[0-9]+\|missing: PortraitUpsideDown, LandscapeRight"
check "faulty: extra device capability → MEDIUM"         fires required-capabilities "App/Info.plist:[0-9]+\|gps"
check "faulty: export-compliance key absent → HIGH"      fires encryption-key-missing
check "faulty: arbitrary loads → MEDIUM"                 fires ats-arbitrary-loads "App/Info.plist"
check "faulty: get-task-allow → HIGH"                    fires get-task-allow "App/App.entitlements"
check "faulty: get-task-allow is not a capability to verify" lacks "entitlement:get-task-allow"
check "faulty: push without aps-environment → HIGH"      fires push-without-aps "App/TripView.swift:24"
check "faulty: CloudKit without schema init → HIGH"      fires cloudkit-schema-init "App/TripView.swift:14"
check "faulty: CloudKit Console deploy is by hand"       has "VERIFY-BY-HAND|cloudkit-deploy|"
check "faulty: alpha icon → BLOCKER"                     fires icon-alpha "App/Assets.xcassets/AppIcon.appiconset/icon.png"
check "faulty: UIWebView → BLOCKER"                      fires uiwebview "App/TripView.swift:15"
check "faulty: Xcode below the floor → BLOCKER, floor filled from facts" fires sdk-floor ".*local Xcode 15.4 — ⚠️VOLATILE: uploads must be built with iOS 26 SDK"
check "faulty: tracking without domains → HIGH"          fires tracking-domains-missing "App/PrivacyInfo.xcprivacy"
check "faulty: tracker SDK without ATT flow → HIGH"      fires tracking-inconsistent ".*tracking SDKs: Adjust"
check "faulty: listed SDK without a local copy is judged" judged listed-sdk ".*Firebase — firebase-ios-sdk 10.0.0"
for t in private-api placeholder-copy debug-gate log-pii display-name ci-toolchain; do
  check "faulty: JUDGE $t"                               judged "$t"
done
check "faulty: release-code token log judged at its line" judged log-pii "App/TripView.swift:27"
questions_once() {  # every JUDGE topic opens with exactly one question line (location "-")
  printf '%s\n' "$OUT" | awk -F'|' '$1 == "JUDGE" { if (!($2 in seen)) { seen[$2] = 1; if ($3 != "-") exit 1 } if ($3 == "-" && $4 !~ /^\+/) q[$2]++ }
    END { for (t in q) if (q[t] != 1) exit 1 }'
}
check "faulty: each JUDGE topic opens with its question, once" questions_once
check "faulty: question carries the facts' severity, floor filled" has "JUDGE|ci-toolchain|-|CI pins an Xcode older than 26 → BLOCKER [SIGNING]"

# ---- sparse: no manifest, no icon, an unmanifested Pod, file-only keys ---------------------
scan sparse 26.1
check "sparse: exits 0"                                  eq "$CODE" 0
check "sparse: output matches the contract"              contract
check "sparse: no manifest → BLOCKER naming the APIs"    fires manifest-missing ".*required-reason APIs used: UserDefaults"
check "sparse: …and no per-API duplicates"               silent reason-api-undeclared
check "sparse: no appiconset → BLOCKER"                  fires icon-missing ".*no AppIcon.appiconset"
check "sparse: Pod without .xcprivacy → BLOCKER"         fires sdk-manifest-missing "Podfile.lock\|Alamofire \(Alamofire 5.6.0\)"
check "sparse: Pod source is not app code"               silent uiwebview
check "sparse: file-plist key satisfies the location API" silent purpose-key-missing
check "sparse: file-plist launch screen satisfies"       silent launch-screen-missing
check "sparse: UIRequiresFullScreen flagged deprecated"  fires requires-fullscreen-deprecated "Sparse.xcodeproj/project.pbxproj"
check "sparse: …and it suppresses the orientation BLOCKER" silent ipad-orientations
check "sparse: non-numeric build → MEDIUM"               fires build-number-shape '.*"12b"'
check "sparse: only universal is on" \
  has "FLAGS|cloudkit=no|storekit=no|universal=yes|permission-requests=no|account-creation=no|third-party-login=no|att=no|ai-endpoint=no|webview-primary=no|ugc=no|remote-config=no"

# ---- coverage: every rule has a known-positive control, every flag both states ------------
emitted="$(cat "$W"/clean.out "$W"/faulty.out "$W"/sparse.out | awk -F'|' '$1 == "FINDING" { print $4 }' | sort -u)"
rules="$(awk -F'\t' '$1 == "rule" { print $2 }' "$F" | sort -u)"
check "coverage: every facts rule fires on some fixture" eq "$(comm -23 <(echo "$rules") <(echo "$emitted") | tr '\n' ' ')" ""
check "coverage: nothing fires that facts doesn't define" eq "$(comm -13 <(echo "$rules") <(echo "$emitted") | tr '\n' ' ')" ""

# ---- protection and single-source facts ----------------------------------------------------
field_guarded() {  # the comment block directly above the rule row carries a FIELD marker
  awk -F'\t' -v id="$1" '/^#/ { blk = blk $0 "\n"; next } /^[ \t]*$/ { blk = ""; next }
    $1 == "rule" && $2 == id { found = 1; exit (blk ~ /<!-- FIELD: /) ? 0 : 1 } END { if (!found) exit 1 }' "$F"
}
check "field: build-number-mismatch sits under a FIELD marker" field_guarded build-number-mismatch
check "field: build-number-shape sits under a FIELD marker"    field_guarded build-number-shape
check "field: moved CFBundleVersion row text kept verbatim"     grep -qF "Same value on the app **and every extension** target (Xcode bumps only the app; mismatch fails upload)" "$F"
perm_doc="$(sed -n 's/^grep -rnE "\(.*\)" \\$/\1/p' "$SKILL/checks-permissions.md" | head -1)"
perm_facts="$(awk -F'\t' '$1 == "flag" && $2 == "permission-requests" { print $3 }' "$F")"
check "field: permission-requests flag == checks-permissions.md grep" eq "$perm_doc" "$perm_facts"
check "facts: currency is a YYYY-MM-DD date" grep -qE "^meta${TAB}currency${TAB}[0-9]{4}-[0-9]{2}-[0-9]{2}$" "$F"

# ---- fail loud: a drifted facts file stops the scan ----------------------------------------
drift() {  # drift <name> <sed-expr> → runs the scan with an edited facts copy; sets CODE/OUT
  sed "$2" "$F" > "$W/$1.tsv"
  OUT="$(bash "$S" "$W/fx/faulty" --facts "$W/$1.tsv" --xcode-version 26 2>"$W/err")"; CODE=$?
}
drift dead-pattern $'s/^purpose\tCLLocationManager\t/purpose\tCLLocationManagr\t/'
check "drift: pattern that misses its probe exits 1"   eq "$CODE" 1
check "drift: …names the pattern"                     grep -qF 'pattern "CLLocationManagr" does not match its probe' "$W/err"
check "drift: …and scans nothing"                     eq "$OUT" ""
drift bad-severity $'s/^rule\tuiwebview\tBLOCKER\t/rule\tuiwebview\tCRITICAL\t/'
check "drift: unknown severity exits 1"               eq "$CODE" 1
drift spaces $'s/^rule\tget-task-allow\tHIGH\tSIGNING\t/rule get-task-allow HIGH SIGNING /'
check "drift: tabs turned to spaces exits 1"          eq "$CODE" 1
check "drift: …naming the field count"                grep -qF "rule row is not TAB-separated" "$W/err"
drift orphan $'$a\\\nrule\tmade-up-rule\tLOW\tCODE\tNothing emits this'
check "drift: rule row nothing emits exits 1"         eq "$CODE" 1
check "drift: …names it"                              grep -qF "in facts, not emitted by the script: made-up-rule" "$W/err"
drift missing $'/^rule\tuiwebview\t/d'
check "drift: rule the script emits but facts lacks exits 1" eq "$CODE" 1
check "drift: …names it"                              grep -qF "emitted by the script, missing from facts: uiwebview" "$W/err"
drift no-question $'/^judge\tlog-pii\t/d'
check "drift: JUDGE topic without a question exits 1" eq "$CODE" 1

# ---- usage --------------------------------------------------------------------------------
mkdir -p "$W/none" "$W/lib" "$W/spm"; echo "notes" > "$W/none/README.txt"
printf 'let package = Package(name: "Lib", targets: [.target(name: "Lib")])\n' > "$W/lib/Package.swift"
printf 'let package = Package(name: "App", products: [.iOSApplication(name: "App")])\n' > "$W/spm/Package.swift"
OUT="$(bash "$S" "$W/none" --xcode-version 26 2>&1)"; CODE=$?
check "usage: no project exits 2"                     eq "$CODE" 2
check "usage: …with the skill's message"              eq "$OUT" "No Apple app project found — nothing to preflight."
OUT="$(bash "$S" "$W/lib" --xcode-version 26 2>&1)"; CODE=$?
check "usage: library-only Package.swift exits 2"     eq "$CODE" 2
OUT="$(bash "$S" "$W/spm" --xcode-version 26 2>&1)"; CODE=$?
check "usage: SwiftPM app exits 0"                 eq "$CODE" 0
check "usage: …its plist checks are judged, not guessed" has "JUDGE|swiftpm-app|"
bash "$S" --bogus >/dev/null 2>&1; CODE=$?
check "usage: unknown flag exits 2"                   eq "$CODE" 2

echo "-- $PASS/$((PASS + FAIL)) checks passed"
[ "$FAIL" -eq 0 ]
