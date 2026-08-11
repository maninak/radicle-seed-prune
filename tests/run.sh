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
# columns: rid  name  seeds  vis  own  days_since_activity  size_bytes  description
MANIFEST_ROWS='zjunk1\ttest-old\t5\tpublic\t0\t400\t2000\ta real project
zbig2\tbigmirror\t5\tpublic\t0\t200\t2200000\ta real project
ztwoyr3\tnormalproj\t4\tpublic\t0\t800\t2000\ta real project
zfresh4\tactiveproj\t5\tpublic\t0\t5\t2000\ta real project
zfews5\tcoolproj\t1\tpublic\t0\t800\t2000\ta real project
zpin6\tpinnedproj\t5\tpublic\t0\t800\t2000\ta real project
zpriv7\tsecretproj\t5\tprivate\t0\t800\t2000\ta real project
zbar8\tbar\t5\tpublic\t0\t300\t2000\ta real project
zbwid9\tBAR_widget\t5\tpublic\t0\t300\t2000\ta real project
zown22\tmyproj\t5\tpublic\t1\t800\t2000\ta real project
zhexid23\t08a25d0f666d\t5\tpublic\t0\t300\t2000\ta real project
zdigit24\t12345678\t5\tpublic\t0\t300\t2000\ta real project
zridin25\tridquoter\t5\tpublic\t0\t800\t2000\tstatic site generator used for the site in rad:zsomeotherrepo
zspaced26\tBlog e64\t5\tpublic\t0\t800\t2000\ta real project
zhexzero27\t9f3c1a7b2e4d8506\t0\tpublic\t0\t300\t2000\ta real project
zwordzero28\ttest-orphan\t0\tpublic\t0\t300\t2000\ta real project'

# Rule D is decided by the CORPUS, so it needs whole families, and the families below are a
# controlled experiment: all five are 9 repos, the same age, the same size, and a name skeleton
# with a variable slot. They differ in exactly one variable each, so a failure names its own cause.
#   zspam*   name has a random-id slot AND all 9 share one description template  -> pruned
#   zdecoy*  same name shape, but every repo carries its OWN real description    -> kept
#   zenum*   descriptions agree, but the varying slot is a plain enumeration     -> kept by default
#   znodesc* random-id slot, but no descriptions at all, so only ONE signal      -> kept
#   zdate*   agreeing descriptions and a 6+ digit slot, but no LETTER in it, so
#            it is a date/sequence rather than a random id                        -> kept
# 90 days old: too young for rules A/C, too small for B, so rule D is the only thing that can fire
# and a hit can be nothing else.
build_families(){
  local i rows=""
  local hex=(- 33ed7115 6cf239e8 28036e03 1d9ce82f e9a0b26f df68129a 944f76e9 283bed8c 9e1437e9)
  # a mirror farm's descriptions differ in WORDS, the way real ones do, not merely in a number
  local word=(- gyroscope barometer thermometer altimeter magnetometer hygrometer photodiode tachometer voltmeter)
  # rids index from 1: 0 is not in the base58 alphabet, so a "zspam0" would be correctly rejected
  # as a malformed rid and the family would come up one member short.
  for i in $(seq 1 9); do
    rows+="zspam$i\tevens-$i-${hex[$i]}\t5\tpublic\t0\t90\t2000\tKeep only even values from an array. Variant $i.\n"
    rows+="zdecoy$i\tmirror-$i-${hex[$i]}\t5\tpublic\t0\t90\t2000\tCircuitPython driver for the ${word[$i]} breakout board\n"
    rows+="zenum$i\tlinuxstable-$i\t5\tpublic\t0\t90\t2000\tLinux kernel stable tree branch $i\n"
    rows+="znodesc$i\tblank-$i-${hex[$i]}\t5\tpublic\t0\t90\t2000\t\n"
    rows+="zdate$i\tsnapshot-2024010$i\t5\tpublic\t0\t90\t2000\tNightly snapshot $i\n"
  done
  rows+="zspamzero\tevens-10-4b7e2c91\t0\tpublic\t0\t90\t2000\tKeep only even values from an array. Variant 10.\n"
  printf '%b' "$rows"
}
MANIFEST_ROWS="$MANIFEST_ROWS"$'\n'"$(build_families)"
NREPOS=62

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
  while IFS=$'\t' read -r rid name seeds vis own days size desc; do
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
has "$plan" "zhexid23" && grep -qE "^zhexid23 .*junk-id" <<<"$plan" && ok "name that is only a random hex id pruned (junk-id)" || no "random-hex-id name pruned"
! has "$plan" "zdigit24" && ok "all-digit name '12345678' not treated as a random id"  || no "'12345678' not a random id"

# --- rule D: generated-bulk families, decided by the corpus ---
# The three families are identical except for the one variable each tests, so these assertions
# isolate a single cause. Every zspam* member must be pruned, including the LAST one, since the
# family-extension pass is what carries stragglers whose random slot came out all-digits.
spamhits=$(grep -cE "^zspam[1-9] .*spam-family" <<<"$plan" || true)
[ "$spamhits" = 9 ] && ok "templated family (id slot + one description) pruned (spam-family)" || no "spam family pruned (got $spamhits/9)"
decoyhits=$(grep -cE "^zdecoy[1-9] " <<<"$plan" || true)
[ "$decoyhits" = 0 ] && ok "same name shape but real per-repo descriptions kept (mirror farm)" || no "decoy family kept (got $decoyhits/9 pruned)"
enumhits=$(grep -cE "^zenum[1-9] " <<<"$plan" || true)
[ "$enumhits" = 0 ] && ok "enumeration-only family kept by default (SPAM_REQUIRE_ID=1)" || no "enum family kept (got $enumhits/9 pruned)"
datehits=$(grep -cE "^zdate[1-9] " <<<"$plan" || true)
[ "$datehits" = 0 ] && ok "date-suffixed family kept (a digit run is an enumeration, not an id)" || no "date family kept (got $datehits/9 pruned)"
nodeschits=$(grep -cE "^znodesc[1-9] " <<<"$plan" || true)
[ "$nodeschits" = 0 ] && ok "id-slot family with no descriptions kept (one signal is not enough)" || no "no-description family kept (got $nodeschits/9 pruned)"
grep -qE '^# spam families: 1 template' <<<"$plan" && ok "the plan header reports the family it found" || no "plan header reports spam families"

# The gate must be able to say no: raise the family threshold above the family size and the exact
# same repos have to survive, or the rule is passing on something other than the evidence it claims.
plan_k=$(SPAM_MIN_FAMILY=11 run)   # the evens family is 10 members
[ "$(grep -cE "^zspam[1-9] " <<<"$plan_k" || true)" = 0 ] && ok "SPAM_MIN_FAMILY above the family size spares it" || no "SPAM_MIN_FAMILY gate is vacuous"
# ...and so must the description-agreement gate, on its own.
plan_d=$(SPAM_DESC_AGREE_PCT=101 run)
[ "$(grep -cE "^zspam[1-9] " <<<"$plan_d" || true)" = 0 ] && ok "unreachable description agreement spares the family" || no "SPAM_DESC_AGREE_PCT gate is vacuous"
# Opting out of the random-id requirement is what reaches an enumeration-only family.
plan_id=$(SPAM_REQUIRE_ID=0 run)
{ [ "$(grep -cE "^zenum[1-9] .*spam-family" <<<"$plan_id" || true)" = 9 ] \
  && [ "$(grep -cE "^zdecoy[1-9] " <<<"$plan_id" || true)" = 0 ]; } \
  && ok "SPAM_REQUIRE_ID=0 reaches enumeration families, still not the decoy" || no "SPAM_REQUIRE_ID=0 reaches enum family"
# --- taking the last copy WE KNOW OF, but only where the evidence is conclusive ---
# "No other seed has it" is worthlessness for machine-generated bulk and preservation value for
# anything else, so the two rule-A branches are gated apart and rule C is not in this game at all.
has "$plan" "zhexzero27" && grep -qE "^zhexzero27 .*junk-id" <<<"$plan" \
  && ok "zero-seed random-id name is pruned (junk-id takes the last copy)" || no "zero-seed junk-id pruned"
! has "$plan" "zwordzero28" \
  && ok "zero-seed 'test-orphan' is kept (a word in a name is a guess, not proof)" || no "zero-seed junk-name kept"
has "$plan" "zspamzero" && grep -qE "^zspamzero .*spam-family" <<<"$plan" \
  && ok "zero-seed spam family member is pruned" || no "zero-seed spam-family pruned"

# Both new floors must be able to say no, or they are decoration.
plan_i=$(JUNK_ID_MIN_SEEDS=1 run)
! has "$plan_i" "zhexzero27" && has "$plan_i" "zhexid23" \
  && ok "JUNK_ID_MIN_SEEDS=1 spares the zero-seed id repo, keeps the seeded one" || no "JUNK_ID_MIN_SEEDS gate is vacuous"
# ...and the word branch's floor must be the REASON zwordzero28 survives, not a coincidence of it
# also failing every other rule: drop the floor and it has to appear.
plan_w=$(JUNK_MIN_SEEDS=0 run)
grep -qE "^zwordzero28 .*junk-name" <<<"$plan_w" \
  && ok "JUNK_MIN_SEEDS=0 does reach the zero-seed word repo (so the keep above is real)" || no "zero-seed junk-name keep is vacuous"
plan_s=$(SPAM_MIN_SEEDS=1 run)
! has "$plan_s" "zspamzero" && has "$plan_s" "zspam1" \
  && ok "SPAM_MIN_SEEDS=1 spares the zero-seed spam repo, keeps the seeded ones" || no "SPAM_MIN_SEEDS gate is vacuous"

# A repo whose description quotes an rid must still be filed under its OWN rid, not the quoted one.
# Regression: a description may itself quote an rid ("...used for the site in rad:z3U9..."), and
# taking the LAST rad: token on the row filed the whole repo under the rid it merely mentioned.
grep -qE "^zridin25 .*ridquoter$" <<<"$plan" && ok "a description quoting an rid still files under the row's own rid" || no "row filed under its own rid"
# Regression: the name column was read as field 2, so any name with a space was silently truncated
# ("Blog e64" became "Blog") - and a truncated name is what rule D skeletonises.
grep -qE "^zspaced26 .*Blog e64$" <<<"$plan" && ok "a name containing spaces survives the parse" || no "spaced name survives the parse"

# --- an empty `rad ls` degrades loudly: blank names and a blind rule D look exactly like a clean seed ---
out=$(RSP_NO_LS=1 DISK_AWARE=0 ABS_SIZE_FLOOR_MB=1 run)
{ grep -q "WARN: .*returned no repos" <<<"$out" && ! grep -q '^# spam families' <<<"$out"; } \
  && ok "an empty repo listing is reported, not silently read as 'no spam'" || no "empty repo listing warns"

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
# Three unreadable repos against a 1% limit, so the assertion does not ride on the fixture size.
# Without this the run would report a plausible-looking small plan built from a partial scan.
for r in zjunk1 zbig2 zbar8; do chmod 000 "$STORAGE/$r"; done
out=$(DISK_AWARE=0 ABS_SIZE_FLOOR_MB=1 MAX_SCAN_FAIL_PCT=1 "$SCRIPT" 2>&1); rc=$?
for r in zjunk1 zbig2 zbar8; do chmod 755 "$STORAGE/$r"; done
{ [ "$rc" = 5 ] && grep -q "could not read 3 of $NREPOS repos" <<<"$out" && ! grep -q '# PLAN:' <<<"$out"; } \
  && ok "blind scan aborts instead of reporting a small plan" || no "blind scan aborts (got exit $rc)"

# --- every walk in the scan can fail mid-flight without taking the run down ---
# Regression: the repo-counting walk was the one find call left unguarded, so on a busy seed the run
# died at the very first line of the scan, before printing anything a bug report could use.
shimdir="$ROOT/shim"; mkdir -p "$shimdir"; cp "$HERE/find-shim" "$shimdir/find"; chmod +x "$shimdir/find"
out=$(PATH="$shimdir:$PATH" DISK_AWARE=0 ABS_SIZE_FLOOR_MB=1 "$SCRIPT" 2>&1); rc=$?
{ [ "$rc" = 0 ] && grep -q "# scanning $NREPOS repos" <<<"$out" && has "$out" "zjunk1"; } \
  && ok "a failing find in the scan is survived, not fatal" || no "failing find survived (got exit $rc)"
grep -qE '^# WARN: [0-9]+ scan error' <<<"$out" && ok "a failing find is still reported as a scan error" || no "failing find reported"

# --- storage we cannot read is an abort, never a serene empty plan ---
# Running as the wrong user reads as zero repos, and zero repos reads as "nothing to do" rather than
# "I could not look".
chmod 000 "$STORAGE"
out=$(DISK_AWARE=0 "$SCRIPT" 2>&1); rc=$?
chmod 755 "$STORAGE"
{ [ "$rc" = 1 ] && grep -q 'cannot read storage dir' <<<"$out" && ! grep -q '# PLAN:' <<<"$out"; } \
  && ok "unreadable storage dir aborts (no empty plan)" || no "unreadable storage aborts (got exit $rc)"

# --- fail-safe: node down aborts --apply before touching anything ---
RSP_NODE_DOWN=1 DISK_AWARE=0 ABS_SIZE_FLOOR_MB=1 "$SCRIPT" --apply >/dev/null 2>&1; rc=$?
[ "$rc" = 5 ] && ok "node-down aborts --apply (exit 5)" || no "node-down aborts --apply (got exit $rc)"

# --- apply: non-interactive (cron path) applies; interactive prompt (pty) obeys y/N ---
# non-interactive --apply (no controlling tty): applies directly, no prompt.
build_fixture; assert_isolated                    # fresh fixture before the tests that delete
DISK_AWARE=0 ABS_SIZE_FLOOR_MB=1 "${NOTTY[@]}" "$SCRIPT" --apply </dev/null >/dev/null 2>&1
gone=1; for r in zjunk1 zbig2 ztwoyr3 zbar8 zspam1 zspam9;             do [ -e "$STORAGE/$r" ] && gone=0; done
kept=1; for r in zfresh4 zpin6 zpriv7 zown22 zbwid9 zfews5 zdecoy1 zenum1; do [ -e "$STORAGE/$r" ] || kept=0; done
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

# The script anchors its cwd (cd /) so a launch directory the running user cannot read
# never turns every find into a "Failed to restore initial working directory" scan
# error. Both halves are guarded: the anchor, and the path resolution before it.
build_fixture; assert_isolated
blind="$ROOT/unreadable"; mkdir -p "$blind"
if [ "$(id -u)" != 0 ]; then
  out=$(cd "$blind" && chmod 000 . && "$SCRIPT" 2>&1); rc=$?
  chmod 755 "$blind"
  { [ "$rc" = 0 ] && ! grep -q 'Failed to restore initial working directory' <<<"$out" \
      && ! grep -q 'scan error' <<<"$out" && grep -q '# PLAN:' <<<"$out"; } \
    && ok "an unreadable launch directory produces no scan errors" || no "unreadable cwd is clean (rc=$rc)"
else
  echo "skip - unreadable-cwd test (running as root bypasses the mode bits)"
fi

# cd / must not change what a RELATIVE RAD_HOME/STORAGE/RAD meant to the caller.
build_fixture; assert_isolated
out=$(cd "$ROOT" && env RAD_HOME="./rad-home" STORAGE="./rad-home/storage" \
        CONFIG="./rad-home/config.json" AUDIT_DIR="./rad-home/prune-audit" \
        RAD="./bin/rad" "$SCRIPT" 2>&1); rc=$?
{ [ "$rc" = 0 ] && grep -qE '^zjunk1 ' <<<"$out" && grep -q '# PLAN:' <<<"$out"; } \
  && ok "relative RAD_HOME/STORAGE/RAD survive the cwd anchor" || no "relative paths survive cd / (rc=$rc)"

rm -rf "$ROOT"
# ============================================================================
echo "-----------------------------------------"
echo "passed: $PASS   failed: $FAIL"
[ "$FAIL" = 0 ]
