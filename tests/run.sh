#!/usr/bin/env bash
#
# Test suite for radicle-seed-prune. Zero external deps beyond bash + git + coreutils:
# it builds a throwaway Radicle-home fixture (fake `rad` stub on PATH + real bare git repos
# with controlled activity dates and sizes) and runs the real script against it.
#
#   bash tests/run.sh
#
set -uo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
SCRIPT="$HERE/../radicle-seed-prune"
PASS=0; FAIL=0
ok(){ PASS=$((PASS+1)); printf 'ok   - %s\n' "$1"; }
no(){ FAIL=$((FAIL+1)); printf 'FAIL - %s\n' "$1"; }
# assert that "$2" (a plan text) contains / omits a repo line for rid $3 with optional reason $4
has(){ grep -qE "^$2 " <<<"$1"; }

# ---- fixture -----------------------------------------------------------------
# columns: rid  name  seeds  vis  own  days_since_activity  size_bytes
MANIFEST_ROWS='zjunk1\ttest-old\t5\tpublic\t0\t400\t2000
zbig2\tbigmirror\t5\tpublic\t0\t200\t2200000
ztwoyr3\tnormalproj\t4\tpublic\t0\t800\t2000
zfresh4\tactiveproj\t5\tpublic\t0\t5\t2000
zfews5\tcoolproj\t1\tpublic\t0\t800\t2000
zpin6\tpinnedproj\t5\tpublic\t0\t800\t2000
zpriv7\tsecretproj\t5\tprivate\t0\t800\t2000
zbar8\tbar\t5\tpublic\t0\t300\t2000
zbwid9\tBAR_widget\t5\tpublic\t0\t300\t2000
zown22\tmyproj\t5\tpublic\t1\t800\t2000'

build_fixture(){
  [ -n "${ROOT:-}" ] && rm -rf "$ROOT" 2>/dev/null # re-runnable: drop the previous fixture
  ROOT=$(mktemp -d)
  trap 'rm -rf "$ROOT" 2>/dev/null' EXIT           # always clean up, even on failure
  local bin="$ROOT/bin"; mkdir -p "$bin"
  cp "$HERE/rad-stub" "$bin/rad"; chmod +x "$bin/rad"

  export RSP_HOME="$ROOT/rad-home"
  export RSP_NID="zOURNODExxxxxxxxxxxxxxxxxxxxx"
  export RSP_MANIFEST="$ROOT/manifest.tsv"

  # ISOLATION: pin every input the script reads so a test can NEVER touch the real Radicle home,
  # even if the caller's shell exported RAD_HOME/RAD/STORAGE/etc. STORAGE in particular confines all
  # deletions to the temp dir (the script only rm's paths under "$STORAGE"/z*).
  export RAD="$bin/rad"
  export RAD_HOME="$RSP_HOME"
  export STORAGE="$RSP_HOME/storage"
  export CONFIG="$RSP_HOME/config.json"
  export AUDIT_DIR="$RSP_HOME/prune-audit"
  export OUR_NID="$RSP_NID"
  export SERVICE="rsp-test-does-not-exist.service"
  export PATH="$bin:$PATH"
  # Hermetic git: ignore the user's global/system config, so fixture commits never use their signing
  # key (gpgsign) or identity, and the host config can't change behaviour.
  export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null

  printf '%b\n' "$MANIFEST_ROWS" > "$RSP_MANIFEST"
  mkdir -p "$STORAGE"
  printf '{ "web": { "pinned": { "repositories": ["rad:zpin6"] } } }\n' > "$CONFIG"

  # real bare git repos with controlled activity date + size (all under $ROOT)
  while IFS=$'\t' read -r rid name seeds vis own days size; do
    [ -z "$rid" ] && continue
    local d="$STORAGE/$rid"
    git init -q --bare "$d"
    local w; w=$(mktemp -d -p "$ROOT")
    git -C "$w" -c init.defaultBranch=master init -q
    git -C "$w" config user.email a@b; git -C "$w" config user.name a
    head -c "$size" /dev/urandom > "$w/blob"
    git -C "$w" add -A
    local ts; ts=$(date -u -d "$days days ago" +%s)
    GIT_AUTHOR_DATE="@$ts +0000" GIT_COMMITTER_DATE="@$ts +0000" git -C "$w" commit -q -m c
    git -C "$w" push -q "$d" master:master 2>/dev/null
    rm -rf "$w"
    touch -d "10 days ago" "$d"        # keep every dir out of the freshness guard
  done < "$RSP_MANIFEST"
}

# Defense in depth: refuse to run anything if STORAGE is not confined to the temp fixture.
assert_isolated(){
  case "$STORAGE" in
    "$ROOT"/*) : ;;
    *) echo "ABORT: STORAGE=$STORAGE is not under the test root $ROOT - refusing to run"; exit 3 ;;
  esac
}

# run the real script against the fixture; echoes combined output, sets RC
run(){ local out; out=$("$SCRIPT" "$@" 2>&1); RC=$?; printf '%s' "$out"; }

NOTTY=(); command -v setsid >/dev/null && NOTTY=(setsid)   # drop the tty for the non-interactive --apply test

# ============================================================================
build_fixture
assert_isolated                                   # STORAGE must be inside the temp fixture

# --- classification & exclusions (relaxed thresholds, disk-awareness off) ---
export DISK_AWARE=0 ABS_SIZE_FLOOR_MB=1
plan=$(run)
has "$plan" "zjunk1"  && grep -qE "^zjunk1 .*junk-name"     <<<"$plan" && ok "junk-named stale repo pruned (junk-name)"     || no "junk-named stale repo pruned"
has "$plan" "zbig2"   && grep -qE "^zbig2 .*size-outlier"   <<<"$plan" && ok "big stale well-seeded repo pruned (size)"      || no "big stale repo pruned"
has "$plan" "ztwoyr3" && grep -qE "^ztwoyr3 .*stale"        <<<"$plan" && ok "2yr-stale well-seeded repo pruned (stale)"     || no "2yr-stale repo pruned"
has "$plan" "zbar8"   && grep -qE "^zbar8 .*junk-name"      <<<"$plan" && ok "whole-name 'bar' pruned (junk-name)"           || no "'bar' pruned"
! has "$plan" "zfresh4" && ok "recently-active repo kept"        || no "recently-active repo kept"
! has "$plan" "zfews5"  && ok "stale but under-seeded repo kept (seed gate)" || no "under-seeded repo kept"
! has "$plan" "zpin6"   && ok "pinned repo excluded"            || no "pinned repo excluded"
! has "$plan" "zpriv7"  && ok "private repo excluded"           || no "private repo excluded"
! has "$plan" "zown22"  && ok "own repo excluded"               || no "own repo excluded"
! has "$plan" "zbwid9"  && ok "'BAR_widget' not treated as junk" || no "'BAR_widget' not junk"

# --- disk-pressure: at full pressure, stale window shrinks + seed gate drops to 1 ---
plan_hi=$(DISK_AWARE=1 PRESSURE_CRIT_PCT=100 PRESSURE_CRIT_GB=99999999 PRESSURE_RELAX_PCT=100 PRESSURE_RELAX_GB=999999999 ABS_SIZE_FLOOR_MB=1 run)
grep -qE "pressure=100%" <<<"$plan_hi" && ok "pressure reaches 100% under forced watermarks" || no "pressure=100%"
has "$plan_hi" "zbwid9" && ok "pressure prunes a repo that was kept at p=0"   || no "pressure widens the net"
has "$plan_hi" "zfews5" && ok "pressure drops seed gate to 1 (under-seeded now pruned)" || no "pressure drops seed gate"
! has "$plan_hi" "zfresh4" && ok "pressure still keeps a fresh repo"          || no "pressure keeps fresh repo"

# --- RAD_HOME reaches rad as ENVIRONMENT, not just as a shell variable ---
# Regression: the script resolved RAD_HOME but never exported it, so every rad call queried the
# default home instead, came back empty, and forced a plan of zero repos. Unset it in the caller so
# the only way the stub can see it is the script exporting what it resolved from `rad path`.
: > "$RSP_HOME/.stub_radhome"
env -u RAD_HOME DISK_AWARE=0 ABS_SIZE_FLOOR_MB=1 "$SCRIPT" >/dev/null 2>&1; rc=$?
{ grep -qxF "$RSP_HOME" "$RSP_HOME/.stub_radhome" && [ "$rc" = 0 ]; } \
  && ok "resolved RAD_HOME is exported to rad" || no "resolved RAD_HOME is exported to rad (rc=$rc)"

# --- an unexpected failure names the line and the command instead of exiting silently ---
# Regression: `set -e` plus muted stderr meant any hiccup exited non-zero with no output whatsoever,
# which is undebuggable from a bug report. Inject a failure and demand a diagnosable message.
inj="$ROOT/injected-failure"; sed 's|^nrepos=|false  # injected\nnrepos=|' "$SCRIPT" > "$inj"; chmod +x "$inj"
out=$(DISK_AWARE=0 "$inj" 2>&1); rc=$?
{ [ "$rc" != 0 ] && grep -qE '^# ERROR: line [0-9]+: \[false' <<<"$out"; } \
  && ok "unexpected failure reports line + command" || no "unexpected failure reports line + command (rc=$rc)"

# --- blind runs abort instead of reporting a reassuring, meaningless "prune 0 repos" ---
out=$(RSP_NODE_DOWN=1 DISK_AWARE=0 "$SCRIPT" 2>&1); rc=$?
{ [ "$rc" = 5 ] && grep -q 'ABORT(dry-run)' <<<"$out" && ! grep -q '# PLAN:' <<<"$out"; } \
  && ok "node-down aborts dry-run too (exit 5, no plan)" || no "node-down aborts dry-run (got exit $rc)"

out=$(RSP_NO_ROUTING=1 DISK_AWARE=0 "$SCRIPT" 2>&1); rc=$?
{ [ "$rc" = 5 ] && grep -q 'routing table empty' <<<"$out" && ! grep -q '# PLAN:' <<<"$out"; } \
  && ok "empty routing table aborts (exit 5, no plan)" || no "empty routing aborts (got exit $rc)"

# --- an unreadable repo survives the scan: reported and excluded, never fatal ---
# Regression: du hit one unreadable dir, xargs returned 123, and `set -e` killed the whole run with
# no output at all. The unreadable dir is INSIDE the repo, so its refs stay readable and ztwoyr3
# still looks prunable on age - only the scan-error exclusion keeps it out of the plan.
mkdir -p "$STORAGE/ztwoyr3/unreadable" && chmod 000 "$STORAGE/ztwoyr3/unreadable"
touch -d "10 days ago" "$STORAGE/ztwoyr3"   # creating the subdir bumped mtime; keep it out of the
                                            # freshness guard so ONLY the scan-error rule excludes it
# a high blind-scan limit, so this tests the per-repo exclusion and not the aggregate guard below
out=$(DISK_AWARE=0 ABS_SIZE_FLOOR_MB=1 MAX_SCAN_FAIL_PCT=50 "$SCRIPT" 2>&1); rc=$?
chmod 755 "$STORAGE/ztwoyr3/unreadable"; rmdir "$STORAGE/ztwoyr3/unreadable"
{ [ "$rc" = 0 ] && grep -q '# PLAN:' <<<"$out"; } \
  && ok "unreadable repo does not abort the scan" || no "unreadable repo does not abort the scan (got exit $rc)"
grep -qE '^# WARN: [0-9]+ scan error' <<<"$out" && ok "scan errors are reported, not swallowed" || no "scan errors reported"
{ ! has "$out" "ztwoyr3" && has "$out" "zjunk1"; } \
  && ok "unreadable repo excluded from plan, others still planned" || no "unreadable repo excluded from plan"

# --- a scan that missed too much of storage refuses to report a plan at all ---
# Three unreadable repos out of ten, against a 10% limit. Without this the run would report a
# plausible-looking small plan built from a scan that never saw a third of the seed.
for r in zjunk1 zbig2 zbar8; do chmod 000 "$STORAGE/$r"; done
out=$(DISK_AWARE=0 ABS_SIZE_FLOOR_MB=1 MAX_SCAN_FAIL_PCT=10 "$SCRIPT" 2>&1); rc=$?
for r in zjunk1 zbig2 zbar8; do chmod 755 "$STORAGE/$r"; done
{ [ "$rc" = 5 ] && grep -q 'could not read 3 of 10 repos' <<<"$out" && ! grep -q '# PLAN:' <<<"$out"; } \
  && ok "blind scan aborts instead of reporting a small plan" || no "blind scan aborts (got exit $rc)"

# --- fail-safe: node down aborts --apply before touching anything ---
RSP_NODE_DOWN=1 DISK_AWARE=0 ABS_SIZE_FLOOR_MB=1 "$SCRIPT" --apply >/dev/null 2>&1; rc=$?
[ "$rc" = 5 ] && ok "node-down aborts --apply (exit 5)" || no "node-down aborts --apply (got exit $rc)"

# --- apply: non-interactive (cron path) applies; interactive prompt (pty) obeys y/N ---
# non-interactive --apply (no controlling tty): applies directly, no prompt.
build_fixture; assert_isolated                    # fresh fixture before the tests that delete
DISK_AWARE=0 ABS_SIZE_FLOOR_MB=1 "${NOTTY[@]}" "$SCRIPT" --apply </dev/null >/dev/null 2>&1
gone=1; for r in zjunk1 zbig2 ztwoyr3 zbar8;                do [ -e "$STORAGE/$r" ] && gone=0; done
kept=1; for r in zfresh4 zpin6 zpriv7 zown22 zbwid9 zfews5; do [ -e "$STORAGE/$r" ] || kept=0; done
{ [ "$gone" = 1 ] && [ "$kept" = 1 ]; } && ok "non-interactive --apply prunes exactly the plan" || no "non-interactive --apply prunes the plan"
{ [ -s "$RSP_HOME/.stub_block" ] && [ -s "$RSP_HOME/.stub_unseed" ]; } && ok "apply calls rad unseed + block" || no "apply calls unseed+block"

# --- a failed deletion is never reported as reclaimed disk ---
# A read-only storage dir lets the whole plan compute, then makes every rm fail. The audit log and
# the GiB total are both written from the plan, so silence here would record disk that never freed.
build_fixture; assert_isolated
before=$(ls "$STORAGE" | wc -l)
chmod 555 "$STORAGE"
out=$(DISK_AWARE=0 ABS_SIZE_FLOOR_MB=1 "${NOTTY[@]}" "$SCRIPT" --apply </dev/null 2>&1); rc=$?
chmod 755 "$STORAGE"
after=$(ls "$STORAGE" | wc -l)
{ [ "$before" = "$after" ] && grep -q 'WARN delete failed' <<<"$out" \
    && grep -qE 'WARN: [0-9]+ of [0-9]+ deletions failed' <<<"$out" && grep -q 'DONE: deleted 0 repos' <<<"$out"; } \
  && ok "failed deletions are reported, not counted as reclaimed" || no "failed deletions reported (rc=$rc)"

# interactive prompt via a pty (needs util-linux `script`): n aborts, y applies.
if command -v script >/dev/null 2>&1; then
  build_fixture; assert_isolated
  b=$(ls "$STORAGE" | wc -l)
  printf 'n\n' | script -qec "env DISK_AWARE=0 ABS_SIZE_FLOOR_MB=1 '$SCRIPT' --apply" /dev/null >"$ROOT/n.out" 2>&1
  a=$(ls "$STORAGE" | wc -l)
  { grep -q aborted "$ROOT/n.out" && [ "$b" = "$a" ]; } && ok "interactive --apply + n aborts, nothing deleted" || no "interactive + n aborts"

  build_fixture; assert_isolated
  printf 'y\n' | script -qec "env DISK_AWARE=0 ABS_SIZE_FLOOR_MB=1 '$SCRIPT' --apply" /dev/null >"$ROOT/y.out" 2>&1
  gone=1; for r in zjunk1 zbig2 ztwoyr3 zbar8; do [ -e "$STORAGE/$r" ] && gone=0; done
  [ "$gone" = 1 ] && ok "interactive --apply + y prunes the plan" || no "interactive + y prunes"
else
  echo "skip - interactive prompt tests (no util-linux 'script' for a pty)"
fi

rm -rf "$ROOT"
# ============================================================================
echo "-----------------------------------------"
echo "passed: $PASS   failed: $FAIL"
[ "$FAIL" = 0 ]
