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
# Neither pass nor fail: the machine cannot run this one. It still prints, so a
# permanently skipped check is visible rather than quietly absent.
skip(){ printf 'skip - %s\n' "$1"; }
# assert that "$2" (a plan text) contains / omits a repo line for rid $3 with optional reason
# $4
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
zridin25\tridquoter\t5\tpublic\t0\t800\t2000\tsite generator, see rad:zsomeotherrepo
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
zheavy\tbulkyproj\t5\tpublic\t0\t800\t2000\ta real project
zmediaone\tclipdump\t2\tpublic\t0\t60\t4096\ta clip
zmediatwo\treadmeclip\t2\tpublic\t0\t60\t100\ta clip with notes
zmediabin\tblobonly\t2\tpublic\t0\t60\t100\tone unrecognised file
zmediatiny\tthumbonly\t2\tpublic\t0\t60\t100\tone small picture
zmediafresh\tnewclip\t2\tpublic\t0\t5\t100\ta clip pushed this week
zmediazero\tlonelyclip\t0\tpublic\t0\t60\t100\ta clip nobody else seeds
zmediapeer\tpeerpushed\t2\tpublic\t0\t60\t100\ta stranger pushed a clip
zmediaraw\tunknownfile\t2\tpublic\t0\t60\t100\tone file of nothing in particular
zmediamd\tnotesonly\t2\tpublic\t0\t60\t100\tone big markdown file
zmediacob\tissueclip\t2\tpublic\t0\t60\t100\ta clip in the owner own issue
zmediapast\toldattach\t2\tpublic\t0\t60\t100\ta clip in an older comment
zmediazip\tzippedclip\t2\tpublic\t0\t60\t100\tone archive
zbatch1\tgallery\t2\tpublic\t0\t60\t100\tholiday pictures
zbatch2\talbum\t2\tpublic\t0\t60\t100\tsome things I made
zbatch3\treel\t2\tpublic\t0\t60\t100\tstuff
zbatch4\tmontage\t2\tpublic\t0\t60\t100\ta few videos
zbatch5\tclipset\t2\tpublic\t0\t60\t100\tmy own dump
zbatchodd\tsolocam\t2\tpublic\t0\t60\t100\tone of a kind
zmediabrk\tbracketname\t2\tpublic\t0\t60\t100\ta clip beside an odd filename
zmediaop\topfile\t2\tpublic\t0\t60\t100\ta clip beside a cob-shaped filename
zmediaman\tmanifile\t2\tpublic\t0\t60\t100\ta clip beside a cob manifest
zmediaspc\tspacename\t2\tpublic\t0\t60\t100\ta clip beside a filename with a space
zmediatorn\ttornlist\t2\tpublic\t0\t60\t100\ta clip whose listing cannot finish
zmediarefs\tmanyrefs\t2\tpublic\t0\t60\t100\ta clip under more refs than the cap
zmediawide\tlongreadme\t2\tpublic\t0\t60\t100\ta clip under a very long readme
zmediacut\tcutshort\t2\tpublic\t0\t60\t100\ta long readme over a broken listing
zmediamirr\tmirrored\t2\tpublic\t0\t60\t100\ta project a peer replicates
zmediacobm\tcobmirror\t2\tpublic\t0\t60\t100\tan issue thread a peer replicates
zpara1\tparahost1\t2\tpublic\t0\t60\t100\ta repo one peer keeps posting a clip into
zpara2\tparahost2\t2\tpublic\t0\t60\t100\tanother repo that peer posts into
zpara3\tparahost3\t2\tpublic\t0\t60\t100\ta third repo that peer posts into
zparaown\tcontribown\t2\tpublic\t0\t60\t100\ta repo the contributor delegates'

# Rule D is decided by the CORPUS, so it needs whole batches, and the batches below are a
# controlled experiment: all five are 9 repos, the same age, the same size, and a name skeleton
# with a variable slot. They differ in exactly one variable each, so a failure names its own
# cause.
#   zspam*   name has a random-id slot AND all 9 share one description template  -> pruned
#   zdecoy*  same name shape, but every repo carries its OWN real description    -> kept zenum*
#   descriptions agree, but the varying slot is a plain enumeration     -> kept by default
#   znodesc* random-id slot, but no descriptions at all, so only ONE signal      -> kept zdate*
#   agreeing descriptions and a 6+ digit slot, but no LETTER in it, so
#            it is a date/sequence rather than a random id                        -> kept
# 90 days old: too young for rules A and C, too small for B. None of the five carries a link,
# so a hit on any of them names rule D as its cause.
build_batches(){
  local i rows=""
  local hex=(- 33ed7115 6cf239e8 28036e03 1d9ce82f e9a0b26f
             df68129a 944f76e9 283bed8c 9e1437e9)
  # a mirror farm's descriptions differ in WORDS, the way real ones do, not merely in a number
  local word=(- gyroscope barometer thermometer altimeter magnetometer
               hygrometer photodiode tachometer voltmeter)
  # rids index from 1: 0 is not in the base58 alphabet, so a "zspam0" would be correctly
  # rejected as a malformed rid and the batch would come up one member short.
  for i in $(seq 1 9); do
    rows+="zspam$i\tflatten-$i-${hex[$i]}\t5\tpublic\t0\t90\t2000"
    rows+="\tFlatten a nested array. Variant $i.\n"
    rows+="zdecoy$i\tmirror-$i-${hex[$i]}\t5\tpublic\t0\t90\t2000"
    rows+="\tDriver for the ${word[$i]} breakout board\n"
    rows+="zenum$i\tmainline-$i\t5\tpublic\t0\t90\t2000\tMainline tree branch $i\n"
    rows+="znodesc$i\tblank-$i-${hex[$i]}\t5\tpublic\t0\t90\t2000\t\n"
    rows+="zdate$i\tsnapshot-2024010$i\t5\tpublic\t0\t90\t2000\tNightly snapshot $i\n"
  done
  rows+="zspamzero\tflatten-10-4b7e2c91\t0\tpublic\t0\t90\t2000"
  rows+="\tFlatten a nested array. Variant 10.\n"
  rows+="zspamfresh\tflatten-11-7d3a9c22\t5\tpublic\t0\t90\t2000"
  rows+="\tFlatten a nested array. Variant 11.\n"
  # a twelfth member, used by rule E: its own code links to a spam host, and rule D calling it
  # generated is what stops that link from vouching for the host
  rows+="zfamv12\tflatten-12-4c8d1e73\t5\tpublic\t0\t90\t2000"
  rows+="\tFlatten a nested array. Variant 12.\n"
  # a thirteenth member whose refs are one day old, used by the first-seen ledger: on ref dates
  # alone it is too young for rule D, and only the ledger's older date reaches it
  rows+="zspamaged\tflatten-13-8f2a4d61\t5\tpublic\t0\t1\t2000"
  rows+="\tFlatten a nested array. Variant 13.\n"
  printf '%b' "$rows"
}
MANIFEST_ROWS="$MANIFEST_ROWS"$'\n'"$(build_batches)"
NREPOS=111

# Rule E fixture helpers. Each writes one file holding the given lines, commits it 80 days
# back, pushes it to $rid, and puts the directory mtime back where the manifest loop left it so
# the freshness guard cannot step in. e_cob puts the links in an issue COB, e_code puts them on
# master.
e_push(){
  local rid=$1 ref=$2 file=$3; shift 3
  local w; w=$(mktemp -d -p "$ROOT")
  git -C "$w" init -q -b master
  git -C "$w" config user.email a@b; git -C "$w" config user.name a
  printf '%s\n' "$@" > "$w/$file"
  git -C "$w" add -A
  local ts; ts=$(date -u -d "80 days ago" +%s)
  GIT_AUTHOR_DATE="@$ts +0000" GIT_COMMITTER_DATE="@$ts +0000" git -C "$w" commit -q -m e
  # never silence this push: a rejected one leaves a test passing on no evidence
  git -C "$w" push -q --force "$STORAGE/$rid" "master:$ref"
  rm -rf "$w"
  touch -d "10 days ago" "$STORAGE/$rid"
}
# The node id this fixture hands out as a delegate of $1. It has to survive the script's base58
# filter, so the rid's own characters are mapped into the alphabet and the rest is padding.
dlg(){
  local n="zDLG$1"
  printf '%s' "$n"
  local i=${#n}; while [ "$i" -lt 45 ]; do printf x; i=$((i+1)); done
}
# A COB lands in the namespace of whoever pushed it, which is how rule E tells a repo's own
# links from a passing stranger's, so every COB here names the peer it came from.
e_cob(){
  local rid=$1 nid=$2; shift 2
  e_push "$rid" "refs/namespaces/$nid/refs/cobs/xyz.radicle.issue/aaa" issue.json "$@"
}
# Replaces one ref of $rid with a tree holding exactly the given "name:bytes" files, which is
# how rule F's fixtures control what a repo tracks. Random bytes, so nothing compresses to a
# different size than asked for, and the force-push leaves the manifest loop's own commit
# UNREACHABLE: a rule F that read the object store instead of the tree would still see it and
# reach a different verdict.
e_tree(){
  local rid=$1 days=$2 ref=$3; shift 3
  local w spec; w=$(mktemp -d -p "$ROOT")
  git -C "$w" init -q -b master
  git -C "$w" config user.email a@b; git -C "$w" config user.name a
  # Build on what the ref already holds, so a second call to the same ref adds a commit the way
  # a COB gains an op. Each call still declares the WHOLE tree: files it does not list are gone
  # from that commit, which is how an attachment ends up only in history.
  if GIT_DIR="$STORAGE/$rid" git rev-parse --verify -q "$ref" >/dev/null 2>&1; then
    git -C "$w" fetch -q "$STORAGE/$rid" "$ref" && git -C "$w" reset -q --hard FETCH_HEAD
    find "$w" -maxdepth 1 -type f -delete
  fi
  # "name:bytes" is random filler; the kind suffix writes a real file header instead, which is
  # what the content sniff recognises. Without one, a renamed video is indistinguishable from
  # any other unknown file and the test would be asserting the wrong thing. "same" pads with
  # zeros rather than noise, so two repos given it end up holding the very same blob.
  local name rest bytes kind
  for spec in "$@"; do
    name=${spec%%:*}; rest=${spec#*:}; bytes=${rest%%:*}
    kind=""; [ "$rest" != "$bytes" ] && kind=${rest#*:}
    mkdir -p "$(dirname "$w/$name")"
    case $kind in
      mp4)  printf '\0\0\0\40ftypisom' > "$w/$name"
            head -c "$((bytes-12))" /dev/urandom >> "$w/$name" ;;
      same) printf '\0\0\0\40ftypisom' > "$w/$name"
            head -c "$((bytes-12))" /dev/zero >> "$w/$name" ;;
      zip)  printf 'PK\3\4' > "$w/$name"
            head -c "$((bytes-4))" /dev/urandom >> "$w/$name" ;;
      *)    head -c "$bytes" /dev/urandom > "$w/$name" ;;
    esac
  done
  git -C "$w" add -A
  local ts; ts=$(date -u -d "$days days ago" +%s)
  GIT_AUTHOR_DATE="@$ts +0000" GIT_COMMITTER_DATE="@$ts +0000" git -C "$w" commit -q -m m
  git -C "$w" push -q --force "$STORAGE/$rid" "master:$ref"
  rm -rf "$w"
  touch -d "10 days ago" "$STORAGE/$rid"
}
e_code(){ local rid=$1; shift; e_push "$rid" master README.md "$@"; }

build_fixture(){
  [ -n "${ROOT:-}" ] && rm -rf "$ROOT" 2>/dev/null # re-runnable: drop the previous fixture
  ROOT=$(mktemp -d)
  trap 'rm -rf "$ROOT" 2>/dev/null' EXIT           # always clean up, even on failure
  local bin="$ROOT/bin"; mkdir -p "$bin"
  cp "$HERE/rad-stub" "$bin/rad"; chmod +x "$bin/rad"
  # A Debian seed runs mawk, which is stricter than gawk in ways that matter here: it ignores
  # a {n} interval regex instead of honouring it, and prints an integer over 2^31 as %.6g.
  # Test against it wherever it exists, or a program that only works under gawk ships green.
  local awkbin=${AWK:-$(command -v mawk || command -v awk)}
  ln -sf "$awkbin" "$bin/awk"
  export PATH="$bin:$PATH"
  echo "# awk under test: $(readlink -f "$awkbin")"

  export RSP_HOME="$ROOT/rad-home"
  export RSP_NID="zOURNODExxxxxxxxxxxxxxxxxxxxx"
  export RSP_MANIFEST="$ROOT/manifest.tsv"
  export RSP_DELEGATES="$ROOT/delegates.tsv"

  # ISOLATION: pin every input the script reads so a test can NEVER touch the real Radicle
  # home, even if the caller's shell exported RAD_HOME/RAD/STORAGE/etc. STORAGE in particular
  # confines all deletions to the temp dir (the script only rm's paths under "$STORAGE"/z*).
  export RAD="$bin/rad"
  export RAD_HOME="$RSP_HOME"
  export STORAGE="$RSP_HOME/storage"
  export CONFIG="$RSP_HOME/config.json"
  export AUDIT_DIR="$RSP_HOME/prune-audit"
  export OUR_NID="$RSP_NID"
  export SERVICE="rsp-test-does-not-exist.service"
  export PATH="$bin:$PATH"
  # Hermetic git: ignore the user's global/system config, so fixture commits never use their
  # signing key (gpgsign) or identity, and the host config can't change behaviour.
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
    # refs/rad/id is where rule F learns who the repo's delegates are. Real storage keeps the
    # identity document there and only the local node writes it, so a stranger's push cannot
    # move it. Committed at the repo's own date so it does not disturb the activity clocks.
    w=$(mktemp -d -p "$ROOT")
    git -C "$w" -c init.defaultBranch=master init -q
    git -C "$w" config user.email a@b; git -C "$w" config user.name a
    printf '{"delegates":["did:key:%s"]}\n' "$(dlg "$rid")" > "$w/id.json"
    git -C "$w" add -A
    GIT_AUTHOR_DATE="@$ts +0000" GIT_COMMITTER_DATE="@$ts +0000" git -C "$w" commit -q -m id
    git -C "$w" push -q "$d" master:refs/rad/id 2>/dev/null
    rm -rf "$w"
    touch -d "10 days ago" "$d"        # keep every dir out of the freshness guard
  done < "$RSP_MANIFEST"

  # Rule E fixture. Three spam hosts and two honest ones, over nine repos. The real thing has
  # hundreds of repos per host, so the tests below lower LINK_MIN_REPOS to 3 to match this
  # scale.
  #
  #   zfarm1-3    spam repos. Three spam hosts each, linked from an issue COB rather than
  #               a branch, which is where the real spam lives.
  #   zcode4/6/7  honest repos whose own code links to github.example and github2.example.
  #               Three of those two hosts' four linkers are code, which keeps them off the
  #               spam-host list and is why zcode4/6/7 are never flagged.
  #   zpoison5    an ordinary repo whose code happens to link to spamhost-a. Nothing marks
  #               it suspect, so its link counts and spamhost-a is disqualified at a low cap.
  #   zpoison9    a spam repo trying that trick on spamhost-b. Pass 1 sees it link to three
  #               loose spam hosts and marks it suspect, so its link does not count.
  #   zfamv12     a rule D batch member trying it on spamhost-c. Rule D marks it, same outcome.
  #   zvictimten  an innocent repo a stranger pushed the same spam links to. Its own refs carry
  #               none of them, so the delegate check has to take it back out of the plan.
  #   zrot1-3     one link each, to three subdomains of one domain. No hostname reaches
  #               the linker bar; the registrable domain does.
  local lrid extra
  for lrid in zfarm1 zfarm2 zfarm3; do
    # only zfarm1 cites the honest hosts. If all three did, github.example would sit at 25%
    # code and land between the two caps, which is a borderline case these tests do not want to
    # depend on
    extra=""
    [ "$lrid" = zfarm1 ] \
      && extra='built with https://github.example/tooling and https://github2.example/other'
    e_cob "$lrid" "$(dlg "$lrid")" '[View Full Gallery](https://spamhost-a.example/x)' \
      '[![thumb](https://spamhost-b.example/1.jpg)](https://spamhost-a.example/1)' \
      '[![thumb](https://spamhost-c.example/2.jpg)](https://spamhost-a.example/2)' \
                  "$extra"
  done
  for lrid in zcode4 zcode6 zcode7; do
    e_code "$lrid" \
      'see https://github.example/tooling and https://github2.example/other for docs'
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

  # zspamaged's refs are a day old, so on ref dates alone rules D and E cannot touch it. This
  # seed says it has been here for over a year, which is the date those rules are supposed to
  # use.
  mkdir -p "$AUDIT_DIR"
  printf 'zspamaged\t%s\n' "$(date -u -d "400 days ago" +%s)" > "$AUDIT_DIR/first-seen.tsv"
  # A ledger appended to for years will eventually carry a line torn by a crash mid-write.
  printf 'zfresh4\tnot-a-date\n' >> "$AUDIT_DIR/first-seen.tsv"
  # zbatch3 published the shared clip first, so the batch path has to leave it alone.
  printf 'zbatch3\t%s\n' "$(date -u -d "400 days ago" +%s)" >> "$AUDIT_DIR/first-seen.tsv"

  touch "$STORAGE/zinfetch"        # a fetch landing right now: inside the freshness guard

  # zheavy gets enough loose objects that merely listing them fills a pipe buffer. Under a
  # small LINK_REPO_BUDGET the harvest stops reading mid-list and the lister dies of SIGPIPE,
  # which is the cap working and must not be read as a repo we could not open. Written straight
  # into the object store, because the harvest lists objects rather than refs, so no commit is
  # needed.
  w=$(mktemp -d -p "$ROOT")
  local i=0
  while [ "$i" -lt 3000 ]; do printf 'x%s' "$i" > "$w/$i"; i=$((i+1)); done
  ls -d "$w"/* | GIT_DIR="$STORAGE/zheavy" git hash-object -w --stdin-paths > /dev/null
  rm -rf "$w"
  touch -d "10 days ago" "$STORAGE/zheavy"

  # Rule F fixtures. Each replaces the manifest loop's tree, so what the repo tracks is exactly
  # what is listed here. The suite runs with MEDIA_MIN_BYTES=20000, small enough to keep 40-odd
  # full runs fast; a separate test covers the shipped default. Sizes straddle that bar and
  # MEDIA_TEXT_MAX_BYTES (2048), so each repo differs from zmediaone in ONE thing.
  e_tree zmediaone   60 master "clip.mp4:40000"                 # media only          -> pruned
  e_tree zmediatwo   60 master "clip.mp4:40000" "README.md:8192" # a real README       -> kept
  e_tree zmediabin   60 master "payload.bin:40000:mp4"          # a video renamed     -> pruned
  e_tree zmediaraw   60 master "payload.bin:40000"               # unknown, and really -> kept
  e_tree zmediamd    60 master "notes.md:400000:mp4"            # a video called .md  -> pruned
  e_tree zmediatiny  60 master "thumb.png:10000"                 # under the byte bar  -> kept
  # A repo is only young if every one of its refs is, the identity ref included, so zmediafresh
  # carries a 5-day manifest row as well as a 5-day tree.
  e_tree zmediafresh  5 master "clip.mp4:40000"                  # too young           -> kept
  e_tree zmediazero  60 master "clip.mp4:40000"                  # no other seeds      -> kept
  # The same clip in a namespace, twice over. zmediacob's is the delegate's own, a dump hiding
  # in its owner's issue thread. zmediapeer's belongs to a passing stranger, and counting that
  # would let anybody delete anybody else's near-empty repo by pushing them a video. Both
  # canonical trees hold 100 bytes of text, so whose namespace it is, is the ONLY difference
  # between them.
  e_tree zmediacob   60 master "notes.txt:100"
  e_tree zmediacob   60 "refs/namespaces/$(dlg zmediacob)/refs/cobs/xyz.radicle.issue/aaa" \
                        "clip.mp4:40000"
  e_tree zmediazip   60 master "payload.dat:40000:zip"          # a zip of something  -> pruned
  # An attachment from an earlier op. The COB's tip holds only the later reply, so anything
  # reading the tip alone sees a repo with no media at all.
  local past=refs/namespaces/$(dlg zmediapast)/refs/cobs/xyz.radicle.issue/ccc
  e_tree zmediapast  60 master   "notes.txt:100"
  e_tree zmediapast  60 "$past"  "clip.mp4:40000"
  e_tree zmediapast  60 "$past"  "reply.txt:50"
  # The batch path: five repos publishing the SAME clip, each behind a README too big for the
  # single-repo budget. zbatchodd is the control, same README over a clip of its own, so the
  # only difference between it and the five is whether anybody else holds the file.
  e_tree zbatch1     60 master "clip.mp4:40000:same" "README.md:4096"
  e_tree zbatch2     60 master "clip.mp4:40000:same" "README.md:4096"
  e_tree zbatch3     60 master "clip.mp4:40000:same" "README.md:4096"
  e_tree zbatch4     60 master "clip.mp4:40000:same" "README.md:4096"
  e_tree zbatch5     60 master "clip.mp4:40000:same" "README.md:4096"
  e_tree zbatchodd   60 master "clip.mp4:40000:mp4"  "README.md:4096"
  # Two shapes that a real seed produced and the fixture did not. A file whose name is a lone
  # "[" is not a valid regex, so a classifier matching names by regex dies on it. A README
  # between the two text budgets is only looked past when the guard uses the wider one.
  e_tree zmediabrk    60 master "clip.mp4:40000:mp4" "[:20"
  # A Radicle COB op is a tree of files named 0, 1, ... beside a "manifest". Those are read as
  # text without being opened, so a 4 KB one blows the budget even though it holds a video
  # header. That is the price of not opening the millions of them a seed carries.
  e_tree zmediaop     60 master "clip.mp4:40000:mp4" "0:4096:mp4"
  e_tree zmediaman    60 master "clip.mp4:40000:mp4" "manifest:4096:mp4"
  # A path may hold spaces, so a classifier reading the last word of the line sees "0" here
  # and waves the file through as a COB op payload.
  e_tree zmediaspc    60 master "clip.mp4:40000:mp4" "notes 0:4096:mp4"
  # Every other fixture repo has two refs, refs/rad/id and master, so a cap of 2 singles this
  # one out and leaves the rest judged.
  e_tree zmediarefs   60 master "clip.mp4:40000:mp4"
  e_tree zmediarefs   60 extra  "other.mp4:40000:mp4"
  e_tree zmediawide   60 master "payload.dat:40000:mp4" "README.md:70000"
  # A repo whose listing dies part-way: the docs/ subtree is deleted from the object store
  # after the push, so the walk sees the clip, then fails before it can see the README that
  # would have spared the repo. A short list must not read as a repo holding less.
  e_tree zmediatorn   60 master "clip.mp4:40000:mp4" "docs/README.md:4096"
  torn_tree=$(GIT_DIR="$STORAGE/zmediatorn" git rev-parse 'master^{tree}:docs')
  rm -f "$STORAGE/zmediatorn/objects/${torn_tree:0:2}/${torn_tree:2}"
  # The README alone already holds more text than any verdict allows, so the walk can stop at
  # it. Everything after it is unreadable, exactly as in zmediatorn: a run that reads on
  # regardless tears and reports the repo unjudged, one that stops does not.
  e_tree zmediacut    60 master "README.md:70000" "clip.mp4:40000:mp4" "docs/note.md:4096"
  cut_tree=$(GIT_DIR="$STORAGE/zmediacut" git rev-parse 'master^{tree}:docs')
  rm -f "$STORAGE/zmediacut/objects/${cut_tree:0:2}/${cut_tree:2}"
  e_tree zmediapeer  60 master "notes.txt:100"
  local stranger=zSTRANGERxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
  # A project with a README on its branch and a clip attached to its owner's own issue, which
  # one peer replicates: replicating mirrors the branch, so the README is a blob a stranger's
  # refs hold too. Subtract on that and the README is gone while the un-mirrored clip stays,
  # leaving a real repo looking exactly like a dump.
  e_tree zmediamirr  60 master "README.md:8192"
  e_tree zmediamirr  60 "refs/namespaces/$(dlg zmediamirr)/refs/cobs/xyz.radicle.issue/aaa" \
                        "clip.mp4:40000"
  GIT_DIR="$STORAGE/zmediamirr" git update-ref \
    "refs/namespaces/$stranger/refs/heads/master" \
    "$(GIT_DIR="$STORAGE/zmediamirr" git rev-parse master)"
  e_tree zmediapeer  60 "refs/namespaces/$stranger/refs/cobs/xyz.radicle.issue/aaa" \
                        "clip.mp4:40000"
  # The same trap one layer in. This repo's text is not on its branch but in its owner's own
  # issue thread, and replicating mirrors COB refs as well as branches, so those op payloads
  # are blobs a stranger's refs hold too. Subtract on that and the repo's own writing is gone
  # while the clip on its branch stays, which is the dump shape exactly.
  e_tree zmediacobm  60 master "clip.mp4:70000:mp4" "README.md:64"
  e_tree zmediacobm  60 "refs/namespaces/$(dlg zmediacobm)/refs/cobs/xyz.radicle.issue/aaa" \
                        "0:60000"
  GIT_DIR="$STORAGE/zmediacobm" git update-ref \
    "refs/namespaces/$stranger/refs/cobs/xyz.radicle.issue/aaa" \
    "$(GIT_DIR="$STORAGE/zmediacobm" git rev-parse \
        "refs/namespaces/$(dlg zmediacobm)/refs/cobs/xyz.radicle.issue/aaa")"

  # Rule G fixture. Three peers push the very same clip ("same" pads with zeros, so all three
  # push one blob) into three repos none of them owns. Only the first is a parasite: the
  # second delegates zparaown, and the third also wrote something. Each repo keeps a README on
  # its own branch, so none of them is a media dump in its own right.
  local para=zPARASITExxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
  local writer=zWRITERxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
  local contrib; contrib=$(dlg zparaown)
  local r
  for r in zpara1 zpara2 zpara3; do
    e_tree "$r" 60 master "README.md:8192"
    e_tree "$r" 60 "refs/namespaces/$para/refs/cobs/xyz.radicle.issue/aaa" \
                   "clip.mp4:40000:same"
    e_tree "$r" 60 "refs/namespaces/$contrib/refs/cobs/xyz.radicle.issue/bbb" \
                   "clip.mp4:40000:same"
    e_tree "$r" 60 "refs/namespaces/$writer/refs/cobs/xyz.radicle.issue/ccc" \
                   "clip.mp4:40000:same"
  done
  e_tree zpara1   60 "refs/namespaces/$writer/refs/cobs/xyz.radicle.issue/ddd" "notes.md:8192"
  e_tree zparaown 60 master "README.md:4096"
}

# Defense in depth: refuse to run anything if STORAGE is not confined to the temp fixture.
assert_isolated(){
  case "$STORAGE" in
    "$ROOT"/*) : ;;
    *) echo "ABORT: STORAGE=$STORAGE is not under the test root $ROOT"; exit 3 ;;
  esac
}

# run the real script against the fixture; echoes combined output, sets RC
run(){ local out; out=$("$SCRIPT" "$@" 2>&1); RC=$?; printf '%s' "$out"; }

# drop the tty for the non-interactive --apply test
NOTTY=(); command -v setsid >/dev/null && NOTTY=(setsid)

# ============================================================================
build_fixture
assert_isolated                                   # STORAGE must be inside the temp fixture

# --- classification & exclusions (relaxed thresholds, disk-awareness off) ---
# PLAN_FULL because nearly every assertion below looks for one repo's row. The folding that
# hides those rows on a real 519-row plan gets its own test rather than silencing the rest.
export DISK_AWARE=0 ABS_SIZE_FLOOR_MB=1 MEDIA_MIN_BYTES=20000 PLAN_FULL=1
plan=$(run)
has "$plan" "zjunk1"  && grep -qE "^zjunk1 .*junk-name"     <<<"$plan" \
  && ok "junk-named stale repo pruned (junk-name)"     \
  || no "junk-named stale repo pruned"
has "$plan" "zbig2"   && grep -qE "^zbig2 .*size-outlier"   <<<"$plan" \
  && ok "big stale well-seeded repo pruned (size)"      \
  || no "big stale repo pruned"
has "$plan" "ztwoyr3" && grep -qE "^ztwoyr3 .*stale"        <<<"$plan" \
  && ok "2yr-stale well-seeded repo pruned (stale)"     \
  || no "2yr-stale repo pruned"
has "$plan" "zbar8"   && grep -qE "^zbar8 .*junk-name"      <<<"$plan" \
  && ok "whole-name 'bar' pruned (junk-name)"           \
  || no "'bar' pruned"
! has "$plan" "zfresh4" \
  && ok "recently-active repo kept"        \
  || no "recently-active repo kept"
! has "$plan" "zfews5"  \
  && ok "stale but under-seeded repo kept (seed floor)" \
  || no "under-seeded repo kept"
! has "$plan" "zpin6"   && ok "pinned repo excluded"            || no "pinned repo excluded"
! has "$plan" "zpriv7"  && ok "private repo excluded"           || no "private repo excluded"
! has "$plan" "zown22"  && ok "own repo excluded"               || no "own repo excluded"
! has "$plan" "zbwid9"  && ok "'BAR_widget' not treated as junk" || no "'BAR_widget' not junk"
has "$plan" "zhexid23" && grep -qE "^zhexid23 .*junk-id" <<<"$plan" \
  && ok "name that is only a random hex id pruned (junk-id)" \
  || no "random-hex-id name pruned"
! has "$plan" "zdigit24" \
  && ok "all-digit name '12345678' not treated as a random id"  \
  || no "'12345678' not a random id"

# --- rule D: generated-bulk batches, decided by the corpus ---
# The three batches are identical except for the one variable each tests, so these assertions
# isolate a single cause. Every zspam* member must be pruned, including the LAST one, since the
# batch-extension pass is what carries stragglers whose random slot came out all-digits.
spamhits=$(grep -cE "^zspam[1-9] .*spam-batch" <<<"$plan" || true)
[ "$spamhits" = 9 ] \
  && ok "templated batch (id slot + one description) pruned (spam-batch)" \
  || no "spam batch pruned (got $spamhits/9)"
decoyhits=$(grep -cE "^zdecoy[1-9] " <<<"$plan" || true)
[ "$decoyhits" = 0 ] \
  && ok "same name shape but real per-repo descriptions kept (mirror farm)" \
  || no "decoy batch kept (got $decoyhits/9 pruned)"
enumhits=$(grep -cE "^zenum[1-9] " <<<"$plan" || true)
[ "$enumhits" = 0 ] \
  && ok "enumeration-only batch kept by default (SPAM_REQUIRE_ID=1)" \
  || no "enum batch kept (got $enumhits/9 pruned)"
datehits=$(grep -cE "^zdate[1-9] " <<<"$plan" || true)
[ "$datehits" = 0 ] \
  && ok "date-suffixed batch kept (a digit run is an enumeration, not an id)" \
  || no "date batch kept (got $datehits/9 pruned)"
nodeschits=$(grep -cE "^znodesc[1-9] " <<<"$plan" || true)
[ "$nodeschits" = 0 ] \
  && ok "id-slot batch with no descriptions kept (one signal is not enough)" \
  || no "no-description batch kept (got $nodeschits/9 pruned)"
grep -qE '^# spam batches: 1 template' <<<"$plan" \
  && ok "the plan header reports the batch it found" \
  || no "plan header reports spam batches"

# The check must be able to say no: raise the batch threshold above the batch size and the
# exact same repos have to survive, or the rule is passing on something other than the evidence
# it claims.
plan_k=$(SPAM_MIN_BATCH=14 run)   # the flatten batch is 13 members
[ "$(grep -cE "^zspam[1-9] " <<<"$plan_k" || true)" = 0 ] \
  && ok "SPAM_MIN_BATCH above the batch size spares it" \
  || no "SPAM_MIN_BATCH check is vacuous"
# ...and so must the description-agreement check, on its own.
plan_d=$(SPAM_DESC_AGREE_PCT=101 run)
[ "$(grep -cE "^zspam[1-9] " <<<"$plan_d" || true)" = 0 ] \
  && ok "unreachable description agreement spares the batch" \
  || no "SPAM_DESC_AGREE_PCT check is vacuous"
# Opting out of the random-id requirement is what reaches an enumeration-only batch.
plan_id=$(SPAM_REQUIRE_ID=0 run)
idhits=$(grep -cE "^zenum[1-9] .*spam-batch" <<<"$plan_id" || true)
iddecoy=$(grep -cE "^zdecoy[1-9] " <<<"$plan_id" || true)
{ [ "$idhits" = 9 ] && [ "$iddecoy" = 0 ]; } \
  && ok "SPAM_REQUIRE_ID=0 reaches enumeration batches, still not the decoy" \
  || no "SPAM_REQUIRE_ID=0 reaches enum batch (got $idhits/9 enum, $iddecoy/9 decoy)"
# --- rule D clocks CREATION, not last activity ---
# The spammer appends a COB to their own repos every few days, which under last-activity gating
# resets the clock and makes the whole batch permanently immune. Creation only moves forward.
has "$plan" "zspamfresh" && grep -qE "^zspamfresh .*spam-batch" <<<"$plan" \
  && ok "spam repo created 90d ago but touched yesterday is still pruned" \
  || no "rule D clocks creation"
# ...and the window must still be able to spare a batch that is genuinely new.
plan_b=$(SPAM_STALE_DAYS=99999 run)
[ "$(grep -cE "^zspam" <<<"$plan_b" || true)" = 0 ] \
  && ok "SPAM_STALE_DAYS spares a batch younger than the window" \
  || no "rule D creation window is vacuous"
# --- rule E: link farms ---
# Thresholds are lowered so three fixture repos can stand in for the hundreds a real wave has.
plan_e=$(LINK_MIN_REPOS=3 LINK_MIN_SCORE=2 run)
[ "$(grep -cE "^zfarm[1-3] .*link-farm" <<<"$plan_e" || true)" = 3 ] \
  && ok "repos linking to hosts almost no code links to are pruned as link-farm" \
  || no "rule E does not fire"
# The whole point of the second half of the rule: a host that appears in somebody's own code is
# a dependency, not spam, so it must not count towards any repo's score. github.example clears
# the LINK_MIN_REPOS bar just as the spam hosts do, and must still be ignored.
! grep -qE "^zcode4 " <<<"$plan_e" \
  && ok "a repo linking only to hosts its own code links to is spared" \
  || no "rule E flags an honest repo"
# One repo linking to a host from its code must NOT disqualify that host for the whole seed,
# because publishing such a repo is free and would immunise anything a spammer is selling.
plan_ep=$(LINK_MIN_REPOS=3 LINK_MIN_SCORE=2 LINK_CODE_MAX_PCT=30 run)
[ "$(grep -cE "^zfarm[1-3] .*link-farm" <<<"$plan_ep" || true)" = 3 ] \
  && ok "one code link does not disqualify a spam host" \
  || no "a single repo can veto a spam host"
# ...and the percentage must still be able to disqualify: at 20% the one code link out of four
# linkers is 25%, over the bar, so spamhost-a stops counting and the score drops below 2.
plan_eq=$(LINK_MIN_REPOS=3 LINK_MIN_SCORE=3 LINK_CODE_MAX_PCT=20 run)
[ "$(grep -cE "^zfarm[1-3] " <<<"$plan_eq" || true)" = 0 ] \
  && ok "LINK_CODE_MAX_PCT still disqualifies a widely code-linked host" \
  || no "LINK_CODE_MAX_PCT is vacuous"
# A code link only counts when the repo it comes from is not itself suspect, or a spammer
# clears any host they like using repos they already have. The two ways a repo becomes suspect
# are tested separately, each against its own host, and each against the knob that switches it
# off.
grep -q 'spamhost-b.example' <<<"$plan_e" \
  && ok "a link farm cannot vouch for the host it is selling (pass 1)" \
  || no "pass-1 suspects still vouch"
grep -q 'spamhost-c.example' <<<"$plan_e" \
  && ok "a rule D batch member cannot vouch either" || no "rule D members still vouch"
# ...and suspicion must stay narrow: zpoison5 is an ordinary repo, so its code link does count
# and spamhost-a is genuinely disqualified at the default cap.
! grep -q 'spamhost-a.example' <<<"$plan_e" \
  && ok "an ordinary repo's code link still disqualifies a host" \
  || no "suspicion is applied too widely"
# Non-vacuity for each of those, via the knob that decides who is suspect.
plan_el=$(LINK_MIN_REPOS=3 LINK_MIN_SCORE=2 LINK_CODE_LOOSE_PCT=0 run)
! grep -q 'spamhost-b.example' <<<"$plan_el" \
  && ok "LINK_CODE_LOOSE_PCT=0 marks nobody, so the vouch counts again" \
  || no "LINK_CODE_LOOSE_PCT is vacuous"
plan_ed=$(LINK_MIN_REPOS=3 LINK_MIN_SCORE=2 SPAM_MIN_BATCH=99 run)
! grep -q 'spamhost-c.example' <<<"$plan_ed" \
  && ok "with no rule D batch, that member's vouch counts again" \
  || no "the rule D leg is vacuous"
# Non-vacuity: the same repos must survive when the rule cannot see them.
plan_e0=$(LINK_SCAN=0 LINK_MIN_REPOS=3 LINK_MIN_SCORE=2 run)
[ "$(grep -cE "^zfarm[1-3] " <<<"$plan_e0" || true)" = 0 ] \
  && ok "LINK_SCAN=0 spares them, so the hits above came from rule E" \
  || no "rule E hits are vacuous"
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
  && ok "LINK_STALE_DAYS spares a link farm younger than the window" \
  || no "rule E creation window is vacuous"

# --- rule E: only the repo's own peers' links count ---
# Anybody may push an issue to any public repo and it lands in that repo's storage here. Left
# alone, five spam links in five issues would put somebody else's repo in the plan.
! has "$plan_e" "zvictimten" \
  && ok "spam links a stranger pushed do not flag the repo they landed in" \
  || no "rule E flags a repo over a stranger's links"
plan_ex=$(LINK_MIN_REPOS=3 LINK_MIN_SCORE=2 LINK_DELEGATE_CHECK=0 run)
grep -qE "^zvictimten .*link-farm" <<<"$plan_ex" \
  && ok "LINK_DELEGATE_CHECK=0 does flag it, so the spare above is the check working" \
  || no "LINK_DELEGATE_CHECK is vacuous"
spared_msg='# rule E: 1 repo(s) spared, the spam links were pushed by peers that are not'
grep -qF "$spared_msg their delegates" <<<"$plan_e" \
  && ok "the plan says how many repos the delegate check took back out" \
  || no "delegate check reports its drops"
# Without a delegate list there is no way to tell a repo's own links from a stranger's, so the
# repo leaves the plan rather than staying in it on evidence nobody can attribute.
grep -v "^zfarm1"$'\t' "$RSP_DELEGATES" > "$ROOT/deleg.partial"
plan_eu=$(RSP_DELEGATES="$ROOT/deleg.partial" LINK_MIN_REPOS=3 LINK_MIN_SCORE=2 run)
{ ! has "$plan_eu" "zfarm1" \
    && [ "$(grep -cE "^zfarm[23] .*link-farm" <<<"$plan_eu" || true)" = 2 ]; } \
  && ok "a repo whose delegates cannot be read leaves the plan, its neighbours do not" \
  || no "unreadable delegates leave the plan"
# ...and the two outcomes are counted apart: zfarm1 could not be attributed at all, zvictimten
# was attributed and cleared. Reporting both under one heading would misname one of them.
{ grep -qF 'rule E: 1 repo(s) spared, their delegates could not be read' <<<"$plan_eu" \
  && grep -qF "$spared_msg" <<<"$plan_eu"; } \
  && ok "an unattributable repo is counted apart from a cleared one" \
  || no "the two rule E outcomes are counted apart"

# --- rule E: hostnames are folded to their registrable domain before counting ---
# A wildcard DNS record and one subdomain per repo would otherwise keep every name below the
# linker bar for free. zrot1-3 link to one domain via three subdomains, one linker each.
{ grep -qE 'rotate\.example$' <<<"$plan_e" && ! grep -q 'a1\.rotate\.example' <<<"$plan_e"; } \
  && ok "subdomains of one domain count as one spam host" \
  || no "subdomains folded to their domain"

# The linker bar is a share of storage with a floor under it, so "many repos link to it" means
# something both on a 200-repo seed and on a 100k-repo one.
plan_epc=$(LINK_MIN_REPOS=3 LINK_MIN_SCORE=2 LINK_MIN_REPOS_PCT=10 run)
[ "$(grep -cE "^zfarm[1-3] " <<<"$plan_epc" || true)" = 0 ] \
  && ok "LINK_MIN_REPOS_PCT raises the linker bar above the floor" \
  || no "LINK_MIN_REPOS_PCT is vacuous"

# --- rule F: media dumps --- Radicle storage is for collaborating on code, and a repo tracking
# a video and nothing else is using the seed as file hosting. The seven fixtures differ from
# each other in one thing each, so a failure names its own cause.
grep -qE "^zmediaone .*media-dump" <<<"$plan" \
  && ok "a repo tracking only media is pruned (media-dump)" || no "media-only repo pruned"
! has "$plan" "zmediatwo" \
  && ok "a README over the text budget spares a repo full of media" \
  || no "text budget spares a real repo"
grep -qE "^zmediabin .*media-dump" <<<"$plan" \
  && ok "a video renamed .bin is caught by its first bytes" \
  || no "content sniff catches a rename"
! has "$plan" "zmediaraw" \
  && ok "a file matching no signature counts as text, sparing the repo" \
  || no "unknown content spares the repo"
grep -qE "^zmediamd .*media-dump" <<<"$plan" \
  && ok "a video called README-sized .md is read too, not trusted by name" \
  || no "large text files are sniffed"
! has "$plan" "zmediatiny" \
  && ok "media under MEDIA_MIN_BYTES is not a dump" || no "MEDIA_MIN_BYTES spares a small repo"
! has "$plan" "zmediafresh" \
  && ok "MEDIA_STALE_DAYS spares a clip pushed this week" \
  || no "rule F age window spares a new repo"
! has "$plan" "zmediapeer" \
  && ok "a clip a stranger pushed is not the repo's own content" \
  || no "a stranger cannot get a repo deleted"
grep -qE "^zmediacob .*media-dump" <<<"$plan" \
  && ok "a clip in the delegate's own issue counts as the repo's" \
  || no "rule F sees delegate COBs"
grep -qE "^zmediazip .*media-dump" <<<"$plan" \
  && ok "an archive is judged like the media it hides" \
  || no "archives count as an opaque payload"
grep -qE "^zmediapast .*media-dump" <<<"$plan" \
  && ok "an attachment from an earlier comment counts, not just the newest one" \
  || no "rule F walks COB history"

# Three shapes a real 11k-repo seed threw at rule F. Each of these used to leave the repo with
# no usable totals, so each one is spared when it should be pruned.
grep -qE "^zmediabrk .*media-dump" <<<"$plan" \
  && ok "a file called \"[\" does not break the classifier" \
  || no "a filename that is not a valid regex breaks rule F"
! has "$plan" "zmediaop" \
  && ok "a file named like a COB op counts as text, unopened" \
  || no "COB op payloads are opened, which costs a seed most of rule F"
! has "$plan" "zmediaman" \
  && ok "a COB op's manifest counts as text, unopened" \
  || no "COB manifests are opened, which costs a seed most of rule F"
grep -qE "^zmediaspc .*media-dump" <<<"$plan" \
  && ok "a space in a path does not turn its last word into the filename" \
  || no "a file called \"notes 0\" passes as a COB op payload"
# The fragment left by a half-finished listing holds the clip and not the README, so judging it
# would delete the repo on the evidence that failed to arrive.
{ ! has "$plan" "zmediatorn" && grep -q 'unjudged' <<<"$plan"; } \
  && ok "a repo whose listing dies part-way is left unjudged, not pruned on the fragment" \
  || no "rule F judges a repo on a partial listing"
# zmediacut is the same broken listing behind a README that already clears the widest budget.
# Only zmediatorn is unjudged, so the walk must have stopped at that README and never reached
# the break: the verdict was settled, and the rest of the repo was never read. Reading on
# regardless makes this count 2.
{ ! has "$plan" "zmediacut" && grep -q 'left 1 repo(s) unjudged' <<<"$plan"; } \
  && ok "rule F stops reading a repo once its text clears the widest budget" \
  || no "the walk read past the point where the verdict was already settled"
# Only a delegate can move a branch or a tag, so what one holds is this repo's own content
# however many peers have a copy of it.
! has "$plan" "zmediamirr" \
  && ok "a peer replicating a repo does not subtract the repo's own branch from itself" \
  || no "replication erased zmediamirr's README and left it looking like a dump"
! has "$plan" "zmediacobm" \
  && ok "a peer replicating a repo does not subtract the repo's own COB text from itself" \
  || no "replication erased zmediacobm's issue thread and left it looking like a dump"

# --- a plan nobody reads is not a review --- A verdict decided by a pattern across many repos
# folds to one line once the group is big; a verdict decided by one repo's own metadata never
# folds, however many there are, because those are the rows that want eyes.
folded=$(PLAN_FULL=0 PLAN_COLLAPSE_ROWS=2 run)
{ grep -qE '^\([0-9]+ repos\) .* spam-batch' <<<"$folded" \
  && ! has "$folded" "zspam1"; } \
  && ok "a big corpus verdict folds to one line in the plan" \
  || no "spam-batch did not fold, so a 434-row group would print in full"
has "$folded" "zjunk1" \
  && ok "a verdict resting on one repo is always listed, never folded" \
  || no "a judgment-tier row was folded away where a human could not see it"
grep -q "PLAN_FULL=1" <<<"$folded" \
  && ok "the folded line says how to see what it hid" \
  || no "the plan folded rows without saying how to expand them"

# --- one spelling for turning a rule off --- Every rule answers to the same switch, including
# B and C, which used to have no off switch at all.
noa=$(RULES=BCDEFG run)
{ ! has "$noa" "zjunk1" && has "$noa" "zbig2"; } \
  && ok "a rule left out of RULES puts nothing in the plan" \
  || no "RULES=BCDEFG still pruned a rule A repo, or took rule B down with it"
grep -q 'A junk.*DISABLED: not in RULES' <<<"$noa" \
  && ok "the banner says which rules are switched off" \
  || no "a disabled rule was not marked in the banner"
nof=$(RULES=ABCDE run)
{ ! has "$nof" "zmediamd" && ! grep -q 'measuring repo trees' <<<"$nof"; } \
  && ok "a rule left out of RULES does not even run its scan" \
  || no "RULES=ABCDE still ran or planned rule F"


# --- rule G: parasite peers --- Three peers put the identical clip in the same three repos.
# Only one of them is accused, so each exemption is what separates it from the other two, not
# a shortage of evidence.
PARA=zPARASITExxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
WRITER=zWRITERxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
CONTRIB=$(dlg zparaown)
# Exported, not prefixed: run is a shell function, and an assignment in front of one does not
# reach the script it launches.
export PARASITE_MIN_REPOS=3 PARASITE_MIN_BYTES=65536 PARASITE_TEXT_MAX_BYTES=4096
gplan=$(run)
grep -q "PARASITE PEERS: 1" <<<"$gplan" && grep -q "$PARA" <<<"$gplan" \
  && ok "a peer posting one file into repos it does not own is reported (rule G)" \
  || no "rule G missed a peer republishing one file across repos it does not own"
! grep -q "$CONTRIB" <<<"$gplan" \
  && ok "a peer who delegates a repo somewhere in storage is never accused" \
  || no "rule G accused a delegate, whose block would stop their own repo replicating"
! grep -q "$WRITER" <<<"$gplan" \
  && ok "a peer who also wrote something is not a parasite" \
  || no "rule G accused a peer that contributed text"
{ ! has "$gplan" "zpara1" && ! has "$gplan" "zpara2" && ! has "$gplan" "zpara3"; } \
  && ok "rule G puts no repo in the plan; the peer is the finding" \
  || no "rule G pruned a repo somebody else pushed into"
grep -q -- "--block-peers" <<<"$gplan" \
  && ok "rule G reports without blocking until --block-peers is given" \
  || no "rule G did not say that blocking needs its own opt-in"
unset PARASITE_MIN_REPOS PARASITE_MIN_BYTES PARASITE_TEXT_MAX_BYTES

# --- numbers must not follow the operator's locale --- mawk honours LC_NUMERIC, so under a
# comma locale it hands back "2,52e+10" and the awk that reads it gets 2. The script pins
# LC_ALL=C; this checks the plan is byte-identical either way rather than eyeballing output.
if locale -a 2>/dev/null | grep -qix 'de_AT.utf8'; then
  # Plan rows only: the banner carries a timestamp, so two runs never match on it.
  # Both sides are pinned, because the machine running the suite may itself be on a comma
  # locale, in which case an unpinned baseline would match the comma run and prove nothing.
  # Exported rather than prefixed for the same reason as the rule G knobs above: run is a
  # shell function, and an assignment in front of one never reaches the script it launches.
  unset LC_ALL
  export LC_NUMERIC=C;             base=$(run | grep -v '^#')
  export LC_NUMERIC=de_AT.UTF-8;   comma=$(run | grep -v '^#')
  unset LC_NUMERIC
  [ -n "$base" ] && [ "$comma" = "$base" ] \
    && ok "a comma-decimal locale does not change the plan" \
    || no "the plan changes under LC_NUMERIC=de_AT.UTF-8; a number went through the locale"
else
  skip "no comma-decimal locale installed to test LC_ALL=C against"
fi
# Each worker is written to a file and run later, so a stray apostrophe inside one of their
# single-quoted awk programs is invisible to `bash -n` on the script itself. It closes the
# quote, and only the generated worker then fails to parse. Parse each one on its own.
badbody=""
# Discovered from the script, not listed here: a hand-kept list would silently stop covering
# whichever worker was added last, which is the exact moment this gate is worth having.
tags=$(grep -oE "<<'[A-Z]+'\$" "$SCRIPT" | tr -d "<'" | sort -u)
[ -n "$tags" ] || no "found no generated workers to parse; the gate has stopped working"
for tag in $tags; do
  awk -v tag="$tag" '$0 ~ ("<<" "\047" tag "\047$") { f=1; next }
                     f && $0 == tag { exit }
                     f' "$SCRIPT" > "$HERE/.body.$tag.sh"
  bash -n "$HERE/.body.$tag.sh" 2>/dev/null || badbody="$badbody $tag"
  rm -f "$HERE/.body.$tag.sh"
done
[ -z "$badbody" ] \
  && ok "every generated worker parses on its own" \
  || no "generated worker(s)$badbody do not parse; a quote inside one is unbalanced"

# mawk prints any integral value over 2^31 with "%.6g", so an unformatted 3 GB size arrives as
# "2.81904e+09" and the shell reading it stops dead. This machine's awk prints it in full, so
# no fixture can reach the bug from here: pin the formats that avoid it instead.
# Both counts come from the script, so a new printf that emits a byte count without %.0f
# raises the first and not the second. A fixed number here would instead go red for any new
# printf at all, formatted or not, which is a gate that cries wolf until someone edits it.
emitre='printf "[^"]*", *[^;]*\b(size|media|text|unk|other)\b'
fmtre='printf "[^"]*%\.0f[^"]*", *[^;]*\b(size|media|text|unk|other)\b'
nemit=$(grep -cE "$emitre" "$SCRIPT"); nfmt=$(grep -cE "$fmtre" "$SCRIPT")
{ [ "$nemit" -gt 0 ] && [ "$nemit" = "$nfmt" ]; } \
  && ok "every byte count handed back to the shell is formatted ($nfmt sites)" \
  || no "$((nemit - nfmt)) unformatted byte count(s) reach the shell as 2.81904e+09 on mawk"

# The batch path. A README clears the single-repo budget, so these five can only be reached by
# what no one repo can fake: other repos holding the very same file.
[ "$(grep -cE "^zbatch[1245] .*media-batch" <<<"$plan" || true)" = 4 ] \
  && ok "repos reposting one clip behind a README are pruned (media-batch)" \
  || no "the batch path prunes a reposted dump"
! has "$plan" "zbatch3" \
  && ok "the repo that published the clip first is not in its own batch" \
  || no "the batch path spares the first holder"
! has "$plan" "zbatchodd" \
  && ok "the same README over a clip nobody else holds still spares the repo" \
  || no "the batch path is about the sharing, not the README"
plan_fk=$(MEDIA_MIN_BATCH=6 run)
[ "$(grep -cE "^zbatch[1-5] " <<<"$plan_fk" || true)" = 0 ] \
  && ok "MEDIA_MIN_BATCH=6 spares all five, so the prunes above came from the batch" \
  || no "MEDIA_MIN_BATCH is vacuous"
plan_fc=$(MEDIA_TEXT_CEIL_BYTES=100 run)
[ "$(grep -cE "^zbatch[1-5] " <<<"$plan_fc" || true)" = 0 ] \
  && ok "a ceiling under their README spares them, batch or no batch" \
  || no "MEDIA_TEXT_CEIL_BYTES is vacuous"

# Each threshold must be able to say no on its own, and each must be able to say yes: a rule
# that only ever spares is indistinguishable from one that never runs.
# The ref cap. zmediarefs is a dump like any other until its third ref puts it over the cap,
# and the run has to say so rather than quietly counting it as clean.
grep -qE "^zmediarefs .*media-dump" <<<"$plan" \
  && ok "a dump under MEDIA_MAX_REFS is judged" || no "the extra ref alone spares zmediarefs"
plan_fr=$(MEDIA_MAX_REFS=2 run)
{ ! has "$plan_fr" "zmediarefs" && grep -q 'unjudged' <<<"$plan_fr" \
  && grep -qE "^zmediaone .*media-dump" <<<"$plan_fr"; } \
  && ok "a repo over MEDIA_MAX_REFS is left unjudged, said so, and the rest still run" \
  || no "MEDIA_MAX_REFS is vacuous"
plan_fb=$(MEDIA_MIN_BYTES=99999999 run)
! has "$plan_fb" "zmediaone" \
  && ok "MEDIA_MIN_BYTES above the media it holds spares it" || no "MEDIA_MIN_BYTES is vacuous"
# The suite lowers MEDIA_MIN_BYTES to keep itself fast, so the shipped default needs its own
# check: without it, 1 MiB could become any other number unnoticed.
grep -q 'rule F media-dump(>=64KB of media' <<<"$(env -u MEDIA_MIN_BYTES "$SCRIPT" 2>&1)" \
  && ok "the shipped MEDIA_MIN_BYTES default is 64 KiB" \
  || no "MEDIA_MIN_BYTES default is 64 KiB"
plan_ft=$(MEDIA_TEXT_MAX_BYTES=99999 run)
grep -qE "^zmediatwo .*media-dump" <<<"$plan_ft" \
  && ok "a bigger text budget reaches the repo its README was sparing" \
  || no "MEDIA_TEXT_MAX_BYTES is vacuous"
# zmediawide's README sits between the two budgets, and its media is only findable by reading.
# Raising one budget past the other must move the read guard with it.
grep -qE "^zmediawide .*media-dump" <<<"$plan_ft" \
  && ok "raising the text budget past the ceiling still reads the files it needs" \
  || no "the read guard uses the narrower budget"
! has "$plan" "zmediawide" \
  && ok "that same long README spares it at the default budget" \
  || no "a 70KB README should clear a 2KB budget"
plan_fx=$(MEDIA_EXTS='bin' run)
{ grep -qE "^zmediabin .*media-dump" <<<"$plan_fx" && ! has "$plan_fx" "zmediaone"; } \
  && ok "MEDIA_EXTS decides what counts as media, both ways" || no "MEDIA_EXTS is vacuous"
plan_fo=$(MEDIA_SCAN=0 run)
# The "# PLAN:" line is the last thing a run prints, so it separates "rule F found nothing"
# from "the run died before it could".
{ ! has "$plan_fo" "zmediaone" && grep -q 'MEDIA_SCAN=0' <<<"$plan_fo" \
  && grep -q '^# PLAN:' <<<"$plan_fo"; } \
  && ok "MEDIA_SCAN=0 turns rule F off, says so, and still finishes" \
  || no "MEDIA_SCAN=0 disables rule F"

# Rule F defaults to keeping the last copy we know of, unlike rules D and E.
! has "$plan" "zmediazero" \
  && ok "a media dump no other node seeds is kept by default" \
  || no "MEDIA_MIN_SEEDS keeps the last copy"
plan_fz=$(MEDIA_MIN_SEEDS=0 run)
grep -qE "^zmediazero .*media-dump" <<<"$plan_fz" \
  && ok "MEDIA_MIN_SEEDS=0 lets rule F take the last copy we know of" \
  || no "MEDIA_MIN_SEEDS is vacuous"
# Sparing it silently would make the seed floor a permanent hiding place, so the run says what
# it saw and left alone.
{ grep -q '^# review: 1 media dump(s) no other node seeds, kept:' <<<"$plan" \
    && grep -qE '^#   zmediazero +media-dump' <<<"$plan"; } \
  && ok "the dump it kept is named for a human to look at" \
  || no "the review list names what it kept"
! grep -q '^# review:' <<<"$plan_fz" \
  && ok "nothing to review once the floor is 0 and it was pruned instead" \
  || no "review list is vacuous"

# --- the creation clock cannot be reset by a push --- Every date inside a repo is set by
# whoever pushed it, so force-pushing every ref with fresh dates would renew rules D and E
# forever. What this seed recorded when it first saw the repo cannot be reached from outside,
# and the age those rules use is whichever of the two is older.
grep -qE "^zspamaged .*spam-batch" <<<"$plan" \
  && ok "day-old refs do not save a batch member the seed has held for a year" \
  || no "first-seen ledger overrides young refs"
plan_fs=$(FIRST_SEEN=/dev/null run)
! has "$plan_fs" "zspamaged" \
  && ok "with no ledger it survives on ref dates, so the prune above came from the ledger" \
  || no "first-seen ledger is vacuous"
grep -q "^zjunk1"$'\t' "$AUDIT_DIR/first-seen.tsv" \
  && ok "the ledger records repos it had not seen before, on a dry run too" \
  || no "the ledger is written on a dry run"
{ ! grep -q 'integer expression' <<<"$plan" && ! has "$plan" "zfresh4"; } \
  && ok "a torn ledger line is skipped, not fed to an arithmetic comparison" \
  || no "a torn ledger line is skipped"

# --- what the run left alone is counted in the report, not silently absent ---
skipped_re='^# skipped: [0-9]+ unreadable, 1 written in the last 2d,'
skipped_re="$skipped_re"' [0-9]+ with no readable refs'
{ ! has "$plan" "zinfetch" \
    && grep -qE "$skipped_re" <<<"$plan"; } \
  && ok "a repo written mid-run is skipped and counted in the report" \
  || no "the freshness guard is reported"
plan_fg=$(FRESH_GUARD_DAYS=0 run)
grep -qE "^zinfetch .*stale" <<<"$plan_fg" \
  && ok "FRESH_GUARD_DAYS=0 reaches it, so the skip above is the guard" \
  || no "the freshness guard is vacuous"

# --- the AGE column reports the date the matching rule measured ---
# zspamfresh was created 90 days ago and touched yesterday. Printing its last activity beside a
# 7-day creation minimum reads as a bug in the tool rather than as the verdict it is.
[ "$(awk '$1=="zspamfresh"{print $4}' <<<"$plan")" = 90 ] \
  && ok "a spam-batch row shows the creation age its rule measured" \
  || no "AGE column shows the rule's own clock"
[ "$(awk '$1=="zjunk1"{print $4}' <<<"$plan")" = 400 ] \
  && ok "a junk-name row still shows last activity" \
  || no "AGE column still shows activity for rules A to C"

# --- a repo larger than the read budget is judged, not excluded --- Reaching LINK_REPO_BUDGET
# closes the harvest pipe early and kills the object lister with SIGPIPE. Read as a failure,
# that quietly drops every large repo from the plan, and past MAX_SCAN_FAIL_PCT it aborts the
# whole run.
plan_bud=$(LINK_REPO_BUDGET=100 run)
{ has "$plan_bud" "zheavy" && ! grep -q "could not read the contents" <<<"$plan_bud"; } \
  && ok "a repo bigger than the read budget is still judged" \
  || no "the read budget excludes big repos"

# Rules A/B/C must keep clocking ACTIVITY: a repo touched yesterday is not abandoned.
! grep -qE "^zfresh4 " <<<"$plan" \
  && ok "an actively-used repo is still spared by the activity rules" \
  || no "activity rules unaffected"

# --- taking the last copy WE KNOW OF, but only where the evidence is conclusive --- "No other
# seed has it" is worthlessness for machine-generated bulk and preservation value for anything
# else, so the two rule-A branches are gated apart and rule C is not in this game at all.
has "$plan" "zhexzero27" && grep -qE "^zhexzero27 .*junk-id" <<<"$plan" \
  && ok "zero-seed random-id name is pruned (junk-id takes the last copy)" \
  || no "zero-seed junk-id pruned"
! has "$plan" "zwordzero28" \
  && ok "zero-seed 'test-orphan' is kept (a word in a name is a guess, not proof)" \
  || no "zero-seed junk-name kept"
has "$plan" "zspamzero" && grep -qE "^zspamzero .*spam-batch" <<<"$plan" \
  && ok "zero-seed spam batch member is pruned" || no "zero-seed spam-batch pruned"

# Both new floors must be able to say no, or they are decoration.
plan_i=$(JUNK_ID_MIN_SEEDS=1 run)
! has "$plan_i" "zhexzero27" && has "$plan_i" "zhexid23" \
  && ok "JUNK_ID_MIN_SEEDS=1 spares the zero-seed id repo, keeps the seeded one" \
  || no "JUNK_ID_MIN_SEEDS check is vacuous"
# ...and the word branch's floor must be the REASON zwordzero28 survives, not a coincidence of
# it also failing every other rule: drop the floor and it has to appear.
plan_w=$(JUNK_MIN_SEEDS=0 run)
grep -qE "^zwordzero28 .*junk-name" <<<"$plan_w" \
  && ok "JUNK_MIN_SEEDS=0 does reach the zero-seed word repo (so the keep above is real)" \
  || no "zero-seed junk-name keep is vacuous"
plan_s=$(SPAM_MIN_SEEDS=1 run)
! has "$plan_s" "zspamzero" && has "$plan_s" "zspam1" \
  && ok "SPAM_MIN_SEEDS=1 spares the zero-seed spam repo, keeps the seeded ones" \
  || no "SPAM_MIN_SEEDS check is vacuous"

# A repo whose description quotes an rid must still be filed under its OWN rid, not the quoted
# one. Regression: a description may itself quote an rid ("...used for the site in
# rad:z3U9..."), and taking the LAST rad: token on the row filed the whole repo under the rid
# it merely mentioned.
grep -qE "^zridin25 .*ridquoter$" <<<"$plan" \
  && ok "a description quoting an rid still files under the row's own rid" \
  || no "row filed under its own rid"
# Regression: the name column was read as field 2, so any name with a space was silently
# truncated ("Blog e64" became "Blog") - and a truncated name is what rule D skeletonises.
grep -qE "^zspaced26 .*Blog e64$" <<<"$plan" \
  && ok "a name containing spaces survives the parse" \
  || no "spaced name survives the parse"

# --- an empty `rad ls` degrades loudly: blank names and a blind rule D would otherwise look
# exactly like a clean seed ---
out=$(RSP_NO_LS=1 DISK_AWARE=0 ABS_SIZE_FLOOR_MB=1 run)
{ grep -q "WARN: .*returned no repos" <<<"$out" && ! grep -q '^# spam batches' <<<"$out"; } \
  && ok "an empty repo listing is reported, not silently read as 'no spam'" \
  || no "empty repo listing warns"

# --- disk-pressure: at full pressure, stale window shrinks + seed floor drops to 1 ---
plan_hi=$(DISK_AWARE=1 ABS_SIZE_FLOOR_MB=1 \
          PRESSURE_CRIT_PCT=100 PRESSURE_CRIT_GB=99999999 \
          PRESSURE_RELAX_PCT=100 PRESSURE_RELAX_GB=999999999 run)
grep -qE "pressure=100%" <<<"$plan_hi" \
  && ok "pressure reaches 100% under forced watermarks" \
  || no "pressure=100%"
has "$plan_hi" "zbwid9" \
  && ok "pressure prunes a repo that was kept at p=0"   \
  || no "pressure widens the net"
has "$plan_hi" "zfews5" \
  && ok "pressure drops seed floor to 1 (under-seeded now pruned)" \
  || no "pressure drops seed floor"
! has "$plan_hi" "zfresh4" \
  && ok "pressure still keeps a fresh repo"          \
  || no "pressure keeps fresh repo"

# --- RAD_HOME reaches rad as ENVIRONMENT, not just as a shell variable --- Regression: the
# script resolved RAD_HOME but never exported it, so every rad call queried the default home
# instead, came back empty, and forced a plan of zero repos. Unset it in the caller so the only
# way the stub can see it is the script exporting what it resolved from `rad path`.
: > "$RSP_HOME/.stub_radhome"
env -u RAD_HOME DISK_AWARE=0 ABS_SIZE_FLOOR_MB=1 "$SCRIPT" >/dev/null 2>&1; rc=$?
{ grep -qxF "$RSP_HOME" "$RSP_HOME/.stub_radhome" && [ "$rc" = 0 ]; } \
  && ok "resolved RAD_HOME is exported to rad" \
  || no "resolved RAD_HOME is exported to rad (rc=$rc)"

# --- an unexpected failure names the line and the command instead of exiting silently ---
# Regression: `set -e` plus muted stderr meant any hiccup exited non-zero with no output
# whatsoever, which is undebuggable from a bug report. Inject a failure and demand a
# diagnosable message.
inj="$ROOT/injected-failure"
sed 's|^nrepos=|false  # injected\nnrepos=|' "$SCRIPT" > "$inj"; chmod +x "$inj"
out=$(DISK_AWARE=0 "$inj" 2>&1); rc=$?
{ [ "$rc" != 0 ] && grep -qE '^# ERROR: line [0-9]+: \[false' <<<"$out"; } \
  && ok "unexpected failure reports line + command" \
  || no "unexpected failure reports line + command (rc=$rc)"

# --- blind runs abort instead of reporting a reassuring, meaningless "prune 0 repos" ---
out=$(RSP_NODE_DOWN=1 DISK_AWARE=0 "$SCRIPT" 2>&1); rc=$?
{ [ "$rc" = 5 ] && grep -q 'ABORT(dry-run)' <<<"$out" && ! grep -q '# PLAN:' <<<"$out"; } \
  && ok "node-down aborts dry-run too (exit 5, no plan)" \
  || no "node-down aborts dry-run (got exit $rc)"

out=$(RSP_NO_ROUTING=1 DISK_AWARE=0 "$SCRIPT" 2>&1); rc=$?
{ [ "$rc" = 5 ] && grep -q 'routing table empty' <<<"$out" \
    && ! grep -q '# PLAN:' <<<"$out"; } \
  && ok "empty routing table aborts (exit 5, no plan)" \
  || no "empty routing aborts (got exit $rc)"

# --- an unreadable repo survives the scan: reported and excluded, never fatal --- Regression:
# du hit one unreadable dir, xargs returned 123, and `set -e` killed the whole run with no
# output at all. The unreadable dir is INSIDE the repo, so its refs stay readable and ztwoyr3
# still looks prunable on age - only the scan-error exclusion keeps it out of the plan.
mkdir -p "$STORAGE/ztwoyr3/unreadable" && chmod 000 "$STORAGE/ztwoyr3/unreadable"
# creating the subdir bumped mtime; keep it out of the freshness guard so that ONLY the
# scan-error rule excludes it
touch -d "10 days ago" "$STORAGE/ztwoyr3"
# a high blind-scan limit, so this tests the per-repo exclusion and not the aggregate guard
# below
out=$(DISK_AWARE=0 ABS_SIZE_FLOOR_MB=1 MAX_SCAN_FAIL_PCT=50 "$SCRIPT" 2>&1); rc=$?
chmod 755 "$STORAGE/ztwoyr3/unreadable"; rmdir "$STORAGE/ztwoyr3/unreadable"
{ [ "$rc" = 0 ] && grep -q '# PLAN:' <<<"$out"; } \
  && ok "unreadable repo does not abort the scan" \
  || no "unreadable repo does not abort the scan (got exit $rc)"
grep -qE '^# WARN: [0-9]+ scan error' <<<"$out" \
  && ok "scan errors are reported, not swallowed" \
  || no "scan errors reported"
{ ! has "$out" "ztwoyr3" && has "$out" "zjunk1"; } \
  && ok "unreadable repo excluded from plan, others still planned" \
  || no "unreadable repo excluded from plan"

# --- a scan that missed too much of storage refuses to report a plan at all --- Three
# unreadable repos against a 1% limit, so the assertion does not ride on the fixture size.
# Without this the run would report a plausible-looking small plan built from a partial scan.
for r in zjunk1 zbig2 zbar8; do chmod 000 "$STORAGE/$r"; done
out=$(DISK_AWARE=0 ABS_SIZE_FLOOR_MB=1 MAX_SCAN_FAIL_PCT=1 "$SCRIPT" 2>&1); rc=$?
for r in zjunk1 zbig2 zbar8; do chmod 755 "$STORAGE/$r"; done
{ [ "$rc" = 5 ] && grep -q "could not read 3 of $NREPOS repos" <<<"$out" \
    && ! grep -q '# PLAN:' <<<"$out"; } \
  && ok "blind scan aborts instead of reporting a small plan" \
  || no "blind scan aborts (got exit $rc)"

# --- every walk in the scan can fail mid-flight without taking the run down --- Regression:
# the repo-counting walk was the one find call left unguarded, so on a busy seed the run died
# at the very first line of the scan, before printing anything a bug report could use.
shimdir="$ROOT/shim"; mkdir -p "$shimdir"
cp "$HERE/find-shim" "$shimdir/find"; chmod +x "$shimdir/find"
out=$(PATH="$shimdir:$PATH" DISK_AWARE=0 ABS_SIZE_FLOOR_MB=1 "$SCRIPT" 2>&1); rc=$?
{ [ "$rc" = 0 ] && grep -q "# scanning $NREPOS repos" <<<"$out" && has "$out" "zjunk1"; } \
  && ok "a failing find in the scan is survived, not fatal" \
  || no "failing find survived (got exit $rc)"
grep -qE '^# WARN: [0-9]+ scan error' <<<"$out" \
  && ok "a failing find is still reported as a scan error" \
  || no "failing find reported"

# --- storage we cannot read is an abort, never a serene empty plan --- Running as the wrong
# user reads as zero repos, and zero repos reads as "nothing to do" rather than "I could not
# look".
chmod 000 "$STORAGE"
out=$(DISK_AWARE=0 "$SCRIPT" 2>&1); rc=$?
chmod 755 "$STORAGE"
{ [ "$rc" = 1 ] && grep -q 'cannot read storage dir' <<<"$out" \
    && ! grep -q '# PLAN:' <<<"$out"; } \
  && ok "unreadable storage dir aborts (no empty plan)" \
  || no "unreadable storage aborts (got exit $rc)"

# --- fail-safe: node down aborts --apply before touching anything ---
RSP_NODE_DOWN=1 DISK_AWARE=0 ABS_SIZE_FLOOR_MB=1 "$SCRIPT" --apply >/dev/null 2>&1; rc=$?
[ "$rc" = 5 ] \
  && ok "node-down aborts --apply (exit 5)" \
  || no "node-down aborts --apply (got exit $rc)"

# --- apply: non-interactive (cron path) applies; interactive prompt (pty) obeys y/N ---
# non-interactive --apply (no controlling tty): applies directly, no prompt.
build_fixture; assert_isolated                    # fresh fixture before the tests that delete
DISK_AWARE=0 ABS_SIZE_FLOOR_MB=1 "${NOTTY[@]}" "$SCRIPT" --apply </dev/null >/dev/null 2>&1
gone=1
for r in zjunk1 zbig2 ztwoyr3 zbar8 zspam1 zspam9; do
  [ -e "$STORAGE/$r" ] && gone=0
done
kept=1
for r in zfresh4 zpin6 zpriv7 zown22 zbwid9 zfews5 zdecoy1 zenum1; do
  [ -e "$STORAGE/$r" ] || kept=0
done
{ [ "$gone" = 1 ] && [ "$kept" = 1 ]; } \
  && ok "non-interactive --apply prunes exactly the plan" \
  || no "non-interactive --apply prunes the plan"
{ [ -s "$RSP_HOME/.stub_block" ] && [ -s "$RSP_HOME/.stub_unseed" ]; } \
  && ok "apply calls rad unseed + block" \
  || no "apply calls unseed+block"

# --- rule G's act, the only thing in the tool that judges a PERSON --- Blocking is permanent
# and the peer never hears about it, so it needs a human in the room every time: --apply alone
# must not reach it, and --block-peers must refuse when there is nobody to ask.
export PARASITE_MIN_REPOS=3 PARASITE_MIN_BYTES=65536 PARASITE_TEXT_MAX_BYTES=4096
build_fixture; assert_isolated
DISK_AWARE=0 ABS_SIZE_FLOOR_MB=1 "${NOTTY[@]}" "$SCRIPT" --apply </dev/null >/dev/null 2>&1
{ ! grep -q "$PARA" "$RSP_HOME/.stub_block" 2>/dev/null \
  && GIT_DIR="$STORAGE/zpara1" git for-each-ref "refs/namespaces/$PARA/" \
       --format=x 2>/dev/null | grep -q x; } \
  && ok "--apply on its own blocks no peer and drops no peer refs" \
  || no "--apply acted on a peer without --block-peers"

build_fixture; assert_isolated
DISK_AWARE=0 ABS_SIZE_FLOOR_MB=1 "${NOTTY[@]}" "$SCRIPT" --apply --block-peers \
  </dev/null >"$ROOT/nb.out" 2>&1
{ ! grep -q "$PARA" "$RSP_HOME/.stub_block" 2>/dev/null \
  && grep -q "needs a terminal" "$ROOT/nb.out"; } \
  && ok "--block-peers refuses with no terminal rather than blocking unattended" \
  || no "--block-peers blocked a peer with nobody there to approve it"

plan_g=$(run)
grep -q "rad block $PARA" <<<"$plan_g" \
  && ok "the plan prints the exact rad block command for each peer it names" \
  || no "rule G named a peer without printing how to act on it"

if command -v script >/dev/null 2>&1; then
  # Two prompts: the plan, then this one peer. "y" then "n" leaves the peer alone, which is
  # what separates the per-peer question from a blanket licence given by the flag.
  build_fixture; assert_isolated
  printf 'y\nn\n' | script -qec \
    "env DISK_AWARE=0 ABS_SIZE_FLOOR_MB=1 PARASITE_MIN_REPOS=3 PARASITE_MIN_BYTES=65536 \
         PARASITE_TEXT_MAX_BYTES=4096 '$SCRIPT' --apply --block-peers" /dev/null \
    >"$ROOT/gn.out" 2>&1
  { ! grep -q "$PARA" "$RSP_HOME/.stub_block" 2>/dev/null \
    && GIT_DIR="$STORAGE/zpara1" git for-each-ref "refs/namespaces/$PARA/" \
         --format=x 2>/dev/null | grep -q x; } \
    && ok "--block-peers + n leaves that peer alone" \
    || no "--block-peers blocked a peer the operator declined"

  build_fixture; assert_isolated
  printf 'y\ny\n' | script -qec \
    "env DISK_AWARE=0 ABS_SIZE_FLOOR_MB=1 PARASITE_MIN_REPOS=3 PARASITE_MIN_BYTES=65536 \
         PARASITE_TEXT_MAX_BYTES=4096 '$SCRIPT' --apply --block-peers" /dev/null \
    >"$ROOT/gy.out" 2>&1
  grep -q "$PARA" "$RSP_HOME/.stub_block" 2>/dev/null \
    && ok "--block-peers + y blocks the peer rule G named" \
    || no "--block-peers + y did not block the peer"
  { ! grep -q "$CONTRIB" "$RSP_HOME/.stub_block" 2>/dev/null \
    && ! grep -q "$WRITER" "$RSP_HOME/.stub_block" 2>/dev/null; } \
    && ok "--block-peers blocks nobody rule G cleared" \
    || no "--block-peers blocked a delegate or a peer who wrote something"
  gonerefs=1
  for r in zpara1 zpara2 zpara3; do
    GIT_DIR="$STORAGE/$r" git for-each-ref "refs/namespaces/$PARA/" --format=x 2>/dev/null \
      | grep -q x && gonerefs=0
  done
  kept=1
  GIT_DIR="$STORAGE/zpara1" git rev-parse --verify -q master >/dev/null 2>&1 || kept=0
  GIT_DIR="$STORAGE/zpara1" git for-each-ref "refs/namespaces/$WRITER/" --format=x 2>/dev/null \
    | grep -q x || kept=0
  { [ "$gonerefs" = 1 ] && [ "$kept" = 1 ]; } \
    && ok "a blocked peer's refs are dropped and nothing else is touched" \
    || no "blocking left the peer's refs behind or removed somebody else's"
  grep -q "blocked-peer.*$PARA.*repos=" "$RSP_HOME/prune-audit/"prune-*.log 2>/dev/null \
    && ok "a block is recorded in the audit log with the evidence behind it" \
    || no "a peer was blocked without the evidence being written down"
else
  skip "no util-linux script(1); cannot drive the per-peer block prompt through a pty"
fi
unset PARASITE_MIN_REPOS PARASITE_MIN_BYTES PARASITE_TEXT_MAX_BYTES

# --- a failed deletion is never reported as reclaimed disk --- A read-only storage dir lets
# the whole plan compute, then makes every rm fail. The audit log and the GiB total are both
# written from the plan, so silence here would record disk that never freed.
build_fixture; assert_isolated
before=$(ls "$STORAGE" | wc -l)
chmod 555 "$STORAGE"
out=$(DISK_AWARE=0 ABS_SIZE_FLOOR_MB=1 "${NOTTY[@]}" "$SCRIPT" --apply </dev/null 2>&1); rc=$?
chmod 755 "$STORAGE"
after=$(ls "$STORAGE" | wc -l)
{ [ "$before" = "$after" ] && grep -q 'WARN quarantine failed' <<<"$out" \
    && grep -qE 'WARN: [0-9]+ of [0-9]+ deletions failed' <<<"$out" \
    && grep -q 'DONE: quarantined 0 repos' <<<"$out"; } \
  && ok "a failed quarantine move is reported, not counted as reclaimed" \
  || no "failed quarantine reported (rc=$rc)"

# The same claim on the outright-delete path, which is what a full disk falls back to.
build_fixture; assert_isolated
before=$(ls "$STORAGE" | wc -l)
chmod 555 "$STORAGE"
out=$(DISK_AWARE=0 ABS_SIZE_FLOOR_MB=1 QUARANTINE=0 "${NOTTY[@]}" "$SCRIPT" --apply \
        </dev/null 2>&1); rc=$?
chmod 755 "$STORAGE"
after=$(ls "$STORAGE" | wc -l)
{ [ "$before" = "$after" ] && grep -q 'WARN delete failed' <<<"$out" \
    && grep -q 'DONE: deleted 0 repos' <<<"$out"; } \
  && ok "failed deletions are reported, not counted as reclaimed" \
  || no "failed deletions reported (rc=$rc)"

# --- quarantine --- The three floor-0 verdicts may take the last copy the network is known to
# hold, so "re-fetch it" is not an undo for exactly the repos that most need one.
build_fixture; assert_isolated
DISK_AWARE=0 ABS_SIZE_FLOOR_MB=1 "${NOTTY[@]}" "$SCRIPT" --apply </dev/null >/dev/null 2>&1
Q="$RSP_HOME/prune-audit/quarantine"
{ [ ! -e "$STORAGE/zjunk1" ] && [ -d "$Q/zjunk1" ] \
  && GIT_DIR="$Q/zjunk1" git rev-parse --verify -q master >/dev/null 2>&1; } \
  && ok "a pruned repo is moved to quarantine intact, not destroyed" \
  || no "a pruned repo was not recoverable from quarantine"

build_fixture; assert_isolated
Q="$RSP_HOME/prune-audit/quarantine"
DISK_AWARE=0 ABS_SIZE_FLOOR_MB=1 QUARANTINE=0 "${NOTTY[@]}" "$SCRIPT" --apply \
  </dev/null >/dev/null 2>&1
{ [ ! -e "$STORAGE/zjunk1" ] && [ ! -e "$Q/zjunk1" ]; } \
  && ok "QUARANTINE=0 deletes outright, keeping nothing" \
  || no "QUARANTINE=0 still parked a copy"

# A repo already past the window is gone for good on the next run, which is what makes the
# quarantine bounded rather than a second copy of storage growing forever.
build_fixture; assert_isolated
Q="$RSP_HOME/prune-audit/quarantine"
mkdir -p "$Q/zoldquar"; touch -d "40 days ago" "$Q/zoldquar"
out=$(DISK_AWARE=0 ABS_SIZE_FLOOR_MB=1 "${NOTTY[@]}" "$SCRIPT" --apply </dev/null 2>&1)
{ [ ! -e "$Q/zoldquar" ] && grep -q 'purged 1 repo' <<<"$out"; } \
  && ok "quarantine is purged once the window passes" \
  || no "a quarantined repo outlived QUARANTINE_DAYS"

# At the critical watermark a recovery copy is a luxury the disk cannot buy.
build_fixture; assert_isolated
Q="$RSP_HOME/prune-audit/quarantine"
mkdir -p "$Q/zfreshquar"
out=$(DISK_AWARE=1 PRESSURE_CRIT_PCT=100 PRESSURE_CRIT_GB=999999 ABS_SIZE_FLOOR_MB=1 \
        "${NOTTY[@]}" "$SCRIPT" --apply </dev/null 2>&1)
{ [ ! -e "$Q/zfreshquar" ] && grep -q 'emptied the whole quarantine' <<<"$out"; } \
  && ok "a critical disk empties the whole quarantine, window or not" \
  || no "quarantine held disk hostage at the critical watermark"

# --- the caps must catch a plan that CREEPS, not only one that jumps --- A weekly cron whose
# plan doubles every month never touches a fixed cap. The baseline is the history the tool
# already writes, so this fixture writes a history and checks the run stops against it.
build_fixture; assert_isolated
mkdir -p "$RSP_HOME/prune-audit"
for i in 1 2 3 4; do
  printf '2026-0%s-01T00:00:00Z\tdeleted=2\treclaimed_gib=0.01\tpressure=0%%\taudit=x.log\n' \
    "$i" >> "$RSP_HOME/prune-audit/history.log"
done
out=$(DISK_AWARE=0 ABS_SIZE_FLOOR_MB=1 "${NOTTY[@]}" "$SCRIPT" --apply </dev/null 2>&1); rc=$?
{ [ "$rc" = 3 ] && grep -q 'is not a routine week' <<<"$out" \
  && [ -e "$STORAGE/zjunk1" ]; } \
  && ok "a plan far above what this seed usually prunes stops an unattended run" \
  || no "a creeping plan ran unattended (rc=$rc)"

out=$(DISK_AWARE=0 ABS_SIZE_FLOOR_MB=1 "${NOTTY[@]}" "$SCRIPT" --apply --force \
        </dev/null 2>&1); rc=$?
{ [ "$rc" != 3 ] && [ ! -e "$STORAGE/zjunk1" ]; } \
  && ok "--force still gets past the history ratchet" \
  || no "--force could not override the ratchet (rc=$rc)"

# Too little history is no baseline: two runs must not be treated as a norm to measure against.
build_fixture; assert_isolated
mkdir -p "$RSP_HOME/prune-audit"
printf '2026-01-01T00:00:00Z\tdeleted=1\taudit=x.log\n' >> "$RSP_HOME/prune-audit/history.log"
printf '2026-02-01T00:00:00Z\tdeleted=1\taudit=x.log\n' >> "$RSP_HOME/prune-audit/history.log"
out=$(DISK_AWARE=0 ABS_SIZE_FLOOR_MB=1 "${NOTTY[@]}" "$SCRIPT" --apply </dev/null 2>&1); rc=$?
{ [ "$rc" != 3 ] && [ ! -e "$STORAGE/zjunk1" ]; } \
  && ok "two past runs are not enough history to ratchet against" \
  || no "the ratchet fired on a baseline too thin to mean anything (rc=$rc)"

# interactive prompt via a pty (needs util-linux `script`): n aborts, y applies.
if command -v script >/dev/null 2>&1; then
  build_fixture; assert_isolated
  b=$(ls "$STORAGE" | wc -l)
  printf 'n\n' | script -qec "env DISK_AWARE=0 ABS_SIZE_FLOOR_MB=1 '$SCRIPT' --apply" \
    /dev/null >"$ROOT/n.out" 2>&1
  a=$(ls "$STORAGE" | wc -l)
  { grep -q aborted "$ROOT/n.out" && [ "$b" = "$a" ]; } \
    && ok "interactive --apply + n aborts, nothing deleted" \
    || no "interactive + n aborts"

  build_fixture; assert_isolated
  printf 'y\n' | script -qec "env DISK_AWARE=0 ABS_SIZE_FLOOR_MB=1 '$SCRIPT' --apply" \
    /dev/null >"$ROOT/y.out" 2>&1
  gone=1; for r in zjunk1 zbig2 ztwoyr3 zbar8; do [ -e "$STORAGE/$r" ] && gone=0; done
  [ "$gone" = 1 ] \
    && ok "interactive --apply + y prunes the plan" \
    || no "interactive + y prunes"
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
    && ok "an unreadable launch directory produces no scan errors" \
    || no "unreadable cwd is clean (rc=$rc)"
else
  echo "skip - unreadable-cwd test (running as root bypasses the mode bits)"
fi

# cd / must not change what a RELATIVE RAD_HOME/STORAGE/RAD meant to the caller.
build_fixture; assert_isolated
out=$(cd "$ROOT" && env RAD_HOME="./rad-home" STORAGE="./rad-home/storage" \
        CONFIG="./rad-home/config.json" AUDIT_DIR="./rad-home/prune-audit" \
        RAD="./bin/rad" "$SCRIPT" 2>&1); rc=$?
{ [ "$rc" = 0 ] && grep -qE '^zjunk1 ' <<<"$out" && grep -q '# PLAN:' <<<"$out"; } \
  && ok "relative RAD_HOME/STORAGE/RAD survive the cwd anchor" \
  || no "relative paths survive cd / (rc=$rc)"

rm -rf "$ROOT"
# ============================================================================
echo "-----------------------------------------"
echo "passed: $PASS   failed: $FAIL"
[ "$FAIL" = 0 ]
