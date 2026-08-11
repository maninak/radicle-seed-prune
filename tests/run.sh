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
zwordzero28\ttest-orphan\t0\tpublic\t0\t300\t2000\ta real project
zfarm1\tgalleryalpha\t5\tpublic\t0\t90\t2000\tphoto notes
zfarm2\tgallerybeta\t5\tpublic\t0\t90\t2000\tsome pictures
zfarm3\tgallerygamma\t5\tpublic\t0\t90\t2000\tan album
zcode4\thonestproj\t5\tpublic\t0\t90\t2000\ta real project
zcode6\thonestlib\t5\tpublic\t0\t90\t2000\ta real project
zcode7\thonestapp\t5\tpublic\t0\t90\t2000\ta real project
zpoison5\tdecoyproj\t5\tpublic\t0\t90\t2000\tanother real project
zpoison9\tpixelvault\t5\tpublic\t0\t90\t2000\tmore pictures
zvictimten\tphotoclub\t5\tpublic\t0\t90\t2000\ta real project
zrot1\trotone\t5\tpublic\t0\t90\t2000\ta real project
zrot2\trottwo\t5\tpublic\t0\t90\t2000\ta real project
zrot3\trotthree\t5\tpublic\t0\t90\t2000\ta real project
zinfetch\tinflightproj\t5\tpublic\t0\t800\t2000\ta real project
zheavy\tbulkyproj\t5\tpublic\t0\t800\t2000\ta real project'

# Rule D is decided by the CORPUS, so it needs whole batches, and the batches below are a
# controlled experiment: all five are 9 repos, the same age, the same size, and a name skeleton
# with a variable slot. They differ in exactly one variable each, so a failure names its own cause.
#   zspam*   name has a random-id slot AND all 9 share one description template  -> pruned
#   zdecoy*  same name shape, but every repo carries its OWN real description    -> kept
#   zenum*   descriptions agree, but the varying slot is a plain enumeration     -> kept by default
#   znodesc* random-id slot, but no descriptions at all, so only ONE signal      -> kept
#   zdate*   agreeing descriptions and a 6+ digit slot, but no LETTER in it, so
#            it is a date/sequence rather than a random id                        -> kept
# 90 days old: too young for rules A and C, too small for B. None of the five carries a link, so a
# hit on any of them names rule D as its cause.
build_batches(){
  local i rows=""
  local hex=(- 33ed7115 6cf239e8 28036e03 1d9ce82f e9a0b26f df68129a 944f76e9 283bed8c 9e1437e9)
  # a mirror farm's descriptions differ in WORDS, the way real ones do, not merely in a number
  local word=(- gyroscope barometer thermometer altimeter magnetometer hygrometer photodiode tachometer voltmeter)
  # rids index from 1: 0 is not in the base58 alphabet, so a "zspam0" would be correctly rejected
  # as a malformed rid and the batch would come up one member short.
  for i in $(seq 1 9); do
    rows+="zspam$i\tflatten-$i-${hex[$i]}\t5\tpublic\t0\t90\t2000\tFlatten a nested array. Variant $i.\n"
    rows+="zdecoy$i\tmirror-$i-${hex[$i]}\t5\tpublic\t0\t90\t2000\tDriver for the ${word[$i]} breakout board\n"
    rows+="zenum$i\tmainline-$i\t5\tpublic\t0\t90\t2000\tMainline tree branch $i\n"
    rows+="znodesc$i\tblank-$i-${hex[$i]}\t5\tpublic\t0\t90\t2000\t\n"
    rows+="zdate$i\tsnapshot-2024010$i\t5\tpublic\t0\t90\t2000\tNightly snapshot $i\n"
  done
  rows+="zspamzero\tflatten-10-4b7e2c91\t0\tpublic\t0\t90\t2000\tFlatten a nested array. Variant 10.\n"
  rows+="zspamfresh\tflatten-11-7d3a9c22\t5\tpublic\t0\t90\t2000\tFlatten a nested array. Variant 11.\n"
  # a twelfth member, used by rule E: its own code links to a spam host, and rule D calling it
  # generated is what stops that link from vouching for the host
  rows+="zfamv12\tflatten-12-4c8d1e73\t5\tpublic\t0\t90\t2000\tFlatten a nested array. Variant 12.\n"
  # a thirteenth member whose refs are one day old, used by the first-seen ledger: on ref dates
  # alone it is too young for rule D, and only the ledger's older date reaches it
  rows+="zspamaged\tflatten-13-8f2a4d61\t5\tpublic\t0\t1\t2000\tFlatten a nested array. Variant 13.\n"
  printf '%b' "$rows"
}
MANIFEST_ROWS="$MANIFEST_ROWS"$'\n'"$(build_batches)"
NREPOS=79

# Rule E fixture helpers. Each writes one file holding the given lines, commits it 80 days back,
# pushes it to $rid, and puts the directory mtime back where the manifest loop left it so the
# freshness guard cannot step in. e_cob puts the links in an issue COB, e_code puts them on master.
e_push(){
  local rid=$1 ref=$2 file=$3; shift 3
  local w; w=$(mktemp -d -p "$ROOT")
  git -C "$w" init -q -b master
  git -C "$w" config user.email a@b; git -C "$w" config user.name a
  printf '%s\n' "$@" > "$w/$file"
  git -C "$w" add -A
  local ts; ts=$(date -u -d "80 days ago" +%s)
  GIT_AUTHOR_DATE="@$ts +0000" GIT_COMMITTER_DATE="@$ts +0000" git -C "$w" commit -q -m e
  git -C "$w" push -q --force "$STORAGE/$rid" "master:$ref"   # never silence this: a rejected push
  rm -rf "$w"                                                 # leaves a test passing on no evidence
  touch -d "10 days ago" "$STORAGE/$rid"
}
# The node id this fixture hands out as a delegate of $1. It has to survive the script's base58
# filter, so the rid's own characters are mapped into the alphabet and the rest is padding.
dlg(){
  local n="zDLG$1"
  printf '%s' "$n"
  local i=${#n}; while [ "$i" -lt 45 ]; do printf x; i=$((i+1)); done
}
# A COB lands in the namespace of whoever pushed it, which is how rule E tells a repo's own links
# from a passing stranger's, so every COB here names the peer it came from.
e_cob(){  local rid=$1 nid=$2; shift 2; e_push "$rid" "refs/namespaces/$nid/refs/cobs/xyz.radicle.issue/aaa" issue.json "$@"; }
e_code(){ local rid=$1; shift; e_push "$rid" master README.md "$@"; }

build_fixture(){
  [ -n "${ROOT:-}" ] && rm -rf "$ROOT" 2>/dev/null # re-runnable: drop the previous fixture
  ROOT=$(mktemp -d)
  trap 'rm -rf "$ROOT" 2>/dev/null' EXIT           # always clean up, even on failure
  local bin="$ROOT/bin"; mkdir -p "$bin"
  cp "$HERE/rad-stub" "$bin/rad"; chmod +x "$bin/rad"

  export RSP_HOME="$ROOT/rad-home"
  export RSP_NID="zOURNODExxxxxxxxxxxxxxxxxxxxx"
  export RSP_MANIFEST="$ROOT/manifest.tsv"
  export RSP_DELEGATES="$ROOT/delegates.tsv"

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
  # A rid outside the base58 alphabet never survives `rad ls` parsing, so its repo would sit
  # outside rule D's corpus and the plan's NAME column while every other rule still saw it.
  local badrid
  badrid=$(cut -f1 "$RSP_MANIFEST" | grep -vE '^z[1-9A-HJ-NP-Za-km-z]+$' | tr '\n' ' ')
  [ -z "$badrid" ] || { echo "ABORT: manifest rids are not base58: $badrid"; exit 3; }

  # one delegate per repo, so `rad inspect --delegates` answers for everything by default
  : > "$RSP_DELEGATES"
  local mrid
  while IFS=$'\t' read -r mrid _; do
    [ -z "$mrid" ] || printf '%s\t%s\n' "$mrid" "$(dlg "$mrid")" >> "$RSP_DELEGATES"
  done < "$RSP_MANIFEST"
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

  # Rule E fixture. Three spam hosts and two honest ones, over nine repos. The real thing has
  # hundreds of repos per host, so the tests below lower LINK_MIN_REPOS to 3 to match this scale.
  #
  #   zfarm1-3    spam repos. Three spam hosts each, linked from an issue COB rather than a branch,
  #               which is where the real spam lives.
  #   zcode4/6/7  honest repos whose own code links to github.example and github2.example. Three of
  #               those two hosts' four linkers are code, which is what keeps them off the spam-host
  #               list and is the reason zcode4/6/7 are never flagged.
  #   zpoison5    an ordinary repo whose code happens to link to spamhost-a. Nothing marks it
  #               suspect, so its link counts and spamhost-a really is disqualified at a low cap.
  #   zpoison9    a spam repo trying that same trick on spamhost-b. Pass 1 sees it link to three
  #               loose spam hosts and marks it suspect, so its link does not count.
  #   zfamv12     a rule D batch member trying it on spamhost-c. Rule D marks it, same outcome.
  #   zvictimten  an innocent repo a stranger pushed the same spam links to. Its own refs carry
  #               none of them, so the delegate check has to take it back out of the plan.
  #   zrot1-3     one link each, to three different subdomains of one domain. No hostname reaches
  #               the linker bar; the registrable domain does.
  local lrid extra
  for lrid in zfarm1 zfarm2 zfarm3; do
    # only zfarm1 cites the honest hosts. If all three did, github.example would sit at 25% code
    # and land between the two caps, which is a borderline case these tests do not want to depend on
    extra=""
    [ "$lrid" = zfarm1 ] && extra='built with https://github.example/tooling and https://github2.example/other'
    e_cob "$lrid" "$(dlg "$lrid")" '[View Full Gallery](https://spamhost-a.example/x)' \
                  '[![thumb](https://spamhost-b.example/1.jpg)](https://spamhost-a.example/1)' \
                  '[![thumb](https://spamhost-c.example/2.jpg)](https://spamhost-a.example/2)' \
                  "$extra"
  done
  for lrid in zcode4 zcode6 zcode7; do
    e_code "$lrid" 'see https://github.example/tooling and https://github2.example/other for docs'
  done
  e_code zpoison5 'mirror at https://spamhost-a.example/x'
  e_code zfamv12  'mirror at https://spamhost-c.example/x'
  e_cob  zpoison9 "$(dlg zpoison9)" '[gallery](https://spamhost-a.example/y)' \
                  '[![thumb](https://spamhost-b.example/9.jpg)](https://spamhost-c.example/9)'
  e_code zpoison9 'mirror at https://spamhost-b.example/y'
  # A stranger, not a delegate of zvictimten, files two spam links as an issue on it. Only
  # spamhost-b and -c, so the linker counts the other assertions rest on do not move.
  e_cob  zvictimten zSTRANGERxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx \
                  '[gallery](https://spamhost-b.example/v)' \
                  '[![thumb](https://spamhost-c.example/v.jpg)](https://spamhost-c.example/v)'
  e_cob  zrot1 "$(dlg zrot1)" '[gallery](https://a1.rotate.example/x)'
  e_cob  zrot2 "$(dlg zrot2)" '[gallery](https://b2.rotate.example/x)'
  e_cob  zrot3 "$(dlg zrot3)" '[gallery](https://c3.rotate.example/x)'

  # zspamfresh keeps its 90-day-old root commit but gains a COB authored yesterday, exactly the
  # shape the real spam has: created long ago, touched constantly. A rule D that clocks LAST
  # ACTIVITY spares it forever; one that clocks CREATION prunes it.
  local d="$STORAGE/zspamfresh" w ts
  w=$(mktemp -d -p "$ROOT")
  git -C "$w" init -q -b master
  git -C "$w" config user.email a@b; git -C "$w" config user.name a
  echo touched > "$w/cob"; git -C "$w" add -A
  ts=$(date -u -d "1 day ago" +%s)
  GIT_AUTHOR_DATE="@$ts +0000" GIT_COMMITTER_DATE="@$ts +0000" git -C "$w" commit -q -m recent
  git -C "$w" push -q "$d" master:refs/cobs/xyz.radicle.issue/recent 2>/dev/null
  rm -rf "$w"
  touch -d "10 days ago" "$d"

  # zspamaged's refs are a day old, so on ref dates alone rules D and E cannot touch it. This seed
  # says it has been here for over a year, which is the date those rules are supposed to use.
  mkdir -p "$AUDIT_DIR"
  printf 'zspamaged\t%s\n' "$(date -u -d "400 days ago" +%s)" > "$AUDIT_DIR/first-seen.tsv"
  # A ledger appended to for years will eventually carry a line torn by a crash mid-write.
  printf 'zfresh4\tnot-a-date\n' >> "$AUDIT_DIR/first-seen.tsv"

  touch "$STORAGE/zinfetch"        # a fetch landing right now: inside the freshness guard

  # zheavy gets enough loose objects that merely listing them fills a pipe buffer. Under a small
  # LINK_REPO_BUDGET the harvest stops reading mid-list and the lister dies of SIGPIPE, which is
  # the cap working and must not be read as a repo we could not open. Written straight into the
  # object store, because the harvest lists objects rather than refs, so no commit is needed.
  w=$(mktemp -d -p "$ROOT")
  local i=0
  while [ "$i" -lt 3000 ]; do printf 'x%s' "$i" > "$w/$i"; i=$((i+1)); done
  ls -d "$w"/* | GIT_DIR="$STORAGE/zheavy" git hash-object -w --stdin-paths > /dev/null
  rm -rf "$w"
  touch -d "10 days ago" "$STORAGE/zheavy"
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
! has "$plan" "zfews5"  && ok "stale but under-seeded repo kept (seed floor)" || no "under-seeded repo kept"
! has "$plan" "zpin6"   && ok "pinned repo excluded"            || no "pinned repo excluded"
! has "$plan" "zpriv7"  && ok "private repo excluded"           || no "private repo excluded"
! has "$plan" "zown22"  && ok "own repo excluded"               || no "own repo excluded"
! has "$plan" "zbwid9"  && ok "'BAR_widget' not treated as junk" || no "'BAR_widget' not junk"
has "$plan" "zhexid23" && grep -qE "^zhexid23 .*junk-id" <<<"$plan" && ok "name that is only a random hex id pruned (junk-id)" || no "random-hex-id name pruned"
! has "$plan" "zdigit24" && ok "all-digit name '12345678' not treated as a random id"  || no "'12345678' not a random id"

# --- rule D: generated-bulk batches, decided by the corpus ---
# The three batches are identical except for the one variable each tests, so these assertions
# isolate a single cause. Every zspam* member must be pruned, including the LAST one, since the
# batch-extension pass is what carries stragglers whose random slot came out all-digits.
spamhits=$(grep -cE "^zspam[1-9] .*spam-batch" <<<"$plan" || true)
[ "$spamhits" = 9 ] && ok "templated batch (id slot + one description) pruned (spam-batch)" || no "spam batch pruned (got $spamhits/9)"
decoyhits=$(grep -cE "^zdecoy[1-9] " <<<"$plan" || true)
[ "$decoyhits" = 0 ] && ok "same name shape but real per-repo descriptions kept (mirror farm)" || no "decoy batch kept (got $decoyhits/9 pruned)"
enumhits=$(grep -cE "^zenum[1-9] " <<<"$plan" || true)
[ "$enumhits" = 0 ] && ok "enumeration-only batch kept by default (SPAM_REQUIRE_ID=1)" || no "enum batch kept (got $enumhits/9 pruned)"
datehits=$(grep -cE "^zdate[1-9] " <<<"$plan" || true)
[ "$datehits" = 0 ] && ok "date-suffixed batch kept (a digit run is an enumeration, not an id)" || no "date batch kept (got $datehits/9 pruned)"
nodeschits=$(grep -cE "^znodesc[1-9] " <<<"$plan" || true)
[ "$nodeschits" = 0 ] && ok "id-slot batch with no descriptions kept (one signal is not enough)" || no "no-description batch kept (got $nodeschits/9 pruned)"
grep -qE '^# spam batches: 1 template' <<<"$plan" && ok "the plan header reports the batch it found" || no "plan header reports spam batches"

# The check must be able to say no: raise the batch threshold above the batch size and the exact
# same repos have to survive, or the rule is passing on something other than the evidence it claims.
plan_k=$(SPAM_MIN_BATCH=14 run)   # the flatten batch is 13 members
[ "$(grep -cE "^zspam[1-9] " <<<"$plan_k" || true)" = 0 ] && ok "SPAM_MIN_BATCH above the batch size spares it" || no "SPAM_MIN_BATCH check is vacuous"
# ...and so must the description-agreement check, on its own.
plan_d=$(SPAM_DESC_AGREE_PCT=101 run)
[ "$(grep -cE "^zspam[1-9] " <<<"$plan_d" || true)" = 0 ] && ok "unreachable description agreement spares the batch" || no "SPAM_DESC_AGREE_PCT check is vacuous"
# Opting out of the random-id requirement is what reaches an enumeration-only batch.
plan_id=$(SPAM_REQUIRE_ID=0 run)
{ [ "$(grep -cE "^zenum[1-9] .*spam-batch" <<<"$plan_id" || true)" = 9 ] \
  && [ "$(grep -cE "^zdecoy[1-9] " <<<"$plan_id" || true)" = 0 ]; } \
  && ok "SPAM_REQUIRE_ID=0 reaches enumeration batches, still not the decoy" || no "SPAM_REQUIRE_ID=0 reaches enum batch"
# --- rule D clocks CREATION, not last activity ---
# The spammer appends a COB to their own repos every few days, which under last-activity gating
# resets the clock and makes the whole batch permanently immune. Creation only moves forward.
has "$plan" "zspamfresh" && grep -qE "^zspamfresh .*spam-batch" <<<"$plan" \
  && ok "spam repo created 90d ago but touched yesterday is still pruned" || no "rule D clocks creation"
# ...and the window must still be able to spare a batch that is genuinely new.
plan_b=$(SPAM_STALE_DAYS=99999 run)
[ "$(grep -cE "^zspam" <<<"$plan_b" || true)" = 0 ] \
  && ok "SPAM_STALE_DAYS spares a batch younger than the window" || no "rule D creation window is vacuous"
# --- rule E: link farms ---
# Thresholds are lowered so three fixture repos can stand in for the hundreds a real wave has.
plan_e=$(LINK_MIN_REPOS=3 LINK_MIN_SCORE=2 run)
[ "$(grep -cE "^zfarm[1-3] .*link-farm" <<<"$plan_e" || true)" = 3 ] \
  && ok "repos linking to hosts almost no code links to are pruned as link-farm" || no "rule E does not fire"
# The whole point of the second half of the rule: a host that appears in somebody's own code is a
# dependency, not spam, so it must not count towards any repo's score. github.example clears the
# LINK_MIN_REPOS bar just as the spam hosts do, and must still be ignored.
! grep -qE "^zcode4 " <<<"$plan_e" \
  && ok "a repo linking only to hosts its own code links to is spared" || no "rule E flags an honest repo"
# One repo linking to a host from its code must NOT disqualify that host for the whole seed,
# because publishing such a repo is free and would immunise anything a spammer is selling.
plan_ep=$(LINK_MIN_REPOS=3 LINK_MIN_SCORE=2 LINK_CODE_MAX_PCT=30 run)
[ "$(grep -cE "^zfarm[1-3] .*link-farm" <<<"$plan_ep" || true)" = 3 ] \
  && ok "one code link does not disqualify a spam host" || no "a single repo can veto a spam host"
# ...and the percentage must still be able to disqualify: at 20% the one code link out of four
# linkers is 25%, over the bar, so spamhost-a stops counting and the score drops below 2.
plan_eq=$(LINK_MIN_REPOS=3 LINK_MIN_SCORE=3 LINK_CODE_MAX_PCT=20 run)
[ "$(grep -cE "^zfarm[1-3] " <<<"$plan_eq" || true)" = 0 ] \
  && ok "LINK_CODE_MAX_PCT still disqualifies a widely code-linked host" || no "LINK_CODE_MAX_PCT is vacuous"
# A code link only counts when the repo it comes from is not itself suspect, or a spammer clears
# any host they like using repos they already have. The two ways a repo becomes suspect are tested
# separately, each against its own host, and each against the knob that switches it off.
grep -q 'spamhost-b.example' <<<"$plan_e" \
  && ok "a link farm cannot vouch for the host it is selling (pass 1)" || no "pass-1 suspects still vouch"
grep -q 'spamhost-c.example' <<<"$plan_e" \
  && ok "a rule D batch member cannot vouch either" || no "rule D members still vouch"
# ...and suspicion must stay narrow: zpoison5 is an ordinary repo, so its code link does count and
# spamhost-a is genuinely disqualified at the default cap.
! grep -q 'spamhost-a.example' <<<"$plan_e" \
  && ok "an ordinary repo's code link still disqualifies a host" || no "suspicion is applied too widely"
# Non-vacuity for each of those, via the knob that decides who is suspect.
plan_el=$(LINK_MIN_REPOS=3 LINK_MIN_SCORE=2 LINK_CODE_LOOSE_PCT=0 run)
! grep -q 'spamhost-b.example' <<<"$plan_el" \
  && ok "LINK_CODE_LOOSE_PCT=0 marks nobody, so the vouch counts again" || no "LINK_CODE_LOOSE_PCT is vacuous"
plan_ed=$(LINK_MIN_REPOS=3 LINK_MIN_SCORE=2 SPAM_MIN_BATCH=99 run)
! grep -q 'spamhost-c.example' <<<"$plan_ed" \
  && ok "with no rule D batch, that member's vouch counts again" || no "the rule D leg is vacuous"
# Non-vacuity: the same repos must survive when the rule cannot see them.
plan_e0=$(LINK_SCAN=0 LINK_MIN_REPOS=3 LINK_MIN_SCORE=2 run)
[ "$(grep -cE "^zfarm[1-3] " <<<"$plan_e0" || true)" = 0 ] \
  && ok "LINK_SCAN=0 spares them, so the hits above came from rule E" || no "rule E hits are vacuous"
# ...and when they are too few to look like a pattern.
plan_e1=$(LINK_MIN_REPOS=99 LINK_MIN_SCORE=2 run)
[ "$(grep -cE "^zfarm[1-3] " <<<"$plan_e1" || true)" = 0 ] \
  && ok "a host too few repos link to is not a spam host" || no "LINK_MIN_REPOS is vacuous"
# ...and when the score they reach is below the bar.
plan_e2=$(LINK_MIN_REPOS=3 LINK_MIN_SCORE=99 run)
[ "$(grep -cE "^zfarm[1-3] " <<<"$plan_e2" || true)" = 0 ] \
  && ok "LINK_MIN_SCORE spares a repo below the bar" || no "LINK_MIN_SCORE is vacuous"
# Rule E clocks creation like rule D, so its window must be able to spare a genuinely new repo.
plan_e3=$(LINK_MIN_REPOS=3 LINK_MIN_SCORE=2 LINK_STALE_DAYS=99999 run)
[ "$(grep -cE "^zfarm[1-3] " <<<"$plan_e3" || true)" = 0 ] \
  && ok "LINK_STALE_DAYS spares a link farm younger than the window" || no "rule E creation window is vacuous"

# --- rule E: only the repo's own peers' links count ---
# Anybody may push an issue to any public repo and it lands in that repo's storage here. Left
# alone, five spam links in five issues would put somebody else's repo in the plan.
! has "$plan_e" "zvictimten" \
  && ok "spam links a stranger pushed do not flag the repo they landed in" || no "rule E flags a repo over a stranger's links"
plan_ex=$(LINK_MIN_REPOS=3 LINK_MIN_SCORE=2 LINK_DELEGATE_CHECK=0 run)
grep -qE "^zvictimten .*link-farm" <<<"$plan_ex" \
  && ok "LINK_DELEGATE_CHECK=0 does flag it, so the spare above is the check working" || no "LINK_DELEGATE_CHECK is vacuous"
grep -qF '# rule E: 1 repo(s) spared, the spam links were pushed by peers that are not their delegates' <<<"$plan_e" \
  && ok "the plan says how many repos the delegate check took back out" || no "delegate check reports its drops"
# Without a delegate list there is no way to tell a repo's own links from a stranger's, so the
# repo leaves the plan rather than staying in it on evidence nobody can attribute.
grep -v "^zfarm1"$'\t' "$RSP_DELEGATES" > "$ROOT/deleg.partial"
plan_eu=$(RSP_DELEGATES="$ROOT/deleg.partial" LINK_MIN_REPOS=3 LINK_MIN_SCORE=2 run)
{ ! has "$plan_eu" "zfarm1" && [ "$(grep -cE "^zfarm[23] .*link-farm" <<<"$plan_eu" || true)" = 2 ]; } \
  && ok "a repo whose delegates cannot be read leaves the plan, its neighbours do not" || no "unreadable delegates leave the plan"
# ...and the two outcomes are counted apart: zfarm1 could not be attributed at all, zvictimten was
# attributed and cleared. Reporting both under one heading would misname one of them.
{ grep -qF 'rule E: 1 repo(s) spared, their delegates could not be read' <<<"$plan_eu" \
  && grep -qF '# rule E: 1 repo(s) spared, the spam links were pushed by peers' <<<"$plan_eu"; } \
  && ok "an unattributable repo is counted apart from a cleared one" || no "the two rule E outcomes are counted apart"

# --- rule E: hostnames are folded to their registrable domain before counting ---
# A wildcard DNS record and one subdomain per repo would otherwise keep every name below the
# linker bar for free. zrot1-3 link to one domain via three subdomains, one linker each.
{ grep -qE 'rotate\.example$' <<<"$plan_e" && ! grep -q 'a1\.rotate\.example' <<<"$plan_e"; } \
  && ok "subdomains of one domain count as one spam host" || no "subdomains folded to their domain"

# The linker bar is a share of storage with a floor under it, so "many repos link to it" means
# something both on a 200-repo seed and on a 100k-repo one.
plan_epc=$(LINK_MIN_REPOS=3 LINK_MIN_SCORE=2 LINK_MIN_REPOS_PCT=10 run)
[ "$(grep -cE "^zfarm[1-3] " <<<"$plan_epc" || true)" = 0 ] \
  && ok "LINK_MIN_REPOS_PCT raises the linker bar above the floor" || no "LINK_MIN_REPOS_PCT is vacuous"

# --- the creation clock cannot be reset by a push ---
# Every date inside a repo is set by whoever pushed it, so force-pushing every ref with fresh dates
# would renew rules D and E forever. What this seed recorded when it first saw the repo cannot be
# reached from outside, and the age those rules use is whichever of the two is older.
grep -qE "^zspamaged .*spam-batch" <<<"$plan" \
  && ok "day-old refs do not save a batch member the seed has held for a year" || no "first-seen ledger overrides young refs"
plan_fs=$(FIRST_SEEN=/dev/null run)
! has "$plan_fs" "zspamaged" \
  && ok "with no ledger it survives on its ref dates, so the prune above came from the ledger" || no "first-seen ledger is vacuous"
grep -q "^zjunk1"$'\t' "$AUDIT_DIR/first-seen.tsv" \
  && ok "the ledger records repos it had not seen before, on a dry run too" || no "the ledger is written on a dry run"
{ ! grep -q 'integer expression' <<<"$plan" && ! has "$plan" "zfresh4"; } \
  && ok "a torn ledger line is skipped, not fed to an arithmetic comparison" || no "a torn ledger line is skipped"

# --- what the run left alone is counted in the report, not silently absent ---
{ ! has "$plan" "zinfetch" \
    && grep -qE '^# skipped: [0-9]+ unreadable, 1 written in the last 2d, [0-9]+ with no readable refs' <<<"$plan"; } \
  && ok "a repo written mid-run is skipped and counted in the report" || no "the freshness guard is reported"
plan_fg=$(FRESH_GUARD_DAYS=0 run)
grep -qE "^zinfetch .*stale" <<<"$plan_fg" \
  && ok "FRESH_GUARD_DAYS=0 reaches it, so the skip above is the guard" || no "the freshness guard is vacuous"

# --- the AGE column reports the date the matching rule measured ---
# zspamfresh was created 90 days ago and touched yesterday. Printing its last activity beside a
# 7-day creation minimum reads as a bug in the tool rather than as the verdict it is.
[ "$(awk '$1=="zspamfresh"{print $4}' <<<"$plan")" = 90 ] \
  && ok "a spam-batch row shows the creation age its rule measured" || no "AGE column shows the rule's own clock"
[ "$(awk '$1=="zjunk1"{print $4}' <<<"$plan")" = 400 ] \
  && ok "a junk-name row still shows last activity" || no "AGE column still shows activity for rules A to C"

# --- a repo larger than the read budget is judged, not excluded ---
# Reaching LINK_REPO_BUDGET closes the harvest pipe early and kills the object lister with SIGPIPE.
# Read as a failure, that quietly drops every large repo from the plan, and past MAX_SCAN_FAIL_PCT
# it aborts the whole run.
plan_bud=$(LINK_REPO_BUDGET=100 run)
{ has "$plan_bud" "zheavy" && ! grep -q "could not read the contents" <<<"$plan_bud"; } \
  && ok "a repo bigger than the read budget is still judged" || no "the read budget excludes big repos"

# Rules A/B/C must keep clocking ACTIVITY: a repo touched yesterday is not abandoned.
! grep -qE "^zfresh4 " <<<"$plan" \
  && ok "an actively-used repo is still spared by the activity rules" || no "activity rules unaffected"

# --- taking the last copy WE KNOW OF, but only where the evidence is conclusive ---
# "No other seed has it" is worthlessness for machine-generated bulk and preservation value for
# anything else, so the two rule-A branches are gated apart and rule C is not in this game at all.
has "$plan" "zhexzero27" && grep -qE "^zhexzero27 .*junk-id" <<<"$plan" \
  && ok "zero-seed random-id name is pruned (junk-id takes the last copy)" || no "zero-seed junk-id pruned"
! has "$plan" "zwordzero28" \
  && ok "zero-seed 'test-orphan' is kept (a word in a name is a guess, not proof)" || no "zero-seed junk-name kept"
has "$plan" "zspamzero" && grep -qE "^zspamzero .*spam-batch" <<<"$plan" \
  && ok "zero-seed spam batch member is pruned" || no "zero-seed spam-batch pruned"

# Both new floors must be able to say no, or they are decoration.
plan_i=$(JUNK_ID_MIN_SEEDS=1 run)
! has "$plan_i" "zhexzero27" && has "$plan_i" "zhexid23" \
  && ok "JUNK_ID_MIN_SEEDS=1 spares the zero-seed id repo, keeps the seeded one" || no "JUNK_ID_MIN_SEEDS check is vacuous"
# ...and the word branch's floor must be the REASON zwordzero28 survives, not a coincidence of it
# also failing every other rule: drop the floor and it has to appear.
plan_w=$(JUNK_MIN_SEEDS=0 run)
grep -qE "^zwordzero28 .*junk-name" <<<"$plan_w" \
  && ok "JUNK_MIN_SEEDS=0 does reach the zero-seed word repo (so the keep above is real)" || no "zero-seed junk-name keep is vacuous"
plan_s=$(SPAM_MIN_SEEDS=1 run)
! has "$plan_s" "zspamzero" && has "$plan_s" "zspam1" \
  && ok "SPAM_MIN_SEEDS=1 spares the zero-seed spam repo, keeps the seeded ones" || no "SPAM_MIN_SEEDS check is vacuous"

# A repo whose description quotes an rid must still be filed under its OWN rid, not the quoted one.
# Regression: a description may itself quote an rid ("...used for the site in rad:z3U9..."), and
# taking the LAST rad: token on the row filed the whole repo under the rid it merely mentioned.
grep -qE "^zridin25 .*ridquoter$" <<<"$plan" && ok "a description quoting an rid still files under the row's own rid" || no "row filed under its own rid"
# Regression: the name column was read as field 2, so any name with a space was silently truncated
# ("Blog e64" became "Blog") - and a truncated name is what rule D skeletonises.
grep -qE "^zspaced26 .*Blog e64$" <<<"$plan" && ok "a name containing spaces survives the parse" || no "spaced name survives the parse"

# --- an empty `rad ls` degrades loudly: blank names and a blind rule D look exactly like a clean seed ---
out=$(RSP_NO_LS=1 DISK_AWARE=0 ABS_SIZE_FLOOR_MB=1 run)
{ grep -q "WARN: .*returned no repos" <<<"$out" && ! grep -q '^# spam batches' <<<"$out"; } \
  && ok "an empty repo listing is reported, not silently read as 'no spam'" || no "empty repo listing warns"

# --- disk-pressure: at full pressure, stale window shrinks + seed floor drops to 1 ---
plan_hi=$(DISK_AWARE=1 PRESSURE_CRIT_PCT=100 PRESSURE_CRIT_GB=99999999 PRESSURE_RELAX_PCT=100 PRESSURE_RELAX_GB=999999999 ABS_SIZE_FLOOR_MB=1 run)
grep -qE "pressure=100%" <<<"$plan_hi" && ok "pressure reaches 100% under forced watermarks" || no "pressure=100%"
has "$plan_hi" "zbwid9" && ok "pressure prunes a repo that was kept at p=0"   || no "pressure widens the net"
has "$plan_hi" "zfews5" && ok "pressure drops seed floor to 1 (under-seeded now pruned)" || no "pressure drops seed floor"
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
