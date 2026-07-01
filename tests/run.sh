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
