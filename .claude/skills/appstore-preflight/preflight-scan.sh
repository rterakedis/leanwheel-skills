#!/usr/bin/env bash
# preflight-scan.sh — appstore-preflight Steps 1–4, mechanised. Zero model tokens.
#
# Executed, never read into context: the skill runs it and reasons over the output. Every
# requirement fact it applies — rule text, severities, ITMS codes, the purpose-string and
# required-reason tables, listed SDKs, the Xcode floor, the Currency date — lives in
# preflight-facts.tsv beside it, the one file /refresh-swift Step 4 edits. This file is
# mechanism only, so a facts refresh never touches it (DD-79).
#
# Usage:  bash preflight-scan.sh [project-root] [--facts <tsv>] [--xcode-version <major>|none]
#   --facts          alternate facts file (self-test seam)
#   --xcode-version  use this Xcode major instead of `xcodebuild -version` (`none` = unavailable)
#
# Output — the contract is canonical in SKILL.md Step 1 and pinned by scripts/test/preflight-scan.sh:
#   INVENTORY|<topic>|<value>
#   FINDING|<BLOCKER|HIGH|MEDIUM|LOW>|<PLIST|MANIFEST|SIGNING|ASSET|CODE|BEHAVIOR>|<rule-id>|<file[:line]>|<message>
#   JUDGE|<topic>|<file[:line]>|<excerpt>      found mechanically; the verdict needs the model.
#                                              Each topic opens with JUDGE|<topic>|-|<question>
#   VERIFY-BY-HAND|<id>|<text>                 not visible in the repo → a checklist item
#   FLAGS|cloudkit=yes|no|storekit=…|…         branch routing (Step 5 branch files, Step 7 render)
#   SCAN: <n> findings — <B>/<H>/<M>/<L> B/H/M/L; <j> judge, <v> verify-by-hand; flags <yes-list|none>
# Findings print BLOCKER first. The last field of every line is free text and may contain "|".
#
# Exit: 0 scan completed (findings are data) · 1 facts file malformed or out of step with this
#       script — nothing scanned · 2 usage, missing macOS tooling, or no Apple app project
#
# macOS bash 3.2: no mapfile, no associative arrays, no ${var,,}, no jq/python/timeout.
# Needs plutil (and sips for the icon check), both shipped with macOS.

set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
FACTS="$HERE/preflight-facts.tsv"
ROOT="."; ROOT_SET=0; XCODE_OVERRIDE=""

usage() { sed -n '10,12p' "$0" >&2; exit 2; }
while [ $# -gt 0 ]; do
  case "$1" in
    --facts)         FACTS="${2:-}"; shift 2 ;;
    --xcode-version) XCODE_OVERRIDE="${2:-}"; shift 2 ;;
    -h|--help)       usage ;;
    -*)              echo "unknown arg: $1" >&2; usage ;;
    *)               [ "$ROOT_SET" = 1 ] && usage; ROOT="$1"; ROOT_SET=1; shift ;;
  esac
done
[ -d "$ROOT" ] || { echo "not a directory: $ROOT" >&2; exit 2; }
[ -f "$FACTS" ] || { echo "facts file not found: $FACTS" >&2; exit 1; }
command -v plutil >/dev/null 2>&1 || { echo "preflight-scan needs macOS plutil" >&2; exit 2; }
FACTS="$(cd "$(dirname "$FACTS")" && pwd)/$(basename "$FACTS")"
cd "$ROOT" || exit 2

W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
TAB="$(printf '\t')"
JUDGE_CAP=15

# ---------------------------------------------------------------------------
# What this script emits. The facts file must define exactly these — a rule here with no row
# is a crash waiting to happen, a row with no emitter is a gate that can never fire (DD-77).
# ---------------------------------------------------------------------------
RULES_USED="purpose-key-missing purpose-string-generic purpose-key-unused manifest-missing
reason-api-undeclared sdk-manifest-missing tracking-domains-missing tracking-inconsistent
encryption-key-missing marketing-version-shape build-number-mismatch build-number-shape
icon-missing icon-alpha launch-screen-missing ipad-orientations requires-fullscreen-deprecated
required-capabilities get-task-allow push-without-aps cloudkit-schema-init ats-arbitrary-loads
sdk-floor uiwebview"
PATTERNS_USED="push cloudkit-schema-init swiftdata-container uiwebview private-api placeholder-copy
debug-gate log-pii display-name ci-xcode on-device-ai"
FLAGS_ORDER="cloudkit storekit universal permission-requests account-creation third-party-login
att ai-endpoint webview-primary ugc remote-config"
FLAGS_FROM_CODE="cloudkit storekit permission-requests account-creation third-party-login att
ai-endpoint webview-primary ugc remote-config"
VERIFY_USED="entitlement distribution-profile marketing-version-order cloudkit-deploy toolchain icon"
META_USED="currency sdk-floor"
JUDGE_USED="purpose-string listed-sdk display-name placeholder-copy private-api debug-gate log-pii
ci-toolchain unresolved-setting ipad-orientations icon swiftpm-app"

# ---------------------------------------------------------------------------
# 0. Validate the facts file — fail loud before scanning anything
# ---------------------------------------------------------------------------
awk -F'\t' '
  function err(m) { printf "preflight-facts.tsv:%d: %s\n", NR, m > "/dev/stderr"; bad = 1 }
  BEGIN {
    n = split("meta 3 rule 5 purpose 5 reason 5 sdk 4 tracker 4 flag 4 depflag 4 pattern 4 verify 3 judge 3", a, " ")
    for (i = 1; i < n; i += 2) nf[a[i]] = a[i + 1]
    split("BLOCKER HIGH MEDIUM LOW", s, " "); for (i in s) sev[s[i]] = 1
    split("PLIST MANIFEST SIGNING ASSET CODE BEHAVIOR", c, " "); for (i in c) sc[c[i]] = 1
  }
  /^#/ || /^[ \t]*$/ { next }
  {
    k = $1
    if (!(k in nf)) {
      w = k; sub(/[ ].*/, "", w)
      if (w in nf) err(w " row is not TAB-separated (tabs turned into spaces?)"); else err("unknown kind \"" k "\"")
      next
    }
    if (NF != nf[k]) { err(k " row has " NF " fields, expected " nf[k] " (TAB-separated)"); next }
    for (i = 1; i <= NF; i++) if ($i == "") err("empty field " i)
    if (k == "rule") {
      if (!($3 in sev)) err("unknown severity \"" $3 "\"")
      if (!($4 in sc)) err("unknown scope \"" $4 "\"")
      if ($5 ~ /\|/) err("rule message may not contain |")
    }
    if (k ~ /^(rule|meta|pattern|verify|flag|judge)$/) { if ((k, $2) in seen) err("duplicate " k " \"" $2 "\""); seen[k, $2] = 1 }
  }
  END { exit bad }
' "$FACTS" || { echo "preflight-scan: facts file is malformed — fix it before scanning" >&2; exit 1; }

grep -vE '^#|^[[:space:]]*$' "$FACTS" > "$W/facts"
ids_of() { awk -F'\t' -v k="$1" '$1 == k { print $2 }' "$W/facts" | sort -u; }
words()  { printf '%s\n' $1 | sort -u; }
same_set() {  # same_set <kind> <expected words>
  local d
  d="$(diff <(ids_of "$1") <(words "$2") | grep '^[<>]' | sed 's/^</in facts, not emitted by the script:/; s/^>/emitted by the script, missing from facts:/')"
  [ -z "$d" ] && return 0
  printf 'preflight-facts.tsv: %s rows out of step — %s\n' "$1" "$d" >&2; return 1
}
DRIFT=0
same_set rule "$RULES_USED" || DRIFT=1
same_set pattern "$PATTERNS_USED" || DRIFT=1
same_set flag "$FLAGS_FROM_CODE" || DRIFT=1
same_set verify "$VERIFY_USED" || DRIFT=1
same_set judge "$JUDGE_USED" || DRIFT=1
same_set meta "$META_USED" || DRIFT=1
for f in $(awk -F'\t' '$1 == "depflag" { print $2 }' "$W/facts"); do
  case " $(echo $FLAGS_FROM_CODE) " in *" $f "*) ;; *) echo "preflight-facts.tsv: depflag for unknown flag \"$f\"" >&2; DRIFT=1 ;; esac
done

# Per-row positive control: each pattern must match its own probe, with the same grep the scan uses.
while IFS="$TAB" read -r kind a b c d; do
  case "$kind" in
    purpose|reason) re="$a"; probe="$d"; ci="" ;;
    flag|pattern)   re="$b"; probe="$c"; ci="" ;;
    sdk|tracker)    re="$a"; probe="$c"; ci="-i" ;;
    depflag)        re="$b"; probe="$c"; ci="-i" ;;
    *) continue ;;
  esac
  if ! printf '%s\n' "$probe" | grep -qE $ci -- "$re" 2>/dev/null; then
    echo "preflight-facts.tsv: $kind pattern \"$re\" does not match its probe \"$probe\"" >&2; DRIFT=1
  fi
done < "$W/facts"
[ "$DRIFT" = 0 ] || { echo "preflight-scan: facts file and script are out of step — nothing scanned" >&2; exit 1; }

meta()    { awk -F'\t' -v k="$1" '$1 == "meta" && $2 == k { print $3; exit }' "$W/facts"; }
pattern() { awk -F'\t' -v k="$1" '$1 == "pattern" && $2 == k { print $3; exit }' "$W/facts"; }
CURRENCY="$(meta currency)"; SDK_FLOOR="$(meta sdk-floor)"
fill() { local t="$1"; t="${t//\{sdk-floor\}/$SDK_FLOOR}"; t="${t//\{key\}/${2:-}}"; t="${t//\{value\}/${2:-}}"; printf '%s' "$t"; }

# ---------------------------------------------------------------------------
# Emitters
# ---------------------------------------------------------------------------
: > "$W/findings"; : > "$W/judge"; : > "$W/verify"; : > "$W/inventory"
finding() {  # finding <rule-id> <file[:line]> [detail]
  local row sev scope msg rank
  row="$(awk -F'\t' -v id="$1" '$1 == "rule" && $2 == id { print $3 "\t" $4 "\t" $5; exit }' "$W/facts")"
  sev="${row%%"$TAB"*}"; row="${row#*"$TAB"}"; scope="${row%%"$TAB"*}"; msg="$(fill "${row#*"$TAB"}")"
  [ -n "${3:-}" ] && msg="$3 — $msg"
  case "$sev" in BLOCKER) rank=1 ;; HIGH) rank=2 ;; MEDIUM) rank=3 ;; *) rank=4 ;; esac
  printf '%s\t%s\n' "$rank" "FINDING|$sev|$scope|$1|${2:--}|$msg" >> "$W/findings"
}
judge()  { printf 'JUDGE|%s|%s|%s\n' "$1" "${2:--}" "$3" >> "$W/judge"; }
verify() {  # verify <id> [key/value] [suffix-for-id]
  local t; t="$(awk -F'\t' -v id="$1" '$1 == "verify" && $2 == id { print $3; exit }' "$W/facts")"
  printf 'VERIFY-BY-HAND|%s|%s\n' "$1${3:+:$3}" "$(fill "$t" "${2:-}")" >> "$W/verify"
}
inv()    { printf 'INVENTORY|%s|%s\n' "$1" "${2:-none}" >> "$W/inventory"; }
joined() { awk 'NF && !seen[$0]++' | paste -sd, - | sed 's/,/, /g'; }
orn()    { local s; s="$(cat)"; printf '%s' "${s:-none}"; }
excerpt() { printf '%s' "$1" | sed 's/^[[:space:]]*//' | cut -c1-120; }

# ---------------------------------------------------------------------------
# 1. Inventory
# ---------------------------------------------------------------------------
find . \( -name DerivedData -o -name .build -o -name Pods -o -name Carthage -o -name .git \
          -o -name node_modules -o -name SourcePackages \) -prune -o -type f -print 2>/dev/null \
  | sed 's#^\./##' | LC_ALL=C sort > "$W/all"
not_test()    { grep -vE '(^|/)[^/]*Tests/' ; }
not_bundled() { grep -vE '\.(framework|xcframework|bundle|app|appex)/' ; }
pick() { grep -E "$1" "$W/all" | not_bundled; }

pick '\.(swift|m|mm)$' | not_test > "$W/src"
pick '\.swift$' > "$W/src_all"
pick '(^|/)([^/]*-)?Info\.plist$' | grep -v '\.xcassets/' | not_test > "$W/plists"
pick '\.xcodeproj/project\.pbxproj$' > "$W/pbx"
pick '\.entitlements$' | not_test > "$W/ent"
pick '(^|/)PrivacyInfo\.xcprivacy$' | not_test > "$W/manifests"
pick '(^|/)(Package\.resolved|Podfile\.lock)$' > "$W/resolved"
pick '\.storekit$' > "$W/storekit"
pick '\.xcconfig$' | not_test > "$W/xcconfig"
pick '\.(strings|xcstrings)$' | not_test > "$W/strings"
grep -E '^(\.github/workflows/.*\.ya?ml|\.gitlab-ci\.yml|bitrise\.yml|codemagic\.yaml|\.xcode-version|ci_scripts/.*|fastlane/Fastfile|Jenkinsfile|\.circleci/config\.yml)$' "$W/all" > "$W/ci"
find . -maxdepth 3 \( -name "*.xcodeproj" -o -name "*.xcworkspace" \) ! -path "*/DerivedData/*" \
  ! -path "*.xcodeproj/*" 2>/dev/null | sed 's#^\./##' | LC_ALL=C sort > "$W/projects"
SPM_APP=""
[ -f Package.swift ] && grep -q 'iOSApplication' Package.swift && SPM_APP="Package.swift"

if [ ! -s "$W/projects" ] && [ -z "$SPM_APP" ]; then
  echo "No Apple app project found — nothing to preflight."; exit 2
fi

src_hits() {  # src_hits <ERE> [list] → file:line:content, comment lines dropped
  local list="${2:-$W/src}"
  [ -s "$list" ] || return 0
  tr '\n' '\0' < "$list" | xargs -0 grep -nHE -- "$1" 2>/dev/null \
    | grep -vE '^[^:]*:[0-9]+:[[:space:]]*(//|/\*|\*)' || true
}
hit_loc()   { local r="${1#*:}"; printf '%s:%s' "${1%%:*}" "${r%%:*}"; }
hit_text()  { local r="${1#*:}"; printf '%s' "${r#*:}"; }
hit_token() { hit_text "$1" | grep -oE -- "$2" | head -1; }

# Lines inside an `#if DEBUG` branch (or the #else of `#if !DEBUG`) are not release code.
in_debug() {  # in_debug <file> <line> → exit 0 when inside
  awk -v want="$2" '
    /^[ \t]*#if/    { d++; dbg[d] = ($0 ~ /DEBUG/) ? (($0 ~ /![ \t]*DEBUG/) ? -1 : 1) : 0; br[d] = 1 }
    /^[ \t]*#else/  { if (d) br[d] = 0 }
    /^[ \t]*#endif/ { if (d) d-- }
    FNR == want { for (i = 1; i <= d; i++) if ((dbg[i] == 1 && br[i]) || (dbg[i] == -1 && !br[i])) exit 0; exit 1 }
  ' "$1"
}
release_hits() { while IFS= read -r h; do r="${h#*:}"; in_debug "${h%%:*}" "${r%%:*}" || printf '%s\n' "$h"; done; }

# ---- project.pbxproj → one row per effective build setting --------------------------------
# kind (app|ext|test|other|project) · target · config · key · value · line · file
: > "$W/cfg"
while IFS= read -r pbx; do
  awk -v file="$pbx" '
    function trim(s) { sub(/^[ \t]+/, "", s); sub(/[ \t]+$/, "", s); return s }
    function unq(s)  { s = trim(s); sub(/;$/, "", s); s = trim(s); if (s ~ /^".*"$/) s = substr(s, 2, length(s) - 2); return s }
    BEGIN { OFS = "\t" }
    {
      line = $0
      if (inset) {
        if (inarr) { if (line ~ /\);[ \t]*$/) inarr = 0; next }
        if (line ~ /^[ \t]*};[ \t]*$/) { inset = 0; next }
        p = index(line, " = ")
        if (p > 0) {
          k = unq(substr(line, 1, p - 1)); v = substr(line, p + 3)
          if (v ~ /^\([ \t]*$/) { inarr = 1; v = "(array)" } else v = unq(v)
          if (!((cur, k) in V)) { nk[cur]++; K[cur, nk[cur]] = k }
          V[cur, k] = v; L[cur, k] = FNR
        }
        next
      }
      if (inlist) {
        if (line ~ /\)/) { inlist = 0; next }
        id = trim(line); sub(/[ \t,].*/, "", id); if (id != "") members[cur] = members[cur] " " id
        next
      }
      if (line ~ /^[ \t]*[A-Za-z0-9_]+ (\/\*.*\*\/ )?= \{[ \t]*$/) {
        id = trim(line); sub(/[ \t].*/, "", id)
        if (id == "buildSettings") { inset = 1; inarr = 0 } else { cur = id }
        next
      }
      if (line ~ /^[ \t]*isa = [A-Za-z]+;[ \t]*$/) { t = line; sub(/.*isa = /, "", t); sub(/;.*/, "", t); isa[cur] = t; next }
      if (line ~ /^[ \t]*buildConfigurations = \(/) { inlist = 1; next }
      if (line ~ /^[ \t]*buildConfigurationList = /) { t = trim(line); sub(/^buildConfigurationList = /, "", t); sub(/[ \t;].*/, "", t); clist[cur] = t; next }
      if (line ~ /^[ \t]*productType = /) { t = line; sub(/.*productType = /, "", t); ptype[cur] = unq(t); next }
      if (line ~ /^[ \t]*name = [^;]*;[ \t]*$/) { t = line; sub(/.*name = /, "", t); nm[cur] = unq(t); next }
    }
    END {
      for (o in clist) {
        l = clist[o]
        if (isa[o] == "PBXProject") { lkind[l] = "project"; ltarget[l] = "(project)" }
        else if (isa[o] ~ /Target$/) {
          pt = ptype[o]
          lkind[l] = (pt ~ /test/) ? "test" : (pt ~ /extension/) ? "ext" : (pt ~ /application/) ? "app" : "other"
          ltarget[l] = nm[o]
        }
      }
      for (l in members) { n = split(members[l], m, " "); for (i = 1; i <= n; i++) { ck[m[i]] = lkind[l]; ct[m[i]] = ltarget[l] } }
      for (c in isa) if (isa[c] == "XCBuildConfiguration" && ck[c] == "project") projcfg[nm[c]] = c
      for (c in isa) {
        if (isa[c] != "XCBuildConfiguration") continue
        k = ck[c]; tg = ct[c]
        if (k == "") {   # not reachable from any target or project list: infer
          k = ((c, "PRODUCT_BUNDLE_IDENTIFIER") in V) ? "app" : "project"
          tg = ((c, "PRODUCT_NAME") in V) ? V[c, "PRODUCT_NAME"] : "(unlisted)"
        }
        if (((c, "TEST_HOST") in V) || ((c, "BUNDLE_LOADER") in V)) k = "test"
        print k, tg, nm[c], "_", "_", 0, file
        for (i = 1; i <= nk[c]; i++) { key = K[c, i]; print k, tg, nm[c], key, V[c, key], L[c, key], file }
        if (k != "project" && (nm[c] in projcfg)) {
          p = projcfg[nm[c]]
          for (i = 1; i <= nk[p]; i++) { key = K[p, i]; if (!((c, key) in V)) print k, tg, nm[c], key, V[p, key], L[p, key], file }
        }
      }
    }
  ' "$pbx" >> "$W/cfg"
done < "$W/pbx"
LC_ALL=C sort -o "$W/cfg" "$W/cfg"

cfg_rows() {  # cfg_rows <key-ERE> [kinds-ERE] → value \t file:line \t target \t key
  awk -F'\t' -v k="^($1)\$" -v kr="^(${2:-app|ext})\$" '$4 ~ k && $1 ~ kr { print ($5 == "" ? "(empty)" : $5) "\t" $7 ":" $6 "\t" $2 "\t" $4 }' "$W/cfg"
}

# ---- Info.plist files → app | ext ---------------------------------------------------------
pl_has()     { plutil -extract "$2" xml1 -o - "$1" >/dev/null 2>&1; }
pl_raw()     { plutil -extract "$2" raw -o - "$1" 2>/dev/null; }
pl_strings() { plutil -extract "$2" xml1 -o - "$1" 2>/dev/null | sed -n 's/.*<string>\(.*\)<\/string>.*/\1/p'; }
pl_loc()     { local n; n="$(grep -nF "<key>$2</key>" "$1" 2>/dev/null | head -1 | cut -d: -f1)"; printf '%s%s' "$1" "${n:+:$n}"; }
: > "$W/plist_app"; : > "$W/plist_ext"
while IFS= read -r p; do
  if pl_has "$p" NSExtension || pl_has "$p" EXAppExtensionAttributes; then echo "$p" >> "$W/plist_ext"
  else echo "$p" >> "$W/plist_app"; fi
done < "$W/plists"
cat "$W/plist_app" "$W/plist_ext" > "$W/plist_appext"

HAS_APP=0
{ [ -s "$W/plist_app" ] || awk -F'\t' '$1 == "app" { f = 1 } END { exit !f }' "$W/cfg"; } && HAS_APP=1
PRIMARY="$(head -1 "$W/pbx")"; [ -n "$PRIMARY" ] || PRIMARY="$(head -1 "$W/plist_app")"
[ -n "$PRIMARY" ] || PRIMARY="${SPM_APP:-$(head -1 "$W/projects")}"

# key_sources <plist-key> [files] → value \t location, from Info.plist files and INFOPLIST_KEY_*
key_sources() {
  local f files="${2:-$W/plist_appext}"
  while IFS= read -r f; do pl_has "$f" "$1" || continue; v="$(pl_raw "$f" "$1")"; printf '%s\t%s\n' "${v:-(empty)}" "$(pl_loc "$f" "$1")"; done < "$files"
  cfg_rows "INFOPLIST_KEY_$1" | cut -f1,2
}

# ---- dependencies: src \t name \t url \t version \t original-name ---------------------------
: > "$W/deps"
while IFS= read -r r; do
  case "$r" in
    *Package.resolved)
      awk -v f="$r" '
        function val(s) { sub(/^[^:]*:[ \t]*/, "", s); gsub(/[",]/, "", s); return s }
        function flush() { if (name != "") print f "\t" tolower(name) "\t" (url == "" ? "-" : tolower(url)) "\t" (ver == "" ? "-" : ver) "\t" name; name = url = ver = "" }
        /"(identity|package)"[ \t]*:/          { flush(); name = val($0); next }
        /"(location|repositoryURL)"[ \t]*:/    { url = val($0); next }
        /"version"[ \t]*:/                     { if (ver == "") ver = val($0); next }
        END { flush() }' "$r" >> "$W/deps" ;;
    *Podfile.lock)
      awk -v f="$r" '
        /^PODS:/ { inp = 1; next } /^[A-Z]/ { inp = 0 }
        inp && /^  - / {
          s = $0; sub(/^  - /, "", s); sub(/:$/, "", s); n = s; sub(/ \(.*/, "", n); sub(/\/.*/, "", n)
          v = ""; if (s ~ /\(/) { v = s; sub(/.*\(/, "", v); sub(/\).*/, "", v) }
          if (!(n in seen)) { seen[n] = 1; print f "\t" tolower(n) "\t-\t" (v == "" ? "-" : v) "\t" n }
        }' "$r" >> "$W/deps" ;;
  esac
done < "$W/resolved"
dep_match() { awk -F'\t' '{ print $2; if ($3 != "-") print $3 }' "$W/deps" | grep -qiE -- "$1"; }

inv facts "current as of $CURRENCY"
inv projects "$( (cat "$W/projects"; [ -n "$SPM_APP" ] && echo "$SPM_APP (iOSApplication)") | joined)"
inv targets "$(awk -F'\t' '$1 != "project" && $4 == "_" { print $1 ":" $2 }' "$W/cfg" | joined)"
GEN="no"; cfg_rows GENERATE_INFOPLIST_FILE | grep -q '^YES' && GEN="yes"
inv info-plist "generated=$GEN; files: $(joined < "$W/plists" | orn)"
inv privacy-manifests "$(joined < "$W/manifests")"
inv entitlements "$(joined < "$W/ent")"
inv dependencies "$(awk -F'\t' '{ print $5 ($4 != "-" ? " " $4 : "") }' "$W/deps" | joined)"
inv storekit-config "$(joined < "$W/storekit")"
inv on-device-ai "$(src_hits "$(pattern on-device-ai)" | cut -d: -f1 | joined)"
if [ -n "$SPM_APP" ] && [ ! -s "$W/pbx" ]; then
  judge swiftpm-app "$SPM_APP" ".iOSApplication product"
fi

# ---------------------------------------------------------------------------
# 2. Purpose strings
# ---------------------------------------------------------------------------
: > "$W/keys_used"
key_present() { [ -n "$(key_sources "$1" | head -1)" ]; }
awk -F'\t' '$1 == "purpose" { print $2 "\t" $3 "\t" $4 }' "$W/facts" > "$W/purpose"
while IFS="$TAB" read -r re req opt; do
  hit="$(src_hits "$re" | head -1)"
  [ -n "$hit" ] || continue
  printf '%s\n%s\n' "$req" "$opt" | tr '/+' '\n\n' >> "$W/keys_used"
  missing=""
  case "$req" in
    */*) ok=0; for k in $(echo "$req" | tr '/' ' '); do key_present "$k" && ok=1; done
         [ "$ok" = 1 ] || missing="$(echo "$req" | sed 's#/# or #g')" ;;
    *+*) for k in $(echo "$req" | tr '+' ' '); do key_present "$k" || missing="${missing:+$missing + }$k"; done ;;
    *)   key_present "$req" || missing="$req" ;;
  esac
  [ -n "$missing" ] && finding purpose-key-missing "$(hit_loc "$hit")" "$(hit_token "$hit" "$re") → $missing missing"
done < "$W/purpose"

awk -F'\t' '$1 == "purpose" { print $3; print $4 }' "$W/facts" | tr '/+' '\n\n' \
  | grep 'UsageDescription$' | LC_ALL=C sort -u > "$W/keys_known"
: > "$W/keys_present"
while IFS= read -r k; do
  key_sources "$k" | awk -F'\t' '!seen[$1]++' > "$W/ks"
  [ -s "$W/ks" ] || continue
  echo "$k" >> "$W/keys_present"
  while IFS="$TAB" read -r v loc; do
    if [ "${#v}" -lt 20 ]; then finding purpose-string-generic "$loc" "$k=\"$v\""
    else judge purpose-string "$loc" "$k: $v"; fi
  done < "$W/ks"
  grep -qxF "$k" "$W/keys_used" || finding purpose-key-unused "$(head -1 "$W/ks" | cut -f2)" "$k"
done < "$W/keys_known"
inv purpose-keys "$(joined < "$W/keys_present")"

# ---------------------------------------------------------------------------
# 3. Privacy manifest
# ---------------------------------------------------------------------------
: > "$W/declared"
while IFS= read -r m; do
  n=0
  while [ "$n" -lt 100 ] && t="$(plutil -extract "NSPrivacyAccessedAPITypes.$n.NSPrivacyAccessedAPIType" raw -o - "$m" 2>/dev/null)"; do
    pl_strings "$m" "NSPrivacyAccessedAPITypes.$n.NSPrivacyAccessedAPITypeReasons" | grep -qE '^[0-9A-F]{4}\.[0-9]+$' && echo "$t" >> "$W/declared"
    n=$((n + 1))
  done
done < "$W/manifests"

USED_CATS=""
while IFS="$TAB" read -r kind re cat codes probe; do
  [ "$kind" = reason ] || continue
  hit="$(src_hits "$re" | head -1)"
  [ -n "$hit" ] || continue
  USED_CATS="${USED_CATS:+$USED_CATS, }${cat#NSPrivacyAccessedAPICategory}"
  if [ -s "$W/manifests" ] && ! grep -qxF "$cat" "$W/declared"; then
    finding reason-api-undeclared "$(hit_loc "$hit")" "$(hit_token "$hit" "$re") → $cat ($codes)"
  fi
done < "$W/facts"
if [ "$HAS_APP" = 1 ] && [ ! -s "$W/manifests" ]; then
  finding manifest-missing "$PRIMARY" "${USED_CATS:+required-reason APIs used: $USED_CATS}"
fi

# 3c — listed SDKs. A local copy (Pods/, .build/checkouts) can be checked; otherwise the model judges the version.
awk -F'\t' '$1 == "sdk" { print $2 "\t" $3 }' "$W/facts" > "$W/sdks"
while IFS="$TAB" read -r re name; do
  awk -F'\t' '{ print $0 }' "$W/deps" | while IFS="$TAB" read -r src dn du dv orig; do
    printf '%s\n%s\n' "$dn" "$du" | grep -qiE -- "$re" || continue
    copy=""
    for d in "Pods/$orig" ".build/checkouts/$dn" "SourcePackages/checkouts/$dn"; do [ -d "$d" ] && { copy="$d"; break; }; done
    if [ -n "$copy" ]; then
      [ -n "$(find "$copy" -name '*.xcprivacy' 2>/dev/null | head -1)" ] \
        || finding sdk-manifest-missing "$src" "$name ($orig $dv): no .xcprivacy in $copy"
    else
      judge listed-sdk "$src" "$name — $orig $dv"
    fi
  done
done < "$W/sdks"

# 3d — tracking consistency
TRACK_TRUE=0
while IFS= read -r m; do
  [ "$(pl_raw "$m" NSPrivacyTracking)" = true ] || continue
  TRACK_TRUE=1
  [ -n "$(pl_strings "$m" NSPrivacyTrackingDomains | head -1)" ] || finding tracking-domains-missing "$(pl_loc "$m" NSPrivacyTracking)"
done < "$W/manifests"
TRACKERS="$(awk -F'\t' '$1 == "tracker" { print $2 "\t" $3 }' "$W/facts" | while IFS="$TAB" read -r re name; do dep_match "$re" && echo "$name"; done | joined)"
if [ -n "$TRACKERS" ]; then
  ATT_REQ="$(src_hits 'requestTrackingAuthorization' | head -1)"
  if [ "$TRACK_TRUE" = 0 ] || [ -z "$ATT_REQ" ]; then
    finding tracking-inconsistent "$(awk -F'\t' '{ print $1; exit }' "$W/deps")" \
      "tracking SDKs: $TRACKERS; NSPrivacyTracking=$([ "$TRACK_TRUE" = 1 ] && echo true || echo false); ATT request: $([ -n "$ATT_REQ" ] && hit_loc "$ATT_REQ" || echo none)"
  fi
fi

# ---------------------------------------------------------------------------
# 4. Configuration & assets
# ---------------------------------------------------------------------------
if [ "$HAS_APP" = 1 ]; then
  [ -n "$(key_sources ITSAppUsesNonExemptEncryption "$W/plist_app" | head -1)" ] \
    || [ -n "$(cfg_rows INFOPLIST_KEY_ITSAppUsesNonExemptEncryption app | head -1)" ] \
    || finding encryption-key-missing "$PRIMARY"
fi

# versions: value \t location \t target — app + extension targets only, test targets excluded
versions() {  # versions <build-setting> <plist-key>
  cfg_rows "$1" | cut -f1-3
  local f v
  while IFS= read -r f; do
    v="$(pl_raw "$f" "$2")"; [ -n "$v" ] && printf '%s\t%s\t%s\n' "$v" "$(pl_loc "$f" "$2")" "$f"
  done < "$W/plist_appext"
  if [ -z "$(cfg_rows "$1" | head -1)" ]; then
    while IFS= read -r f; do
      grep -nE "^[[:space:]]*$1[[:space:]]*=" "$f" | head -1 | while IFS=: read -r n l; do
        v="${l#*=}"; v="$(echo "$v" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"; printf '%s\t%s:%s\t%s\n' "$v" "$f" "$n" "xcconfig:$f"
      done
    done < "$W/xcconfig"
  fi
}
SHAPE='^[0-9]+(\.[0-9]+){0,2}$'
versions MARKETING_VERSION CFBundleShortVersionString > "$W/mv"
versions CURRENT_PROJECT_VERSION CFBundleVersion > "$W/bv"
for kind in mv bv; do
  while IFS="$TAB" read -r v loc tg; do
    case "$v" in
      *'$('*|*'${'*) cfg_rows '.*' | grep -qF "$loc" && judge unresolved-setting "$loc" "$tg: $v" ;;
      *) echo "$v" | grep -qE "$SHAPE" && continue
         if [ "$kind" = mv ]; then finding marketing-version-shape "$loc" "\"$v\" ($tg)"
         else finding build-number-shape "$loc" "\"$v\" ($tg)"; fi ;;
    esac
  done < "$W/$kind"
done
grep -v '\$[({]' "$W/bv" | awk -F'\t' '!seen[$3 "=" $1]++ { print $3 "=" $1 }' > "$W/bv_pairs"
if [ "$(grep -v '\$[({]' "$W/bv" | cut -f1 | LC_ALL=C sort -u | grep -c .)" -gt 1 ]; then
  finding build-number-mismatch "$(grep -v '\$[({]' "$W/bv" | head -1 | cut -f2)" "values: $(joined < "$W/bv_pairs")"
fi
inv versions "marketing=$(grep -v '\$[({]' "$W/mv" | cut -f1 | joined); build=$(grep -v '\$[({]' "$W/bv" | cut -f1 | joined); deployment=$(cfg_rows IPHONEOS_DEPLOYMENT_TARGET 'app|ext|project' | cut -f1 | joined | orn)"
MV1="$(grep -v '\$[({]' "$W/mv" | head -1 | cut -f1)"
[ "$HAS_APP" = 1 ] && verify marketing-version-order "${MV1:-(unset)}"

# App icon — 1024², no alpha. Dark/tinted appearance variants are allowed alpha and are skipped.
if [ "$HAS_APP" = 1 ]; then
  ICON_NAMES="$( (cfg_rows ASSETCATALOG_COMPILER_APPICON_NAME app | cut -f1; echo AppIcon) | awk 'NF && !s[$0]++')"
  : > "$W/iconsets"
  for nm in $ICON_NAMES; do grep -E "(^|/)$nm\.appiconset/Contents\.json$" "$W/all" | not_test >> "$W/iconsets"; done
  if ! command -v sips >/dev/null 2>&1; then
    verify icon
  elif [ ! -s "$W/iconsets" ]; then
    if grep -qE "(^|/)($(echo $ICON_NAMES | tr ' ' '|'))\.icon/" "$W/all"; then
      judge icon "$(grep -E "\.icon/" "$W/all" | head -1)" "Icon Composer .icon only, no .appiconset"
    else
      finding icon-missing "$PRIMARY" "no $(echo $ICON_NAMES | tr ' ' '/').appiconset"
    fi
  else
    while IFS= read -r cj; do
      dir="$(dirname "$cj")"; found=0
      count="$(plutil -extract images raw -o - "$cj" 2>/dev/null)"; count="${count:-0}"
      i=0
      while [ "$i" -lt "$count" ]; do
        size="$(plutil -extract "images.$i.size" raw -o - "$cj" 2>/dev/null)"
        fn="$(plutil -extract "images.$i.filename" raw -o - "$cj" 2>/dev/null)"
        if [ "$size" = 1024x1024 ] && [ -n "$fn" ] && ! plutil -extract "images.$i.appearances" xml1 -o - "$cj" >/dev/null 2>&1; then
          png="$dir/$fn"
          if [ -f "$png" ]; then
            found=1
            info="$(sips -g pixelWidth -g pixelHeight -g hasAlpha "$png" 2>/dev/null)"
            w="$(echo "$info" | awk '/pixelWidth/ { print $2 }')"; h="$(echo "$info" | awk '/pixelHeight/ { print $2 }')"
            [ "$w" = 1024 ] && [ "$h" = 1024 ] || finding icon-missing "$png" "is ${w:-?}×${h:-?}"
            echo "$info" | grep -q 'hasAlpha: yes' && finding icon-alpha "$png"
          fi
        fi
        i=$((i + 1))
      done
      [ "$found" = 1 ] || finding icon-missing "$cj" "no 1024×1024 image in the slot"
    done < "$W/iconsets"
  fi
fi

# Launch screen
if [ "$HAS_APP" = 1 ]; then
  ok=0
  while IFS= read -r f; do pl_has "$f" UILaunchScreen || pl_has "$f" UILaunchStoryboardName || pl_has "$f" UILaunchScreens && ok=1; done < "$W/plist_app"
  cfg_rows 'INFOPLIST_KEY_UILaunchScreen_.*|INFOPLIST_KEY_UILaunchStoryboardName' app | cut -f1 | grep -qvx 'NO' && ok=1
  [ "$ok" = 1 ] || finding launch-screen-missing "$PRIMARY"
fi

# Device family, iPad orientations, UIRequiresFullScreen
UNIVERSAL=no
cfg_rows TARGETED_DEVICE_FAMILY app | cut -f1 | grep -q 2 && UNIVERSAL=yes
while IFS= read -r f; do plutil -extract UIDeviceFamily xml1 -o - "$f" 2>/dev/null | grep -q '<integer>2</integer>' && UNIVERSAL=yes; done < "$W/plist_app"
inv device-family "$(cfg_rows TARGETED_DEVICE_FAMILY app | cut -f1 | joined)"

FULLSCREEN=0
while IFS= read -r f; do
  [ "$(pl_raw "$f" UIRequiresFullScreen)" = true ] && { FULLSCREEN=1; finding requires-fullscreen-deprecated "$(pl_loc "$f" UIRequiresFullScreen)"; }
done < "$W/plist_app"
while IFS="$TAB" read -r v loc tg k; do
  [ "$v" = YES ] && { FULLSCREEN=1; finding requires-fullscreen-deprecated "$loc"; }
done < <(cfg_rows INFOPLIST_KEY_UIRequiresFullScreen app)

if [ "$UNIVERSAL" = yes ]; then
  : > "$W/orient"   # location \t space-separated orientations
  while IFS= read -r f; do
    for k in 'UISupportedInterfaceOrientations~ipad' UISupportedInterfaceOrientations; do
      pl_has "$f" "$k" || continue
      printf '%s\t%s\n' "$(pl_loc "$f" "$k")" "$(pl_strings "$f" "$k" | tr '\n' ' ')" >> "$W/orient"; break
    done
  done < "$W/plist_app"
  awk -F'\t' '$1 == "app" && ($4 == "INFOPLIST_KEY_UISupportedInterfaceOrientations_iPad" || $4 == "INFOPLIST_KEY_UISupportedInterfaceOrientations") {
      id = $7 SUBSEP $2 SUBSEP $3
      if ($4 ~ /_iPad$/ || !(id in v)) { v[id] = $5; l[id] = $7 ":" $6 }
    } END { for (i in v) print l[i] "\t" v[i] }' "$W/cfg" >> "$W/orient"
  if [ ! -s "$W/orient" ]; then
    judge ipad-orientations "$PRIMARY" "TARGETED_DEVICE_FAMILY includes 2"
  elif [ "$FULLSCREEN" = 0 ]; then
    while IFS="$TAB" read -r loc list; do
      miss=""
      for o in Portrait PortraitUpsideDown LandscapeLeft LandscapeRight; do
        echo " $list " | grep -q "UIInterfaceOrientation$o " || miss="${miss:+$miss, }$o"
      done
      [ -n "$miss" ] && finding ipad-orientations "$loc" "missing: $miss"
    done < "$W/orient"
  fi
fi

# UIRequiredDeviceCapabilities — anything but arm64
while IFS= read -r f; do
  extra="$( (pl_strings "$f" UIRequiredDeviceCapabilities; plutil -extract UIRequiredDeviceCapabilities xml1 -o - "$f" 2>/dev/null | sed -n 's/.*<key>\(.*\)<\/key>.*/\1/p') | grep -vx arm64 | joined)"
  [ -n "$extra" ] && finding required-capabilities "$(pl_loc "$f" UIRequiredDeviceCapabilities)" "$extra"
done < "$W/plist_appext"
while IFS="$TAB" read -r v loc tg k; do
  extra="$(printf '%s\n' $v | grep -vx arm64 | joined)"
  [ -n "$extra" ] && finding required-capabilities "$loc" "$extra"
done < <(cfg_rows INFOPLIST_KEY_UIRequiredDeviceCapabilities)

# ATS
while IFS= read -r f; do
  [ "$(pl_raw "$f" NSAppTransportSecurity.NSAllowsArbitraryLoads)" = true ] || continue
  pl_has "$f" NSAppTransportSecurity.NSExceptionDomains || finding ats-arbitrary-loads "$(pl_loc "$f" NSAllowsArbitraryLoads)"
done < "$W/plist_appext"

# Entitlements → VERIFY-BY-HAND per capability; get-task-allow; push without aps-environment
HAS_APS=0; ENT_CLOUDKIT=0
while IFS= read -r e; do
  plutil -convert xml1 -o "$W/ent.xml" "$e" 2>/dev/null || continue
  awk '/<dict>/ { d++ } /<\/dict>/ { d-- } d == 1 && /<key>/ { s = $0; sub(/.*<key>/, "", s); sub(/<\/key>.*/, "", s); print s }' "$W/ent.xml" > "$W/ent.keys"
  while IFS= read -r k; do
    [ "$k" = get-task-allow ] && continue
    grep -qxF "entitlement:$k" "$W/verify.ids" 2>/dev/null && continue
    echo "entitlement:$k" >> "$W/verify.ids"; verify entitlement "$k" "$k"
  done < "$W/ent.keys"
  grep -qx 'aps-environment' "$W/ent.keys" && HAS_APS=1
  [ "$(pl_raw "$e" get-task-allow)" = true ] && finding get-task-allow "$(pl_loc "$e" get-task-allow)"
  sed -n '/<key>com.apple.developer.icloud-services<\/key>/,/<\/array>/p' "$W/ent.xml" | grep -q '<string>CloudKit' && ENT_CLOUDKIT=1
done < "$W/ent"
[ "$HAS_APP" = 1 ] && verify distribution-profile
PUSH="$(src_hits "$(pattern push)" | head -1)"
[ -n "$PUSH" ] && [ "$HAS_APS" = 0 ] && finding push-without-aps "$(hit_loc "$PUSH")" "$(hit_token "$PUSH" "$(pattern push)")"

# Toolchain floor — local Xcode; CI pins are listed for the model
XV="$XCODE_OVERRIDE"
[ -z "$XV" ] && XV="$(xcodebuild -version 2>/dev/null | head -1 | sed -n 's/^Xcode //p')"
case "$XV" in
  ''|none) verify toolchain; inv toolchain "unknown" ;;
  *) inv toolchain "Xcode $XV"
     [ "${XV%%.*}" -lt "$SDK_FLOOR" ] 2>/dev/null && finding sdk-floor "$PRIMARY" "local Xcode $XV" ;;
esac
src_hits "$(pattern ci-xcode)" "$W/ci" | while IFS= read -r h; do judge ci-toolchain "$(hit_loc "$h")" "$(excerpt "$(hit_text "$h")")"; done

# Banned / rejection-magnet code
src_hits "$(pattern uiwebview)" | awk -F: '!seen[$1]++' | while IFS= read -r h; do finding uiwebview "$(hit_loc "$h")"; done
{ grep -E '\.(framework|xcframework)/|\.a$' "$W/all"
  for d in Pods Carthage; do [ -d "$d" ] && find "$d" -type f \( -path "*.framework/*" -o -path "*.xcframework/*" -o -name "*.a" \) 2>/dev/null | sed 's#^\./##'; done
} | while IFS= read -r b; do grep -q UIWebView "$b" 2>/dev/null && finding uiwebview "$b" "vendored binary"; done
src_hits "$(pattern private-api)" | while IFS= read -r h; do judge private-api "$(hit_loc "$h")" "$(excerpt "$(hit_text "$h")")"; done
{ src_hits "$(pattern placeholder-copy)"; src_hits "$(pattern placeholder-copy)" "$W/strings"; } \
  | while IFS= read -r h; do judge placeholder-copy "$(hit_loc "$h")" "$(excerpt "$(hit_text "$h")")"; done
src_hits "$(pattern debug-gate)" | release_hits | while IFS= read -r h; do judge debug-gate "$(hit_loc "$h")" "$(excerpt "$(hit_text "$h")")"; done
src_hits "$(pattern log-pii)" | release_hits | while IFS= read -r h; do judge log-pii "$(hit_loc "$h")" "$(excerpt "$(hit_text "$h")")"; done
{ key_sources CFBundleDisplayName "$W/plist_app"; } | while IFS="$TAB" read -r v loc; do
  echo "$v" | grep -qE -- "$(pattern display-name)" && judge display-name "$loc" "CFBundleDisplayName=\"$v\""
done

# ---------------------------------------------------------------------------
# FLAGS
# ---------------------------------------------------------------------------
flag_code() { awk -F'\t' -v n="$1" '$1 == "flag" && $2 == n { print $3; exit }' "$W/facts"; }
flag_dep()  { awk -F'\t' -v n="$1" '$1 == "depflag" && $2 == n { print $3; exit }' "$W/facts"; }
FLAGLINE="FLAGS"; YES=""
for f in $FLAGS_ORDER; do
  v=no
  if [ "$f" = universal ]; then v="$UNIVERSAL"
  else
    [ -n "$(src_hits "$(flag_code "$f")" | head -1)" ] && v=yes
    d="$(flag_dep "$f")"; [ -n "$d" ] && dep_match "$d" && v=yes
    case "$f" in
      storekit) [ -s "$W/storekit" ] && v=yes ;;
      att)      { [ -n "$TRACKERS" ] || [ "$TRACK_TRUE" = 1 ]; } && v=yes ;;
      cloudkit) [ "$ENT_CLOUDKIT" = 1 ] && [ -n "$(src_hits "$(pattern swiftdata-container)" | head -1)" ] && v=yes ;;
    esac
  fi
  FLAGLINE="$FLAGLINE|$f=$v"; [ "$v" = yes ] && YES="${YES:+$YES }$f"
  [ "$f" = cloudkit ] && CLOUDKIT="$v"
done
if [ "$CLOUDKIT" = yes ]; then
  if [ -z "$(src_hits "$(pattern cloudkit-schema-init)" "$W/src_all" | head -1)" ]; then
    first="$(src_hits "$(flag_code cloudkit)|$(pattern swiftdata-container)" | head -1)"
    if [ -n "$first" ]; then finding cloudkit-schema-init "$(hit_loc "$first")"; else finding cloudkit-schema-init "$(head -1 "$W/ent")"; fi
  fi
  verify cloudkit-deploy
fi

# ---------------------------------------------------------------------------
# Report
# ---------------------------------------------------------------------------
cat "$W/inventory"
LC_ALL=C sort -t "$TAB" -k1,1n -k2 "$W/findings" | cut -f2- | awk '!seen[$0]++' > "$W/findings.out"
cat "$W/findings.out"
# Each topic opens with its question (location "-"), then up to JUDGE_CAP hits.
awk -F'\t' '$1 == "judge" { print $2 "\t" $3 }' "$W/facts" | while IFS="$TAB" read -r t q; do printf '%s\t%s\n' "$t" "$(fill "$q")"; done > "$W/judgeq"
awk -F'|' -v cap="$JUDGE_CAP" '
  NR == FNR { i = index($0, "\t"); q[substr($0, 1, i - 1)] = substr($0, i + 1); next }
  !seen[$0]++ { t = $2; if (!(t in n)) print "JUDGE|" t "|-|" q[t]; n[t]++; hits++; if (n[t] <= cap) print; else over[t]++ }
  END { for (t in over) print "JUDGE|" t "|-|+" over[t] " more not listed — re-run the pattern by hand"; print hits + 0 > "/dev/stderr" }' "$W/judgeq" "$W/judge" > "$W/judge.out" 2> "$W/judge.n"
cat "$W/judge.out" "$W/verify"
echo "$FLAGLINE"
cnt() { grep -c "^FINDING|$1|" "$W/findings.out"; }
printf 'SCAN: %s findings — %s/%s/%s/%s B/H/M/L; %s judge, %s verify-by-hand; flags %s\n' \
  "$(grep -c . "$W/findings.out")" "$(cnt BLOCKER)" "$(cnt HIGH)" "$(cnt MEDIUM)" "$(cnt LOW)" \
  "$(cat "$W/judge.n")" "$(grep -c . "$W/verify")" "${YES:-none}"
exit 0
