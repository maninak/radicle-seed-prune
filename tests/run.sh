#!/usr/bin/env bash
#
# Test suite for radicle-seed-prune. Zero external deps beyond bash + git + coreutils:
# it builds a throwaway Radicle-home fixture (fake `rad` stub on PATH + real bare git repos
# with controlled activity dates and sizes) and runs the real script against it.
#
#   tests/run.sh                 everything, in order, in one process
#   tests/run.sh -k quarantine   only the sections that mention "quarantine"
#   tests/run.sh -n 7            only the 7th section, in a process of its own
#   tests/run.sh -e              every section, each in a process of its own
#
# A section is everything from one fixture rebuild to the next, and it must set up everything
# it reads: a whole run takes minutes and one section takes seconds, so a section that only
# passes after the one above it has run takes that loop away from whoever comes next.
#
set -uo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
SCRIPT="$HERE/../rad-prune"
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

# Building the fixture below is about 700 git invocations, and the suite wants a clean one
# roughly forty times, which used to be most of its runtime. It is built once and kept as a
# template; every later call throws the working copy away and restores it from that template,
# which is a copy of a few MB, and a reflink on a filesystem that has them.
build_fixture(){
  [ -n "${ROOT:-}" ] || { ROOT=$(mktemp -d); _fixture_env
                          trap 'rm -rf "$ROOT" 2>/dev/null' EXIT ; }
  if [ -z "${TEMPLATE:-}" ]; then
    if [ "${RSP_FIXTURE_CACHE:-1}" = 0 ]; then
      _build_fixture
      TEMPLATE=$(mktemp -d); cp -a --reflink=auto "$ROOT/." "$TEMPLATE/"
      trap 'rm -rf "$ROOT" "$TEMPLATE" 2>/dev/null' EXIT
    else
      TEMPLATE=$(cached_template) || exit 3         # kept between runs, so never deleted here
    fi
  fi
  # A test that left a directory unreadable would otherwise leave it standing here, and the
  # fixture that follows would be the previous test's leftovers rather than a fresh one. ROOT
  # is the same directory for the whole process now, so a failure to clear it has to stop it.
  if [ -e "$ROOT" ]; then
    chmod -R u+rwX "$ROOT" 2>/dev/null
    rm -rf "$ROOT"
    [ -e "$ROOT" ] && { echo "ABORT: could not clear the fixture at $ROOT"; exit 3; }
  fi
  mkdir -p "$ROOT"
  cp -a --reflink=auto "$TEMPLATE/." "$ROOT/"
}

# Building the fixture takes about eighteen seconds, which is most of what running a single
# section costs, and nothing about it changes between two runs of the same suite. It is kept
# under TMPDIR between runs, keyed by the part of this file that builds it plus the rad stub,
# so editing a test reuses it and editing the fixture does not. Every date inside it is
# relative to the moment it was built, so it is thrown away after an hour rather than left to
# drift towards the day thresholds the tests sit near. RSP_FIXTURE_CACHE=0 turns it off.
cached_template(){
  local key dir staging old
  key=$( { sed -n '1,/^# ---- end of header/p' "$0"; cat "$HERE/rad-stub"; } \
         | sha1sum | cut -c1-12 )
  dir="${TMPDIR:-/tmp}/rsp-fixture-$(id -u)-$key"      # never another user's, on a shared /tmp
  # An hour old is still today's dates; older than that and the day thresholds the tests sit
  # near have moved under it.
  if [ -d "$dir" ] && [ -z "$(find "$dir" -maxdepth 0 -mmin +60)" ]; then
    printf '%s\n' "$dir"; return 0
  fi
  _build_fixture >&2
  # Filled beside the target and renamed onto it, so a second suite running at the same time
  # sees either the old template or the new one, never half of one. The old one is renamed away
  # rather than deleted where it stands: `rm -rf` on a whole fixture leaves the path missing
  # for as long as the walk takes, and a suite copying from it in that window gets a fixture
  # with no storage in it, which fails as a handful of unrelated tests.
  staging=$(mktemp -d -p "$(dirname "$dir")")
  cp -a --reflink=auto "$ROOT/." "$staging/"
  old="$dir.old.$$"
  mv -T "$dir" "$old" 2>/dev/null || old=""
  if mv -T "$staging" "$dir" 2>/dev/null; then
    [ -n "$old" ] && rm -rf "$old"
  else
    rm -rf "$staging"
    [ -n "$old" ] && mv -T "$old" "$dir" 2>/dev/null
  fi
  [ -d "$dir" ] || { echo "ABORT: could not cache the fixture at $dir" >&2; return 1; }
  # The key changes whenever the fixture does, so yesterday's templates are dead weight.
  find "${TMPDIR:-/tmp}" -maxdepth 1 -name "rsp-fixture-$(id -u)-*" -type d -mtime +0 \
    -exec rm -rf {} + 2>/dev/null
  printf '%s\n' "$dir"
}

# Where the fixture is and what the script under test must read. Separate from building it,
# because a process that restores the template instead of building it needs this all the same.
_fixture_env(){
  # A Debian seed runs mawk, which is stricter than gawk in ways that matter here: it ignores
  # a {n} interval regex instead of honouring it, and prints an integer over 2^31 as %.6g.
  # Test against it wherever it exists, or a program that only works under gawk ships green.
  AWKBIN=${AWK:-$(command -v mawk || command -v awk)}
  export PATH="$ROOT/bin:$PATH"

  export RSP_HOME="$ROOT/rad-home"
  export RSP_NID="z6MkourNodexxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
  export RSP_MANIFEST="$ROOT/manifest.tsv"
  export RSP_DELEGATES="$ROOT/delegates.tsv"

  # ISOLATION: pin every input the script reads so a test can NEVER touch the real Radicle
  # home, even if the caller's shell exported RAD_HOME/RAD/STORAGE/etc. STORAGE in particular
  # confines all deletions to the temp dir (the script only rm's paths under "$STORAGE"/z*).
  export RAD="$ROOT/bin/rad"
  export RAD_HOME="$RSP_HOME"
  export STORAGE="$RSP_HOME/storage"
  export CONFIG="$RSP_HOME/config.json"
  export AUDIT_DIR="$RSP_HOME/prune-audit"
  unset OUR_NID   # read from the stub's `rad self --did`, so that path runs in every test
  export SERVICE="rsp-test-does-not-exist.service"
  # Hermetic git: ignore the user's global/system config, so fixture commits never use their
  # signing key (gpgsign) or identity, and the host config can't change behaviour.
  export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null
}

_build_fixture(){
  local bin="$ROOT/bin"; mkdir -p "$bin"
  cp "$HERE/rad-stub" "$bin/rad"; chmod +x "$bin/rad"
  ln -sf "$AWKBIN" "$bin/awk"
  echo "# awk under test: $(readlink -f "$AWKBIN")"

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
# One past applied run, as the ratchet reads it: an audit log and the history.log line naming it.
# $1 = which run (1-9, oldest first), then any of: "reason:count" for what it pruned,
# "held:<rule>" for a rule it held back, "rules:<letters>" for the rules it ran with.
past_run(){
  local i=$1 spec reason count r log="prune-2026010${1}T000000Z.log" rules="" held=""
  shift
  for spec in "$@"; do
    case $spec in rules:*) rules="  rules=${spec#rules:}" ;; held:*) held+=" ${spec#held:}" ;; esac
  done
  mkdir -p "$AUDIT_DIR"
  { printf '# 2026-01-0%sT00:00:00Z  pressure=0%%%s\n' "$i" "$rules"
    for r in $held; do printf '# held back: rule %s, 99 repos (usual 0, limit 20)\n' "$r"; done
    for spec in "$@"; do
      case $spec in rules:*|held:*) continue ;; esac
      reason=${spec%%:*}; count=${spec#*:}
      for r in $(seq 1 "$count"); do
        printf 'zpast%s%s%s\t1\t1\t1\t%s\tpast\t1\t\n' "$i" "${reason%%-*}" "$r" "$reason"
      done
    done; } > "$AUDIT_DIR/$log"
  printf '2026-01-0%sT00:00:00Z\tdeleted=1\taudit=%s\n' "$i" "$log" >> "$AUDIT_DIR/history.log"
}
# A past where every rule but C pruned plenty and C pruned nothing, so only C is over its usual.
# The fixture plans 4 of rule A, 1 of B, 4 of C, 13 of D and 14 of F.
USUAL_BUT_C="junk-name:20 junk-id:20 size-outlier:20 spam-batch:50 link-farm:50 media-dump:50"
# The same past for every rule but C, which each test then writes its own history for.
REST="junk-name:20 junk-id:20 size-outlier:20 spam-batch:50 media-dump:50"

# drop the tty for the non-interactive --apply test
NOTTY=(); command -v setsid >/dev/null && NOTTY=(setsid)

# $1 = a dir to fill with symlinks to everything on the real PATH except the commands named
# after it, for the tests that run the script against a PATH short of something.
# Mirrored rather than listed, because a hand-written list of what the tool needs goes stale
# and then fails as "the tool needs git" when it means "the test forgot cut".
path_without(){
  local dir=$1 d gone
  shift
  mkdir -p "$dir"
  # One PATH entry per line, because a directory with a space in its name is one entry.
  while IFS= read -r d; do
    [ -d "$d" ] || continue
    find "$d" -maxdepth 1 \( -type f -o -type l \) -print0 2>/dev/null \
      | xargs -0r ln -sn -t "$dir" 2>/dev/null
  done < <(printf '%s\n' "${PATH//:/$'\n'}")
  for gone in "$@"; do rm -f "$dir/$gone"; done
}

# The three peers the rule G fixture pushes with: the parasite, the one who also wrote
# something, and the one who delegates a repo of its own. Named here rather than in the
# section that first checks them, because six sections read them.
PARA=zPARASITExxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
WRITER=zWRITERxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
CONTRIB=$(dlg zparaown)

summary(){
  [ -n "${ROOT:-}" ] && rm -rf "$ROOT" 2>/dev/null
  echo "-----------------------------------------"
  echo "passed: $PASS   failed: $FAIL"
  [ "$FAIL" = 0 ]
}

# ---- end of header ---------------------------------------------------------
# Everything below the marker is one long straight-line script, cut into sections by the
# fixture rebuild that opens each one. A section always starts from a fresh fixture, so running
# one on its own gives the same result it gets in the whole suite. This prints the sections a
# caller asked for, or, in count mode, how many there are.
sections(){                      # $1 = regex, or "" for all   $2 = index, or 0   $3 = "count"?
  awk -v pat="$1" -v want="$2" -v mode="$3" '
    function flush() {
      if (buf == "") return
      n++
      if (mode != "count") {
        if (want > 0) { if (n == want) printf "%s", buf }
        else if (pat == "" || buf ~ pat) printf "%s", buf
      }
      buf = ""
    }
    /^# ---- end of sections/ { stop = 1 }
    stop { next }
    /^build_fixture($|;)/ { flush(); started = 1 }
    started { buf = buf $0 "\n" }
    END { flush(); if (mode == "count") print n }
  ' "$0"
}

# Settings every section runs under, so a section run on its own is the same run it gets in
# the whole suite. PLAN_FULL because nearly every assertion looks for one repo's row, and the
# folding that hides those rows on a real 519-row plan gets its own test rather than silencing
# the rest.
export DISK_AWARE=0 ABS_SIZE_FLOOR_MB=1 MEDIA_MIN_BYTES=20000 PLAN_FULL=1

# The three ways to run something other than the whole file in one process:
#
#   tests/run.sh -k quarantine   the sections whose text matches this regular expression. A
#                                test name, a rid, a knob or a rule letter all select one,
#                                which is the loop to be in while changing a single rule.
#   tests/run.sh -n 7            the 7th section alone, in a process of its own.
#   tests/run.sh -e              every section, each in a process of its own, one after
#                                another. Slower than a plain run and not there for speed: a
#                                section that only passes because the section above it ran
#                                first fails here, and that is what keeps -k honest.
case "${1:-}" in
  -k|-n)
    [ $# -ge 2 ] || { echo "usage: $0 [-k PATTERN | -n INDEX | -e]"; exit 3; }
    [ "$1" = -k ] && chosen=$(sections "$2" 0 "") || chosen=$(sections "" "$2" "")
    [ -n "$chosen" ] || { echo "no section matches: $2"; exit 3; }
    eval "$chosen"
    summary
    exit
    ;;
  -e)
    total=$(sections "" 0 count); printed=$(mktemp)
    # Each section keeps its own tally in its own process and prints it, which is noise forty
    # times over, so the tallies are dropped here and the ok and FAIL lines counted instead.
    for i in $(seq 1 "$total"); do
      bash "$0" -n "$i" || echo "# section $i exited $?, see above"
    done | grep -vE '^(-+$|passed: )' | tee "$printed"
    PASS=$(grep -c '^ok   - ' "$printed")
    FAIL=$(grep -c '^FAIL - ' "$printed")
    # A section that died part-way took the assertions after it down with it, and neither count
    # above can see the ones that never ran.
    [ "$FAIL" -gt 0 ] || FAIL=$(grep -c '^# section [0-9]* exited ' "$printed")
    rm -f "$printed"
    summary
    exit
    ;;
esac

# ============================================================================
# The classification tests below are cut into the sections that follow rather than left as
# one, so that -k on a rule reaches a handful of runs instead of forty. The price is that
# several of them build the same default plan again for themselves: a section that borrowed it
# from another could not be run on its own.
build_fixture
assert_isolated                                   # STORAGE must be inside the temp fixture

# --- classification & exclusions (relaxed thresholds, disk-awareness off) ---
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


build_fixture; assert_isolated
# Built here rather than inherited, so this section can run on its own.
plan=$(run)

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


build_fixture; assert_isolated

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
plan_e0=$(RULES=ABCDFG LINK_MIN_REPOS=3 LINK_MIN_SCORE=2 run)
[ "$(grep -cE "^zfarm[1-3] " <<<"$plan_e0" || true)" = 0 ] \
  && ok "a RULES without E spares them, so the hits above came from rule E" \
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


build_fixture; assert_isolated

# --- rule E: whose links count, and what counts as one host --- The thresholds are lowered
# again here, and the plan built rather than inherited, so this section can run on its own.
plan_e=$(LINK_MIN_REPOS=3 LINK_MIN_SCORE=2 run)

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


build_fixture; assert_isolated
# Built here rather than inherited, so this section can run on its own.
plan=$(run)

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


build_fixture; assert_isolated

# --- rule F: the batch path, and every threshold that gates a media verdict --- Both read one
# default plan, built here rather than inherited, so this section can run on its own.
plan=$(run)

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
plan_fo=$(RULES=ABCDEG run)
# The "# PLAN:" line is the last thing a run prints, so it separates "rule F found nothing"
# from "the run died before it could".
{ ! has "$plan_fo" "zmediaone" && grep -q 'F media-dump.*DISABLED' <<<"$plan_fo" \
  && grep -q '^# PLAN:' <<<"$plan_fo"; } \
  && ok "a RULES without F turns rule F off, says so, and still finishes" \
  || no "a RULES without F disables rule F"

# Rule F may take the last copy we know of, like rules D and E. Its evidence is what the repo
# itself holds, and a dump nobody else seeds is still a dump.
grep -qE "^zmediazero .*media-dump" <<<"$plan" \
  && ok "a media dump no other node seeds is pruned by default" \
  || no "the default seed floor spared a dump nobody else seeds"
plan_fz=$(MEDIA_MIN_SEEDS=1 run)
! has "$plan_fz" "zmediazero" \
  && ok "MEDIA_MIN_SEEDS=1 keeps the last copy we know of" \
  || no "MEDIA_MIN_SEEDS is vacuous"
# Sparing it silently would make the seed floor a permanent hiding place, so a run that raised
# the floor says what it saw and left alone.
{ grep -q '^# review: 1 media dump(s) no other node seeds, kept:' <<<"$plan_fz" \
    && grep -qE '^#   zmediazero +media-dump' <<<"$plan_fz"; } \
  && ok "the dump it kept is named for a human to look at" \
  || no "the review list names what it kept"
! grep -q '^# review:' <<<"$plan" \
  && ok "nothing to review at the default floor, where it was pruned instead" \
  || no "review list is vacuous"


build_fixture; assert_isolated

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

# Turning a rule off must not SPARE a repo the remaining rules would have taken. Rule D is the
# case that matters: its corpus scan runs whatever RULES says, because rule E reads its suspect
# list, so a dropped D verdict could shadow the rule C verdict underneath it.
withd=$(STALE_YEARS_DAYS=30 RULES=ABCDEFG run)
nod=$(STALE_YEARS_DAYS=30 RULES=ABCEFG run)
{ has "$withd" "zspam1" && has "$nod" "zspam1" \
  && grep -qE "^zspam1 .* spam-batch " <<<"$withd" \
  && grep -qE "^zspam1 .* stale " <<<"$nod"; } \
  && ok "a repo a disabled rule would have claimed falls through to the next rule" \
  || no "RULES=ABCEFG let a batch member escape rule C as well as rule D"


build_fixture; assert_isolated

# --- rule G: parasite peers --- Three peers put the identical clip in the same three repos.
# Only one of them is accused, so each exemption is what separates it from the other two, not
# a shortage of evidence.
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


build_fixture; assert_isolated

# --- gates on the script itself: its locale, its generated workers, its number formats ---

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


build_fixture; assert_isolated

# --- the clocks a row is judged on, and the margin printed beside them --- The ledger, the
# freshness guard and the AGE column all read one default plan, built here rather than
# inherited, so this section runs on its own.
plan=$(run)

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

# The NEAR column is what tells a reviewer which verdicts rest on a hair, so a row that
# cleared every threshold comfortably must stay unmarked, or the marking says nothing.
near_far=$(JUNK_STALE_DAYS=100 run)
near_close=$(JUNK_STALE_DAYS=350 run)
near_off=$(NEAR_PCT=0 JUNK_STALE_DAYS=350 run)
{ [ "$(awk '$1=="zjunk1"{print $6}' <<<"$near_far")" = "-" ] \
  && [ "$(awk '$1=="zjunk1"{print $6}' <<<"$near_close")" = "age" ] \
  && [ "$(awk '$1=="zjunk1"{print $6}' <<<"$near_off")" = "-" ]; } \
  && ok "NEAR marks a row that only just cleared its age threshold, and NEAR_PCT=0 marks none" \
  || no "the NEAR column did not follow the margin between the repo and its threshold"

# Counted under the plan too, because on a plan of hundreds of rows nobody scrolls the table
# to discover that a column has something in it.
grep -qE '^#   [0-9]+ of them cleared a threshold by under 20%' <<<"$near_close" \
  && ok "the plan summary counts the rows that were near a threshold" \
  || no "the plan never said how many of its rows were near a threshold"


build_fixture; assert_isolated

# --- what a run cannot read is reported, never quietly dropped --- A repo over the read
# budget, an empty listing, a home rad never saw, an injected failure, a node that is down
# and a directory nobody may read: each one is named, and the run finishes or aborts loudly.

# --- a repo larger than the read budget is judged, not excluded --- Reaching LINK_REPO_BUDGET
# closes the harvest pipe early and kills the object lister with SIGPIPE. Read as a failure,
# that quietly drops every large repo from the plan, and past MAX_SCAN_FAIL_PCT it aborts the
# whole run.
plan_bud=$(LINK_REPO_BUDGET=100 run)
{ has "$plan_bud" "zheavy" && ! grep -q "could not read .* repo(s)" <<<"$plan_bud"; } \
  && ok "a repo bigger than the read budget is still judged, and not counted as unreadable" \
  || no "the read budget excluded a big repo or reported it as a read failure"

# --- an empty `rad ls` degrades loudly: blank names and a blind rule D would otherwise look
# exactly like a clean seed ---
out=$(RSP_NO_LS=1 DISK_AWARE=0 ABS_SIZE_FLOOR_MB=1 run)
{ grep -q "WARN: .*returned no repos" <<<"$out" && ! grep -q '^# spam batches' <<<"$out"; } \
  && ok "an empty repo listing is reported, not silently read as 'no spam'" \
  || no "empty repo listing warns"

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

# The other way a non-number reaches an age comparison, and this one is in every heartwood
# repo: refs/rad/sigrefs points at a blob, a blob has no creatordate, so `for-each-ref
# --sort=creatordate` prints that ref first with an empty date field and the object id lands
# where the date should be. Rules D, E and F then compare a 40-hex string and spare the repo.
build_fixture; assert_isolated
blob=$(printf 'sigrefs\n' | GIT_DIR="$STORAGE/zmediaone" git hash-object -w --stdin)
GIT_DIR="$STORAGE/zmediaone" git update-ref refs/rad/sigrefs "$blob"
touch -d "10 days ago" "$STORAGE/zmediaone"        # update-ref just made the repo look fresh
out=$(DISK_AWARE=0 run)
{ grep -qE "^zmediaone .*media-dump" <<<"$out" \
  && ! grep -q 'integer expression' <<<"$out"; } \
  && ok "a ref with no date does not put an object id where the repo's age belongs" \
  || no "a dateless ref blinded the age rules, and the repo went unjudged"

# The tables under the plan header are the evidence a corpus verdict rests on, and each shows
# only its top few. Truncated with no way to reach the rest, a reviewer cannot check the other
# 153 spam domains that condemned a repo, so PLAN_FULL lifts these caps as well as the row
# folding it already controls, and every truncated list says so.
build_fixture; assert_isolated
victims=(zjunk1 zbig2 ztwoyr3 zfresh4); stamps=()
for r in "${victims[@]}"; do
  stamps+=("$(stat -c %y "$STORAGE/$r")")
  mkdir -p "$STORAGE/$r/unreadable" && chmod 000 "$STORAGE/$r/unreadable"
  touch -d "10 days ago" "$STORAGE/$r"     # a repo written moments ago is skipped as fresh
done
short=$(DISK_AWARE=0 MAX_SCAN_FAIL_PCT=90 PLAN_FULL=0 "$SCRIPT" 2>&1)
long=$( DISK_AWARE=0 MAX_SCAN_FAIL_PCT=90 PLAN_FULL=1 "$SCRIPT" 2>&1)
# Taking the directory back out writes the repo again, so the mtimes go back to what the
# fixture set. Left at now, all four read as fresh and the tests below lose their subjects.
for i in "${!victims[@]}"; do
  d="$STORAGE/${victims[$i]}"
  chmod 755 "$d/unreadable"; rmdir "$d/unreadable"; touch -d "${stamps[$i]}" "$d"
done
{ grep -q 'more (PLAN_FULL=1 lists them)' <<<"$short" \
  && ! grep -q 'more (PLAN_FULL=1 lists them)' <<<"$long" \
  && [ "$(grep -c 'Permission denied' <<<"$long")" \
       -gt "$(grep -c 'Permission denied' <<<"$short")" ]; } \
  && ok "PLAN_FULL prints the evidence tables whole, and the short form names the way there" \
  || no "a truncated evidence table gave a reviewer no way to see the rest of it"

# What the terminal showed is trimmed and then scrolls away, so the lists behind it are written
# out whole on every run, a dry one included. The point is not that the files exist: it is that
# they hold the rows the screen left out, and that a reviewer is told where they are.
build_fixture; assert_isolated
L="$RSP_HOME/prune-audit/last-run"
short=$(DISK_AWARE=0 PLAN_COLLAPSE_ROWS=2 PLAN_FULL=0 run)
# Counted against the plan's own total, not against a number written here: a file holding
# every row but one would pass any comparison with what the screen happened to print.
planned=$(sed -n 's/^# PLAN: prune \([0-9]*\) repos.*/\1/p' <<<"$short")
screenrows=$(grep -cE '^z[1-9A-HJ-NP-Za-km-z]+ ' <<<"$short")
cols=$(printf '# rid\tsize_bytes\tother_seeds\tlast_activity_unix\treason')
cols=$cols$(printf '\tname\tage_from_unix\tnear_threshold')
# Read months later a file of repo ids says nothing about which run condemned them, so every
# one of them opens with the same stamp naming that run.
stamped=1
for f in plan spam-batches spam-domains media-review parasite-peers; do
  grep -qE '^# [0-9-]+T[0-9:]+Z  version=[0-9.]+  mode=DRY-RUN  rules=[A-G]+  storage=/' \
       "$L/$f.tsv" || stamped=0
done
{ grep -q "the untrimmed plan and the evidence behind it: $L/" <<<"$short" \
  && [ "$(sed -n '2p' "$L/plan.tsv")" = "$cols" ] \
  && [ "$(grep -vc '^#' "$L/plan.tsv")" = "${planned:-0}" ] \
  && [ "${planned:-0}" -gt "$screenrows" ] \
  && [ "$stamped" = 1 ] \
  && [ -e "$L/spam-batches.tsv" ] && [ -e "$L/spam-domains.tsv" ] \
  && [ -e "$L/media-review.tsv" ] && [ -e "$L/parasite-peers.tsv" ] \
  && [ -e "$L/scan-errors.txt" ] && [ ! -e "$L.new" ]; } \
  && ok "a dry run writes the whole plan out and says where, however folded the screen was" \
  || no "the rows the plan folded away were nowhere to be found after the run"

# The evidence files must carry what the tables trimmed, not just the top few the screen got.
# The fixture holds two media dumps and the screen shows five, so the table only truncates once
# there are more of them than that: copies of one dump, each a repo in its own right to every
# rule, take the count past the cut with no new fixture to maintain.
build_fixture; assert_isolated
L="$RSP_HOME/prune-audit/last-run"
for i in 1 2 3 4 5 6; do cp -a "$STORAGE/zmediamd" "$STORAGE/zmediacopy$i"; done
screen=$(DISK_AWARE=0 MEDIA_MIN_SEEDS=99 PLAN_FULL=0 run)
kept=$(sed -n 's/^# review: \([0-9]*\) media dump.*/\1/p' <<<"$screen")
full=$( DISK_AWARE=0 MEDIA_MIN_SEEDS=99 PLAN_FULL=1 run)
# The rows the review table itself printed, which is what the cap acts on. The "...and N more"
# line wears the same indent as a row and would otherwise count as one.
reviewrows() { awk '/^# review:/ { inb = 1; next }
                    inb && /^#   \.\.\.and/ { next }
                    inb && /^#   / { n++; next }
                    inb { inb = 0 }
                    END { print n + 0 }'; }
{ [ "${kept:-0}" -gt 5 ] \
  && [ "$(grep -vc '^#' "$L/media-review.tsv")" = "$kept" ] \
  && [ "$(sed -n '2p' "$L/media-review.tsv")" = "$(printf '# rid\tverdict\tname')" ] \
  && [ "$(reviewrows <<<"$screen")" = 5 ] \
  && grep -q "^#   ...and $((kept - 5)) more (PLAN_FULL=1 lists them)" <<<"$screen" \
  && [ "$(reviewrows <<<"$full")" = "$kept" ] \
  && ! grep -q 'more (PLAN_FULL=1 lists them)' <<<"$full"; } \
  && ok "an evidence table the screen cut at five is written out in full" \
  || no "the evidence file was cut down to the same rows the screen showed"

# A count of repos rule F gave up on is a warning nobody can act on until it names them. Every
# repo in the fixture is over the ref ceiling below, so the walk gives up on all of them.
unj=$(DISK_AWARE=0 MEDIA_MAX_REFS=0 CACHE=0 run)
nunj=$(sed -n 's/^# WARN: rule F left \([0-9]*\) repo(s) unjudged.*/\1/p' <<<"$unj")
{ [ "${nunj:-0}" -gt 0 ] \
  && grep -q "^#   the $nunj repo(s) rule F left unjudged: $L/media-unjudged.tsv$" <<<"$unj" \
  && [ "$(grep -vc '^#' "$L/media-unjudged.tsv")" = "$nunj" ] \
  && grep -qx 'zmediamd' "$L/media-unjudged.tsv"; } \
  && ok "the repos rule F gave up on are named, not only counted" \
  || no "rule F warned about $nunj unjudged repos and named none of them"


# A read-only audit dir must cost the operator the files, not the run.
build_fixture; assert_isolated
mkdir -p "$RSP_HOME/prune-audit/last-run"
echo "from the run before" > "$RSP_HOME/prune-audit/last-run/plan.tsv"
chmod 500 "$RSP_HOME/prune-audit"
out=$(DISK_AWARE=0 "$SCRIPT" 2>&1); rc=$?
chmod 700 "$RSP_HOME/prune-audit"
{ [ "$rc" = 0 ] && grep -q '# PLAN:' <<<"$out" \
  && grep -q 'WARN: could not write .*last-run' <<<"$out" \
  && [ "$(cat "$RSP_HOME/prune-audit/last-run/plan.tsv")" = "from the run before" ]; } \
  && ok "an audit dir it cannot write costs the evidence files and says so, not the run" \
  || no "a read-only audit dir took the run down, or lost the evidence in silence"

# --- a scan that missed too much of storage refuses to report a plan at all --- Three
# unreadable repos against a 1% limit, so the assertion does not ride on the fixture size.
# Without this the run would report a plausible-looking small plan built from a partial scan.
for r in zjunk1 zbig2 zbar8; do chmod 000 "$STORAGE/$r"; done
out=$(DISK_AWARE=0 ABS_SIZE_FLOOR_MB=1 MAX_SCAN_FAIL_PCT=1 "$SCRIPT" 2>&1); rc=$?
for r in zjunk1 zbig2 zbar8; do chmod 755 "$STORAGE/$r"; done
{ [ "$rc" = 5 ] && grep -q "could not judge 3 of $NREPOS repos" <<<"$out" \
    && grep -q "0 vanished, 3 unreadable, 0 with no readable refs\." <<<"$out" \
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

# --- a dependency missing from PATH is named, not read as unreadable storage --- Without the
# preflight, every per-repo git call fails the way one unreadable repo does, and the run blames
# storage for a binary that is not installed.
nogit="$ROOT/nogit"; path_without "$nogit" git
out=$(PATH="$nogit" "$SCRIPT" 2>&1); rc=$?
{ [ "$rc" = 1 ] && grep -q 'missing required command(s): git$' <<<"$out" \
    && grep -q "^PATH=$nogit$" <<<"$out"; } \
  && ok "a git missing from PATH is named, with the PATH that was searched" \
  || no "missing git named (got exit $rc)"

# A quarantine verb is checked against what it calls, not against what a scan calls, so the
# list it is checked against has to be right: restore reaches dirname through the keep file it
# writes, and without dirname it puts a repo back that the next run prunes again.
nodirname="$ROOT/nodirname"; path_without "$nodirname" dirname
out=$(PATH="$nodirname" "$SCRIPT" quarantine restore zjunk1 2>&1); rc=$?
{ [ "$rc" = 1 ] && grep -q 'missing required command(s): dirname$' <<<"$out"; } \
  && ok "a quarantine verb names the command it needs and does not half-run" \
  || no "quarantine restore ran without dirname (got exit $rc)"

# rad is looked up through $RAD and not through the list above, so it gets its own check: a
# seed whose rad is a Nix store path is exactly where this is typed wrong.
out=$(RAD="$ROOT/no-such-rad" "$SCRIPT" 2>&1); rc=$?
{ [ "$rc" = 1 ] && grep -q "no rad at '$ROOT/no-such-rad'" <<<"$out"; } \
  && ok "a rad that is not there is named, with the path that was tried" \
  || no "missing rad named (got exit $rc)"

# --- the per-repo workers do not need bash on PATH --- A run started as
# `/nix/store/.../bash rad-prune` has the shell by absolute path and not through PATH.
# The stub's shebang is rewritten because `env bash` cannot find bash here either, and the stub
# is not what this test is about.
nobash="$ROOT/nobash"; path_without "$nobash" bash sh rad
realbash=$(command -v bash)
sed "1s|.*|#!$realbash|" "$HERE/rad-stub" > "$nobash/rad"; chmod +x "$nobash/rad"
out=$(PATH="$nobash" RAD="$nobash/rad" DISK_AWARE=0 ABS_SIZE_FLOOR_MB=1 \
      "$realbash" "$SCRIPT" 2>&1); rc=$?
{ [ "$rc" = 0 ] && has "$out" "zjunk1" \
    && ! grep -q 'No such file or directory' <<<"$out"; } \
  && ok "the workers run with bash off PATH" \
  || no "workers need bash on PATH (got exit $rc)"

# --- a walk that read nothing is refused, not reported as an empty plan --- A ref walk that
# dies wholesale leaves every repo ageless, every age rule then skips it, and the plan comes
# out empty from a scan that read no dates at all.
nolife="$ROOT/nolife"; mkdir -p "$nolife"
cp "$HERE/no-life-xargs-shim" "$nolife/xargs"; chmod +x "$nolife/xargs"
out=$(PATH="$nolife:$PATH" DISK_AWARE=0 ABS_SIZE_FLOOR_MB=1 "$SCRIPT" 2>&1); rc=$?
{ [ "$rc" = 5 ] && grep -q 'with no readable refs\.' <<<"$out" \
    && ! grep -q '# PLAN:' <<<"$out"; } \
  && ok "a scan with no ref dates aborts (no empty plan)" \
  || no "ref-less scan aborts (got exit $rc)"
grep -q "# activity: 0 of $NREPOS repos in" <<<"$out" \
  && ok "a phase reports what it read, not the total it set out to read" \
  || no "phase that read nothing still reported its own total"

# --- a fetch still arriving is fresh, not ageless --- A repo whose directory exists before its
# refs do has no age, and counting it against the blind-scan limit would abort a run over
# nothing worse than a busy node.
git init -q --bare "$STORAGE/zinflightfetch"
touch "$STORAGE/zinflightfetch"
out=$(DISK_AWARE=0 ABS_SIZE_FLOOR_MB=1 "$SCRIPT" 2>&1); rc=$?
rm -rf "$STORAGE/zinflightfetch"
{ [ "$rc" = 0 ] && grep -q '^# skipped: .*, 0 with no readable refs$' <<<"$out"; } \
  && ok "a repo with no refs yet counts as freshly written, not as ageless" \
  || no "an in-flight fetch counted against the blind-scan limit (got exit $rc)"

# --- fail-safe: node down aborts --apply before touching anything ---
RSP_NODE_DOWN=1 DISK_AWARE=0 ABS_SIZE_FLOOR_MB=1 "$SCRIPT" --apply >/dev/null 2>&1; rc=$?
[ "$rc" = 5 ] \
  && ok "node-down aborts --apply (exit 5)" \
  || no "node-down aborts --apply (got exit $rc)"

# --- apply: non-interactive (cron path) applies; interactive prompt (pty) obeys y/N ---
# non-interactive --apply (no controlling tty): applies directly, no prompt.
build_fixture; assert_isolated                    # fresh fixture before the tests that delete
DISK_AWARE=0 ABS_SIZE_FLOOR_MB=1 "${NOTTY[@]}" "$SCRIPT" --apply </dev/null \
  >"$ROOT/apply.out" 2>&1
aout=$(cat "$ROOT/apply.out")
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

# The prune is the one phase that changes anything, and it reports over the whole plan, so
# these two numbers are read out of the run's own output rather than counted here.
planned=$(sed -n 's/^# PLAN: prune \([0-9]*\) repos.*/\1/p' <<<"$aout")
pruning=$(sed -n 's/^# pruning: \([0-9]*\) repos in.*/\1/p' <<<"$aout")
{ [ -n "$planned" ] && [ "$pruning" = "$planned" ]; } \
  && ok "the prune reports its progress over every repo in the plan" \
  || no "prune progress covered $pruning of $planned planned repos"

# What a run that has just moved GiB out of storage is asked next is how to get the disk back.
grep -q 'quarantine delete --all' <<<"$aout" \
  && ok "the DONE line says how to reclaim the disk now" \
  || no "DONE line does not name the reclaim command"

# Where a run writes is asked before it finishes, so the answer is in the header.
grep -q "audit=$AUDIT_DIR" <<<"$aout" \
  && ok "the header names the audit dir" \
  || no "header does not name the audit dir"

# --- an apply that could block nothing --- The block is what stops a deleted repo being
# fetched straight back, so a repo it failed on stays in storage. Every line the run then
# prints has to agree with the disk: a progress phase that counted repos attempted would close
# with the full plan directly above the warning that none of it happened.
build_fixture; assert_isolated
RSP_BLOCK_FAIL=1 DISK_AWARE=0 ABS_SIZE_FLOOR_MB=1 "${NOTTY[@]}" "$SCRIPT" --apply </dev/null \
  >"$ROOT/blockfail.out" 2>&1
bout=$(cat "$ROOT/blockfail.out")
planned=$(sed -n 's/^# PLAN: prune \([0-9]*\) repos.*/\1/p' <<<"$bout")
kept=1
for r in zjunk1 zbig2 ztwoyr3; do [ -e "$STORAGE/$r" ] || kept=0; done
{ [ -n "$planned" ] && [ "$kept" = 1 ] \
  && grep -q "^# pruning: 0 of $planned repos in" <<<"$bout" \
  && grep -q "^# WARN: $planned of $planned deletions failed" <<<"$bout" \
  && grep -q '^#   WARN block failed, skipping delete: ' <<<"$bout"; } \
  && ok "an apply that blocked nothing deletes nothing and reports 0 of the plan pruned" \
  || no "a failed apply deleted repos or reported the whole plan as pruned"

# The quarantine advice is about what THIS run put there, so a run that put nothing there does
# not print it and does not point at a delete --all that would take earlier runs' repos.
{ grep -q '^# DONE: quarantined 0 repos' <<<"$bout" \
  && ! grep -q 'quarantine delete --all' <<<"$bout"; } \
  && ok "a run that quarantined nothing leaves out the quarantine advice" \
  || no "quarantine advice printed after a run that quarantined nothing"

# The progress line is redrawn in place on a terminal, and its warnings clear it first. Into a
# log there is no line to clear, and an escape sequence written there is not readable later.
grep -q $'\033' <<<"$bout" \
  && no "the run wrote terminal escapes into output that is not a terminal" \
  || ok "no terminal escapes reach output that is not a terminal"

# --- a quarantine copy that could not be dated --- The purge measures the window from the
# directory's date, so a copy that kept the repo's own date counts its window from a date this
# run did not choose. The repo did leave storage, so it counts as pruned; what it may not have
# is the full undo the closing line promises, and that line is the one an operator reads
# before walking away.
build_fixture; assert_isolated
notouch="$ROOT/notouch"; mkdir -p "$notouch"
cp "$HERE/failing-touch-shim" "$notouch/touch"; chmod +x "$notouch/touch"
PATH="$notouch:$PATH" DISK_AWARE=0 ABS_SIZE_FLOOR_MB=1 "${NOTTY[@]}" "$SCRIPT" --apply \
  </dev/null >"$ROOT/undated.out" 2>&1
uout=$(cat "$ROOT/undated.out")
uplanned=$(sed -n 's/^# PLAN: prune \([0-9]*\) repos.*/\1/p' <<<"$uout")
{ [ -n "$uplanned" ] \
  && grep -q "^# DONE: quarantined $uplanned repos" <<<"$uout" \
  && grep -q "^# $uplanned of them kept their own date, so their window runs from it and may" \
       <<<"$uout" \
  && grep -q 'kept its own date in quarantine' <<<"$uout" \
  && ! grep -q 'deletions failed' <<<"$uout"; } \
  && ok "a quarantine copy that kept its own date is pruned, and its short undo is reported" \
  || no "a copy that kept its own date was reported as recoverable for the full window"

# --- rule G's act, the only thing in the tool that judges a PERSON --- Blocking is permanent
# and the peer never hears about it, so it needs a human in the room every time: --apply alone
# must not reach it, and --block-peers must refuse when there is nobody to ask.
#
# Each of the five sections below sets rule G's thresholds again. They are the same three
# values every time and only the first needs them in a full run, but a section that inherited
# them from the section above could not be run on its own, and one that judges no peer at all
# passes these assertions for the wrong reason.
build_fixture; assert_isolated
export PARASITE_MIN_REPOS=3 PARASITE_MIN_BYTES=65536 PARASITE_TEXT_MAX_BYTES=4096
DISK_AWARE=0 ABS_SIZE_FLOOR_MB=1 "${NOTTY[@]}" "$SCRIPT" --apply </dev/null >/dev/null 2>&1
{ ! grep -q "$PARA" "$RSP_HOME/.stub_block" 2>/dev/null \
  && GIT_DIR="$STORAGE/zpara1" git for-each-ref "refs/namespaces/$PARA/" \
       --format=x 2>/dev/null | grep -q x; } \
  && ok "--apply on its own blocks no peer and drops no peer refs" \
  || no "--apply acted on a peer without --block-peers"

build_fixture; assert_isolated
export PARASITE_MIN_REPOS=3 PARASITE_MIN_BYTES=65536 PARASITE_TEXT_MAX_BYTES=4096
DISK_AWARE=0 ABS_SIZE_FLOOR_MB=1 "${NOTTY[@]}" "$SCRIPT" --apply --block-peers \
  </dev/null >"$ROOT/nb.out" 2>&1
{ ! grep -q "$PARA" "$RSP_HOME/.stub_block" 2>/dev/null \
  && grep -q "nobody to ask" "$ROOT/nb.out"; } \
  && ok "--block-peers refuses with no terminal rather than blocking unattended" \
  || no "--block-peers blocked a peer with nobody there to approve it"

# The unattended form an operator asks for explicitly. Two opt-ins, because this blocks a peer
# across every repo at once with nobody reviewing it.
build_fixture; assert_isolated
export PARASITE_MIN_REPOS=3 PARASITE_MIN_BYTES=65536 PARASITE_TEXT_MAX_BYTES=4096
DISK_AWARE=0 ABS_SIZE_FLOOR_MB=1 "${NOTTY[@]}" "$SCRIPT" --block-peers --yes \
  </dev/null >"$ROOT/by.out" 2>&1
{ grep -q "$PARA" "$RSP_HOME/.stub_block" 2>/dev/null \
  && grep -q "Blocking $PARA (--yes)" "$ROOT/by.out"; } \
  && ok "--block-peers --yes blocks without a terminal, and says it did" \
  || no "--block-peers --yes did not block the peer rule G named"

# "Exclusions (never touched)" has to mean the same thing whichever action is running: a kept
# repo keeps the parasite's refs too, and the block alone stops anything new landing in it.
build_fixture; assert_isolated
export PARASITE_MIN_REPOS=3 PARASITE_MIN_BYTES=65536 PARASITE_TEXT_MAX_BYTES=4096
echo zpara3 > "$RSP_HOME/keep.txt"
DISK_AWARE=0 ABS_SIZE_FLOOR_MB=1 KEEP_FILE="$RSP_HOME/keep.txt" "${NOTTY[@]}" \
  "$SCRIPT" --block-peers --yes </dev/null >"$ROOT/bk.out" 2>&1
{ GIT_DIR="$STORAGE/zpara3" git for-each-ref "refs/namespaces/$PARA/" --format=x 2>/dev/null \
    | grep -q x \
  && ! GIT_DIR="$STORAGE/zpara1" git for-each-ref "refs/namespaces/$PARA/" --format=x \
       2>/dev/null | grep -q x; } \
  && ok "an excluded repo keeps the blocked peer's refs, its neighbours do not" \
  || no "the ref drop ignored the exclusions, or stopped dropping refs anywhere"
rm -f "$RSP_HOME/keep.txt"

# --yes alone must not start blocking peers: the finding is not the act.
build_fixture; assert_isolated
export PARASITE_MIN_REPOS=3 PARASITE_MIN_BYTES=65536 PARASITE_TEXT_MAX_BYTES=4096
DISK_AWARE=0 ABS_SIZE_FLOOR_MB=1 "${NOTTY[@]}" "$SCRIPT" --apply --yes \
  </dev/null >/dev/null 2>&1
grep -q "$PARA" "$RSP_HOME/.stub_block" 2>/dev/null \
  && no "--yes blocked a peer without --block-peers" \
  || ok "--yes on its own blocks nobody"

plan_g=$(run)
grep -q "rad block $PARA" <<<"$plan_g" \
  && ok "the plan prints the exact rad block command for each peer it names" \
  || no "rule G named a peer without printing how to act on it"

if command -v script >/dev/null 2>&1; then
  # Two prompts, and the peer comes first because --block-peers is its own action that does
  # not wait on the prune. "n" then "y" leaves the peer alone and still applies the plan,
  # which is what separates the per-peer question from a blanket licence given by the flag.
  build_fixture; assert_isolated
  printf 'n\ny\n' | script -qec \
    "env DISK_AWARE=0 ABS_SIZE_FLOOR_MB=1 PARASITE_MIN_REPOS=3 PARASITE_MIN_BYTES=65536 \
         PARASITE_TEXT_MAX_BYTES=4096 '$SCRIPT' --apply --block-peers" /dev/null \
    >"$ROOT/gn.out" 2>&1
  { ! grep -q "$PARA" "$RSP_HOME/.stub_block" 2>/dev/null \
    && GIT_DIR="$STORAGE/zpara1" git for-each-ref "refs/namespaces/$PARA/" \
         --format=x 2>/dev/null | grep -q x \
    && [ ! -e "$STORAGE/zjunk1" ]; } \
    && ok "--block-peers + n leaves that peer alone, and the prune still applies" \
    || no "--block-peers blocked a declined peer, or the second answer missed the prune"

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
  GIT_DIR="$STORAGE/zpara1" git for-each-ref "refs/namespaces/$WRITER/" \
    --format=x 2>/dev/null | grep -q x || kept=0
  { [ "$gonerefs" = 1 ] && [ "$kept" = 1 ]; } \
    && ok "a blocked peer's refs are dropped and nothing else is touched" \
    || no "blocking left the peer's refs behind or removed somebody else's"
  grep -q "blocked-peer.*$PARA.*repos=" "$RSP_HOME/prune-audit/"prune-*.log 2>/dev/null \
    && ok "a block is recorded in the audit log with the evidence behind it" \
    || no "a peer was blocked without the evidence being written down"

  # Blocking a peer and pruning repos are separate decisions, so --block-peers must stand on
  # its own: nobody should have to delete the whole plan to deal with one peer. One "y", for
  # the peer, since without --apply there is no plan prompt to answer.
  build_fixture; assert_isolated
  before=$(ls "$STORAGE" | wc -l)
  printf 'y\n' | script -qec \
    "env DISK_AWARE=0 ABS_SIZE_FLOOR_MB=1 PARASITE_MIN_REPOS=3 PARASITE_MIN_BYTES=65536 \
         PARASITE_TEXT_MAX_BYTES=4096 '$SCRIPT' --block-peers" /dev/null \
    >"$ROOT/gsolo.out" 2>&1
  grep -q "$PARA" "$RSP_HOME/.stub_block" 2>/dev/null \
    && ok "--block-peers blocks without --apply" \
    || no "--block-peers did nothing without --apply"
  { [ "$(ls "$STORAGE" | wc -l)" = "$before" ] \
    && [ ! -s "$RSP_HOME/.stub_unseed" ] \
    && grep -q "no repos were pruned" "$ROOT/gsolo.out"; } \
    && ok "--block-peers on its own prunes nothing" \
    || no "--block-peers pruned repos without --apply"
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

# A dry run promises disk it will not free for a month, so the plan line must not say
# "reclaim" while the quarantine is on, and must say it when it is off.
build_fixture; assert_isolated
qplan=$(DISK_AWARE=0 ABS_SIZE_FLOOR_MB=1 run)
{ grep -q "still on disk for 7d, until a later --apply run deletes them" <<<"$qplan" \
  && ! grep -q 'PLAN:.*reclaim' <<<"$qplan"; } \
  && ok "the plan does not promise disk the quarantine is still holding" \
  || no "the plan claimed to reclaim disk that quarantine keeps for a week"
DISK_AWARE=0 ABS_SIZE_FLOOR_MB=1 QUARANTINE=0 run | grep -q 'PLAN:.*reclaim' \
  && ok "QUARANTINE=0 puts the reclaim promise back in the plan" \
  || no "QUARANTINE=0 still hedged the plan's disk figure"

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

# The quarantine subcommands. An operator who has just read a wrong verdict needs to act on
# one repo, and the run that produced it is over: these are the only way to do that without
# hand-moving directories under a live node's storage.
build_fixture; assert_isolated
Q="$RSP_HOME/prune-audit/quarantine"
DISK_AWARE=0 ABS_SIZE_FLOOR_MB=1 "${NOTTY[@]}" "$SCRIPT" --apply </dev/null >/dev/null 2>&1
out=$("$SCRIPT" quarantine list 2>&1)
{ grep -q 'zjunk1' <<<"$out" && grep -q 'HELD' <<<"$out"; } \
  && ok "quarantine list names what a past run pruned" \
  || no "quarantine list did not show the repo the run had just quarantined"

# Restoring has to do three things: the directory, the node's block policy, and the verdict
# itself, or the very next run plans the same repo again. rad seed alone only ever rewrites an
# existing policy row's scope, so on a blocked repo it reports success and changes nothing;
# rad unseed deletes the row whatever policy it holds, which is what drops the block, and it
# is the spelling that exists on every rad version. The prune above already called unseed, so
# both stubs are emptied first: otherwise this would pass on the prune's own calls.
: > "$RSP_HOME/.stub_unseed"; : > "$RSP_HOME/.stub_seed"
out=$("$SCRIPT" quarantine restore zjunk1 2>&1)
{ [ -d "$STORAGE/zjunk1" ] && [ ! -e "$Q/zjunk1" ] \
  && GIT_DIR="$STORAGE/zjunk1" git rev-parse --verify -q master >/dev/null 2>&1 \
  && grep -qx 'rad:zjunk1' "$RSP_HOME/.stub_unseed" \
  && grep -qx 'rad:zjunk1' "$RSP_HOME/.stub_seed" \
  && grep -qx 'zjunk1' "$RSP_HOME/prune-audit/keep.txt"; } \
  && ok "quarantine restore puts the repo back, clears its block and keeps it" \
  || no "quarantine restore left the repo blocked, gone, or still condemned"

DISK_AWARE=0 ABS_SIZE_FLOOR_MB=1 run | grep -q 'zjunk1' \
  && no "a restored repo was planned for pruning all over again" \
  || ok "a repo on the keep list is left out of the next plan"

# Deleting one on demand, rather than waiting out the window.
build_fixture; assert_isolated
Q="$RSP_HOME/prune-audit/quarantine"
mkdir -p "$Q/zdead1" "$Q/zdead2"
"$SCRIPT" quarantine delete zdead1 >/dev/null 2>&1
{ [ ! -e "$Q/zdead1" ] && [ -d "$Q/zdead2" ]; } \
  && ok "quarantine delete removes exactly the repo it was given" \
  || no "quarantine delete took the wrong repo, or none"

"$SCRIPT" quarantine delete --all >/dev/null 2>&1
[ ! -e "$Q/zdead2" ] \
  && ok "quarantine delete --all empties it" \
  || no "quarantine delete --all left repos behind"

# Every verb builds a path from its argument, so an argument that is not a repo id must never
# reach rm or mv.
build_fixture; assert_isolated
Q="$RSP_HOME/prune-audit/quarantine"
canary="$ROOT/canary"; mkdir -p "$canary"
out=$("$SCRIPT" quarantine delete "../../../../../..${canary}" 2>&1 || true)
{ [ -d "$canary" ] && grep -q 'not a repo id' <<<"$out"; } \
  && ok "a quarantine verb refuses an argument that is not a repo id" \
  || no "a path argument reached rm through a quarantine verb"

# The same window a run applies, on demand, so an operator can free the disk without waiting.
build_fixture; assert_isolated
Q="$RSP_HOME/prune-audit/quarantine"
mkdir -p "$Q/zexpq1" "$Q/zfreshq1"; touch -d "40 days ago" "$Q/zexpq1"
out=$("$SCRIPT" quarantine purge 2>&1)
{ [ ! -e "$Q/zexpq1" ] && [ -d "$Q/zfreshq1" ] && grep -q 'purged 1 repo' <<<"$out"; } \
  && ok "quarantine purge takes what is past its window and nothing else" \
  || no "quarantine purge took the wrong repos"

# --- the run cache --- Rules E and F read every repo's contents, and almost nothing changes
# between weekly runs, so their per-repo output is kept and reused. The danger is not a slow
# run, it is a verdict resting on evidence that has since stopped being true.
build_fixture; assert_isolated
first=$(DISK_AWARE=0 run)
second=$(DISK_AWARE=0 run 2>&1)
{ grep -q 'cache: media reuses' <<<"$second" \
  && [ "$(grep -c 'media-dump' <<<"$first")" = "$(grep -c 'media-dump' <<<"$second")" ]; } \
  && ok "a second run reuses the first run's reading and plans the same repos" \
  || no "the warm cache changed the plan, or was never used"

# The direction that matters on a deleter: a repo that has stopped looking like a dump must
# not be pruned on last week's reading of it.
e_tree zmediaone 60 master "clip.mp4:40000:mp4" "README.md:9000"
DISK_AWARE=0 run | grep -qE "^zmediaone .*media-dump" \
  && no "a repo was condemned on cached evidence it no longer matches" \
  || ok "a repo that changed is read again, not judged on the cached reading"

# And the other direction, so the test above cannot pass by the cache simply never being used.
build_fixture; assert_isolated
DISK_AWARE=0 run >/dev/null
e_tree zcode4 60 master "clip.mp4:40000:mp4"
DISK_AWARE=0 run | grep -qE "^zcode4 .*media-dump" \
  && ok "a repo that has become a dump is caught on the next run" \
  || no "the cache hid a repo that turned into a media dump"

# A threshold the operator has just tuned must not leave last week's verdicts standing.
build_fixture; assert_isolated
DISK_AWARE=0 run >/dev/null
out=$(DISK_AWARE=0 MEDIA_MIN_BYTES=999999999 "${NOTTY[@]}" "$SCRIPT" </dev/null 2>&1)
{ grep -q 'cache: cold' <<<"$out" && ! has "$out" "zmediaone"; } \
  && ok "changing a threshold drops the whole cache" \
  || no "a tuned threshold reused verdicts measured under the old one"

build_fixture; assert_isolated
DISK_AWARE=0 run >/dev/null
out=$(DISK_AWARE=0 CACHE=0 "${NOTTY[@]}" "$SCRIPT" </dev/null 2>&1)
{ ! grep -q 'cache: media reuses' <<<"$out" \
  && grep -qE "^zmediaone .*media-dump" <<<"$out"; } \
  && ok "CACHE=0 reads every repo and still finds them" \
  || no "CACHE=0 still reused a cached reading"

# A repo that links to nothing produces no line of its own, so the harvest marks each repo
# it finished. Without that marker the cache cannot tell "read it, found nothing" from
# "never read it", and the repo would be read again every week.
build_fixture; assert_isolated
DISK_AWARE=0 run >/dev/null
DISK_AWARE=0 run 2>&1 | grep -q 'cache: hosts reuses' \
  && ok "the harvest reuses repos it read, including the ones that linked to nothing" \
  || no "the harvest cache never took effect"

# A cold start throws the key files of EVERY cached rule away, not only those of the rules it
# is about to rewrite. Stamping the new fingerprint once per rule instead left a run that died
# between two rules looking fully warm while half its keys still belonged to the old settings.
build_fixture; assert_isolated
CACHEDIR="$RSP_HOME/prune-audit/cache"
DISK_AWARE=0 run >/dev/null
[ -f "$CACHEDIR/keys-media" ] \
  || no "the first run wrote no media keys, so the next check is moot"
DISK_AWARE=0 RULES=E MEDIA_MIN_BYTES=999999999 "${NOTTY[@]}" "$SCRIPT" \
  </dev/null >/dev/null 2>&1
[ ! -f "$CACHEDIR/keys-media" ] \
  && ok "a cold start drops the keys of the rules it does not run, not just its own" \
  || no "a rule that sat out a cold run kept keys measured under the settings that changed"

# The fingerprint covers the settings this script reads, not whatever the caller happens to
# have in its environment. Hashing the whole environment made a systemd run and a hand run
# invalidate each other every time, since systemd stamps a fresh INVOCATION_ID on each start.
build_fixture; assert_isolated
DISK_AWARE=0 run >/dev/null
out=$(DISK_AWARE=0 INVOCATION_ID=deadbeef WHATEVER=1 "${NOTTY[@]}" "$SCRIPT" </dev/null 2>&1)
grep -q 'cache: media reuses' <<<"$out" \
  && ok "a variable this script never reads leaves the cache warm" \
  || no "an unrelated environment variable dropped the whole cache"

# A knob that only changes what is printed is in the fingerprint's skip list, because dropping
# the cache over it would re-read every repo on a seed of this size to no effect on the plan.
out=$(DISK_AWARE=0 PROGRESS_SECS=5 "${NOTTY[@]}" "$SCRIPT" </dev/null 2>&1)
grep -q 'cache: media reuses' <<<"$out" \
  && ok "changing the progress cadence leaves the cache warm" \
  || no "PROGRESS_SECS dropped the whole cache"

# STORAGE is an operator-supplied path, and the list of already-answered repos is built from
# it. A '#' in it used to end sed's own delimiter, which both re-walked every repo and pasted
# its cached rows in beside the fresh ones.
build_fixture; assert_isolated
odd="$RSP_HOME/st#or&age"
cp -r "$STORAGE" "$odd"
DISK_AWARE=0 STORAGE="$odd" "${NOTTY[@]}" "$SCRIPT" </dev/null >/dev/null 2>&1
out=$(DISK_AWARE=0 STORAGE="$odd" "${NOTTY[@]}" "$SCRIPT" </dev/null 2>&1)
{ ! grep -q 'unknown option' <<<"$out" && grep -q 'cache: media reuses' <<<"$out"; } \
  && ok "a storage path holding shell and sed metacharacters still caches correctly" \
  || no "a '#' in STORAGE broke the already-read list"

# Rule G judges a peer across the whole of storage, so its cached rows and its freshly walked
# ones are added together. A repo counted twice, or one banked from a walk that never
# finished, moves the byte totals the accusation rests on.
build_fixture; assert_isolated
export PARASITE_MIN_REPOS=3 PARASITE_MIN_BYTES=65536 PARASITE_TEXT_MAX_BYTES=4096
cold=$(DISK_AWARE=0 run)
warm=$(DISK_AWARE=0 run 2>&1)
{ grep -q 'cache: peer reuses' <<<"$warm" \
  && grep -q "PARASITE PEERS: 1" <<<"$cold" \
  && [ "$(grep -c 'PARASITE PEERS: 1' <<<"$warm")" = 1 ]; } \
  && ok "a warm run reaches rule G's verdict from cached rows unchanged" \
  || no "reusing rule G's reading changed which peers it accused"
unset PARASITE_MIN_REPOS PARASITE_MIN_BYTES PARASITE_TEXT_MAX_BYTES

# A repo already past the window is gone for good on the next run, which is what makes the
# quarantine bounded rather than a second copy of storage growing forever.
build_fixture; assert_isolated
Q="$RSP_HOME/prune-audit/quarantine"
mkdir -p "$Q/zoldquar"; touch -d "40 days ago" "$Q/zoldquar"
out=$(DISK_AWARE=0 ABS_SIZE_FLOOR_MB=1 "${NOTTY[@]}" "$SCRIPT" --apply </dev/null 2>&1)
{ [ ! -e "$Q/zoldquar" ] && grep -q 'purged 1 repo' <<<"$out"; } \
  && ok "quarantine is purged once the window passes" \
  || no "a quarantined repo outlived QUARANTINE_DAYS"

# The window has to run from when the repo ARRIVED in quarantine. mv keeps the source mtime,
# and rules B and C select repos nothing has touched for 90 to 730 days, so measuring from
# that would purge their recovery copy on the very next run. zrot1 is the stale fixture.
build_fixture; assert_isolated
Q="$RSP_HOME/prune-audit/quarantine"
# Age the directory itself, or mv would carry a fresh mtime across and the check below could
# not tell the fixed behaviour from the broken one.
touch -d "200 days ago" "$STORAGE/zrot1"
DISK_AWARE=0 ABS_SIZE_FLOOR_MB=1 STALE_YEARS_DAYS=30 "${NOTTY[@]}" "$SCRIPT" --apply \
  </dev/null >/dev/null 2>&1
[ -d "$Q/zrot1" ] || no "the stale fixture never reached quarantine, so the next check is moot"
out=$(DISK_AWARE=0 ABS_SIZE_FLOOR_MB=1 STALE_YEARS_DAYS=30 "${NOTTY[@]}" "$SCRIPT" --apply \
      </dev/null 2>&1)
{ [ -d "$Q/zrot1" ] && ! grep -q 'purged' <<<"$out"; } \
  && ok "a repo untouched for years still gets its full quarantine window" \
  || no "quarantine measured the window from the repo's own mtime, so it purged immediately"

# A seed that has caught up has an empty plan every week. If the purge only ran on weeks with
# something to prune, quarantined disk would never come back at all.
build_fixture; assert_isolated
Q="$RSP_HOME/prune-audit/quarantine"
mkdir -p "$Q/zoldquar2"; touch -d "40 days ago" "$Q/zoldquar2"
out=$(DISK_AWARE=0 RULES= "${NOTTY[@]}" "$SCRIPT" --apply </dev/null 2>&1)
{ [ ! -e "$Q/zoldquar2" ] && grep -q 'nothing to do' <<<"$out"; } \
  && ok "an empty plan still purges quarantine past its window" \
  || no "a run with nothing to prune left expired quarantine on disk"

# RULES= is set but empty, and on a deleter that has to mean NO rules. Read as unset it would
# fall back to the default and run all seven, which is the one direction that cannot be undone.
{ ! grep -qE '^z' <<<"$(RULES= run)" && has "$(run)" "zjunk1"; } \
  && ok "RULES= means no rules, not the default set" \
  || no "an empty RULES fell back to running every rule"

# --help is the one command a stranger runs first, and it used to read the script through a
# relative $0 after the script had already cd'd to /, so it died on whoever ran ./the-script.
h=$(cd "$ROOT" && "$SCRIPT" --help 2>&1); rc=$?
{ [ "$rc" = 0 ] && grep -q '^USAGE' <<<"$h" && grep -q -- '--block-peers' <<<"$h" \
  && grep -q 'quarantine <verb>' <<<"$h" && grep -q 'restore <rid>' <<<"$h" \
  && grep -qE '^ +RULES=' <<<"$h" && grep -qE '^ +RAD_HOME=' <<<"$h"; } \
  && ok "--help lists the options, the quarantine verbs and the resolved config" \
  || no "--help did not print a usable help (rc=$rc)"

# The subcommand has to answer --help too, and an unknown verb has to say so and fail.
hq=$(cd "$ROOT" && "$SCRIPT" quarantine --help 2>&1); rcq=$?
bq=$(cd "$ROOT" && "$SCRIPT" quarantine nosuchverb 2>&1); rcb=$?
{ [ "$rcq" = 0 ] && grep -q 'QUARANTINE VERBS' <<<"$hq" \
  && [ "$rcb" = 2 ] && grep -q 'unknown quarantine verb: nosuchverb' <<<"$bq"; } \
  && ok "quarantine --help helps, and an unknown verb exits 2 naming itself" \
  || no "quarantine --help or the unknown-verb path is wrong (rc=$rcq/$rcb)"

# The verbs that only read the quarantine must work when storage is unmounted, which is when
# an operator most wants to see what is still recoverable.
build_fixture; assert_isolated
mv "$STORAGE" "$ROOT/storage-away"
qout=$(QUARANTINE_DAYS=7 "$SCRIPT" quarantine list 2>&1); rc=$?
mv "$ROOT/storage-away" "$STORAGE"
{ [ "$rc" = 0 ] && ! grep -q 'no storage dir' <<<"$qout"; } \
  && ok "quarantine list works with storage unmounted" \
  || no "quarantine list refused to run without storage (rc=$rc)"

# They must also work when the tools a SCAN needs are missing, for the same reason: the
# quarantine holds repos that are already out of storage and none of those tools reads it.
Q="$RSP_HOME/prune-audit/quarantine"
mkdir -p "$Q/zheldrepo"; : > "$Q/zheldrepo/some-file"
noscan="$ROOT/noscan"; path_without "$noscan" git jq awk sed find xargs sort sha1sum od df
qout=$(PATH="$noscan" RAD="$ROOT/no-such-rad" "$SCRIPT" quarantine list 2>&1); rc=$?
rm -rf "$Q/zheldrepo"
{ [ "$rc" = 0 ] && grep -q '^zheldrepo ' <<<"$qout"; } \
  && ok "quarantine list works without the tools a scan needs" \
  || no "quarantine list needs the scan's dependencies (rc=$rc)"

# At the critical watermark a recovery copy is a luxury the disk cannot buy.
build_fixture; assert_isolated
Q="$RSP_HOME/prune-audit/quarantine"
mkdir -p "$Q/zfreshquar"
out=$(DISK_AWARE=1 PRESSURE_CRIT_PCT=100 PRESSURE_CRIT_GB=999999 ABS_SIZE_FLOOR_MB=1 \
        "${NOTTY[@]}" "$SCRIPT" --apply </dev/null 2>&1)
{ [ ! -e "$Q/zfreshquar" ] && grep -q 'emptied the whole quarantine' <<<"$out"; } \
  && ok "a critical disk empties the whole quarantine, window or not" \
  || no "quarantine held disk hostage at the critical watermark"

# --- the ratchet: each rule against what that rule usually prunes --- A weekly cron whose plan
# doubles every month never touches a fixed cap, so the baseline is the audit logs the tool
# already writes. It is per rule so that one rule's wave holds back that rule alone.
build_fixture; assert_isolated
for i in 1 2 3 4; do past_run "$i" $USUAL_BUT_C; done
dry=$(RATCHET_FLOOR=0 "$SCRIPT" 2>&1)
grep -q 'HELD BACK unless --force' <<<"$dry" && grep -q '#     rule C: ' <<<"$dry" \
  && ! grep -q '#     rule A: ' <<<"$dry" \
  && ok "a dry run says which rule an unattended apply would hold back" \
  || no "the dry run did not name the rule the ratchet would hold"
out=$(RATCHET_FLOOR=0 "${NOTTY[@]}" "$SCRIPT" --apply </dev/null 2>&1); rc=$?
{ [ "$rc" = 4 ] && grep -q '^# HELD BACK rule C: ' <<<"$out" \
  && [ -e "$STORAGE/ztwoyr3" ] && [ ! -e "$STORAGE/zjunk1" ]; } \
  && ok "a rule far over its usual is held back while the rest of the plan is pruned" \
  || no "the ratchet held the wrong rules, or held the whole run (rc=$rc)"
grep -q '^# held back: rule C, ' "$AUDIT_DIR"/prune-2*Z.log 2>/dev/null \
  && ! grep -q $'^ztwoyr3\t' "$AUDIT_DIR"/prune-2*Z.log \
  && grep -q $'^C\t4\t0\t0$' "$AUDIT_DIR/last-run/held.tsv" \
  && ok "the audit log and last-run/held.tsv name the held rule, the plan in the log omits it" \
  || no "the audit log does not say what the ratchet held back"

build_fixture; assert_isolated
for i in 1 2 3 4; do past_run "$i" $USUAL_BUT_C; done
out=$(RATCHET_FLOOR=0 "${NOTTY[@]}" "$SCRIPT" --apply --force </dev/null 2>&1); rc=$?
{ [ "$rc" = 0 ] && [ ! -e "$STORAGE/ztwoyr3" ] && ! grep -q 'HELD BACK rule' <<<"$out"; } \
  && ok "--force still gets past the history ratchet" \
  || no "--force could not override the ratchet (rc=$rc)"

# The floor is what lets an ordinary week through when a rule's usual is 0.
build_fixture; assert_isolated
for i in 1 2 3 4; do past_run "$i" $USUAL_BUT_C; done
out=$("${NOTTY[@]}" "$SCRIPT" --apply </dev/null 2>&1); rc=$?
{ [ "$rc" = 0 ] && [ ! -e "$STORAGE/ztwoyr3" ]; } \
  && ok "a rule under RATCHET_FLOOR is never held, however small its usual" \
  || no "the ratchet held back a handful of repos from a rule that usually prunes none (rc=$rc)"

# Too little history is no baseline: two runs must not be treated as a norm to measure against.
build_fixture; assert_isolated
for i in 1 2; do past_run "$i" junk-name:1; done
out=$(RATCHET_FLOOR=0 "${NOTTY[@]}" "$SCRIPT" --apply </dev/null 2>&1); rc=$?
{ [ "$rc" = 0 ] && [ ! -e "$STORAGE/zjunk1" ] && [ ! -e "$STORAGE/ztwoyr3" ]; } \
  && ok "two past runs are not enough history to ratchet against" \
  || no "the ratchet fired on a baseline too thin to mean anything (rc=$rc)"

# A run that held a rule back pruned none of that rule because it was not allowed to, and a run
# with the rule switched off could not prune any, so neither is a sample of what the rule
# usually does. Counted as zeros, the three of each below would drag C's median of 4 down to 2.
build_fixture; assert_isolated
for i in 1 2 3; do past_run "$i" $REST stale:4; done
for i in 4 5 6; do past_run "$i" $REST held:C; done
for i in 7 8 9; do past_run "$i" $REST rules:ABDEFG; done
out=$(RATCHET_RUNS=9 RATCHET_FACTOR=1 RATCHET_FLOOR=0 "${NOTTY[@]}" "$SCRIPT" --apply \
        </dev/null 2>&1); rc=$?
{ [ "$rc" = 0 ] && [ ! -e "$STORAGE/ztwoyr3" ]; } \
  && ok "a run that held a rule, or ran without it, is no sample of what that rule prunes" \
  || no "held or switched-off runs dragged a rule's usual down to a hold (rc=$rc)"

# Two samples are no median: after six held weeks and one forced run, C's window holds that
# forced wave and one ordinary week, and three times their mean would wave the next wave through.
build_fixture; assert_isolated
for i in 1 2 3 4 5 6; do past_run "$i" $REST held:C; done
past_run 7 $REST stale:490
past_run 8 $REST stale:5
out=$(RATCHET_FLOOR=0 "${NOTTY[@]}" "$SCRIPT" --apply </dev/null 2>&1); rc=$?
{ [ "$rc" = 4 ] && [ -e "$STORAGE/ztwoyr3" ]; } \
  && ok "a rule with fewer than three samples of its own is held at the floor" \
  || no "one forced wave set a rule's limit for the next one (rc=$rc)"
# Any spelling of RULES that rule_on accepts is read back the same way from the log.
build_fixture; assert_isolated
for i in 1 2 3; do past_run "$i" $REST stale:4 rules:A,B,C,D,E,F; done
out=$(RATCHET_RUNS=3 RATCHET_FACTOR=1 RATCHET_FLOOR=0 "${NOTTY[@]}" "$SCRIPT" --apply \
        </dev/null 2>&1); rc=$?
{ [ "$rc" = 0 ] && [ ! -e "$STORAGE/ztwoyr3" ]; } \
  && ok "a rules list written with separators still counts every rule it names" \
  || no "a separated rules list dropped samples for the rules after its first (rc=$rc)"

# The caps are measured on what the ratchet leaves: the 36-repo plan is over a cap of 33, the
# 32 left once rule C's 4 are held are not, so the rest still goes ahead.
build_fixture; assert_isolated
for i in 1 2 3 4; do past_run "$i" $USUAL_BUT_C; done
out=$(MAX_PRUNE_COUNT=33 RATCHET_FLOOR=0 "${NOTTY[@]}" "$SCRIPT" --apply </dev/null 2>&1); rc=$?
{ [ "$rc" = 4 ] && [ -e "$STORAGE/ztwoyr3" ] && [ ! -e "$STORAGE/zjunk1" ]; } \
  && ok "a held wave does not trip the caps for the rest of the plan" \
  || no "the caps counted repos the ratchet had already held back (rc=$rc)"

# Rotated logs leave the ratchet with less to go on, said out loud since under three readable
# logs it holds nothing at all.
build_fixture; assert_isolated
for i in 1 2 3 4; do past_run "$i" $USUAL_BUT_C; done
rm "$AUDIT_DIR"/prune-20260103T000000Z.log "$AUDIT_DIR"/prune-20260104T000000Z.log
out=$(RATCHET_FLOOR=0 "$SCRIPT" 2>&1)
grep -q 'cannot read 2 of the 4 most recent audit logs' <<<"$out" \
  && ok "the ratchet says when the audit logs it measures against are gone" \
  || no "missing audit logs thinned the ratchet's baseline without a word"
out=$(RATCHET_FLOOR=twenty "$SCRIPT" 2>&1); rc=$?
{ [ "$rc" = 2 ] && grep -q 'RATCHET_FLOOR must be a whole number' <<<"$out"; } \
  && ok "a brake set to something other than a whole number stops the run" \
  || no "a mistyped brake was read as a number (rc=$rc)"

# --- a run that stops leaves the quarantine as it found it --- The stop is what makes a human
# look, and what they look at includes the last runs' verdicts, which only the quarantine has.
build_fixture; assert_isolated
Q="$AUDIT_DIR/quarantine"; mkdir -p "$Q/zexpired"; touch -d "30 days ago" "$Q/zexpired"
out=$(MAX_PRUNE_COUNT=1 "${NOTTY[@]}" "$SCRIPT" --apply </dev/null 2>&1); rc=$?
{ [ "$rc" = 3 ] && [ -d "$Q/zexpired" ]; } \
  && ok "a run the caps stop keeps what is in quarantine, expired or not" \
  || no "an aborted run purged the quarantine before stopping (rc=$rc)"
# A held rule's repos wait in storage, so holding them is no reason to keep the quarantine too.
for i in 1 2 3 4; do past_run "$i"; done
out=$(RATCHET_FLOOR=0 "${NOTTY[@]}" "$SCRIPT" --apply </dev/null 2>&1); rc=$?
{ [ "$rc" = 4 ] && [ ! -d "$Q/zexpired" ] && [ -e "$STORAGE/zjunk1" ] \
  && grep -q 'every verdict in the plan was held back' <<<"$out"; } \
  && ok "a run whose whole plan is held back prunes nothing, and still purges what expired" \
  || no "a fully held run pruned something, or kept the quarantine's expired disk (rc=$rc)"

# interactive prompt via a pty (needs util-linux `script`): n aborts, y applies.
if command -v script >/dev/null 2>&1; then
  build_fixture; assert_isolated
  b=$(ls "$STORAGE" | wc -l)
  Q="$AUDIT_DIR/quarantine"; mkdir -p "$Q/zexpired"; touch -d "30 days ago" "$Q/zexpired"
  printf 'n\n' | script -qec "env DISK_AWARE=0 ABS_SIZE_FLOOR_MB=1 '$SCRIPT' --apply" \
    /dev/null >"$ROOT/n.out" 2>&1
  a=$(ls "$STORAGE" | wc -l)
  { grep -q aborted "$ROOT/n.out" && [ "$b" = "$a" ] && [ -d "$Q/zexpired" ]; } \
    && ok "interactive --apply + n aborts, nothing deleted, nothing purged" \
    || no "interactive + n aborts"

  # The line a human answers has to say what the run really does. Under quarantine the disk
  # does not come back today, so a prompt promising to reclaim it is asking for a wrong yes.
  { grep -q 'quarantine' "$ROOT/n.out" && ! grep -q 'reclaiming' "$ROOT/n.out"; } \
    && ok "the confirmation prompt says quarantine, not reclaim, while quarantine is on" \
    || no "the apply prompt promised disk the quarantine is still holding"

  build_fixture; assert_isolated
  printf 'n\n' | script -qec \
    "env DISK_AWARE=0 ABS_SIZE_FLOOR_MB=1 QUARANTINE=0 '$SCRIPT' --apply" \
    /dev/null >"$ROOT/nq0.out" 2>&1
  grep -q 'DELETE.*reclaiming' "$ROOT/nq0.out" \
    && ok "QUARANTINE=0 puts the reclaim promise back in the prompt" \
    || no "the prompt hid the outright deletion QUARANTINE=0 was about to do"

  # A quarantine is a recovery copy, and at the critical watermark the run empties it whole
  # rather than wait out the window. That emptying used to happen before the human was asked
  # anything, so answering no destroyed every recovery copy in a run that pruned nothing.
  CRIT="env DISK_AWARE=1 PRESSURE_CRIT_PCT=100 PRESSURE_CRIT_GB=999999 ABS_SIZE_FLOOR_MB=1"
  build_fixture; assert_isolated
  Q="$RSP_HOME/prune-audit/quarantine"; mkdir -p "$Q/zkeepme"
  printf 'n\n' | script -qec "$CRIT '$SCRIPT' --apply" /dev/null >"$ROOT/ncrit.out" 2>&1
  { grep -q aborted "$ROOT/ncrit.out" && [ -d "$Q/zkeepme" ]; } \
    && ok "answering no leaves the quarantine standing, critical watermark or not" \
    || no "an aborted run had already emptied the whole quarantine before asking"

  # And the other direction, so the check above cannot pass by the wipe never happening.
  build_fixture; assert_isolated
  Q="$RSP_HOME/prune-audit/quarantine"; mkdir -p "$Q/zkeepme"
  printf 'y\n' | script -qec "$CRIT '$SCRIPT' --apply" /dev/null >"$ROOT/ycrit.out" 2>&1
  { grep -q 'critical watermark' "$ROOT/ycrit.out" && [ ! -e "$Q/zkeepme" ]; } \
    && ok "answering yes at the critical watermark still empties the whole quarantine" \
    || no "the critical watermark left the quarantine holding disk the run needed"

  # Rule C would be held back unattended, and a yes is a human signing off on that too.
  build_fixture; assert_isolated
  for i in 1 2 3 4; do past_run "$i" $USUAL_BUT_C; done
  printf 'y\n' | script -qec \
    "env DISK_AWARE=0 ABS_SIZE_FLOOR_MB=1 RATCHET_FLOOR=0 '$SCRIPT' --apply" \
    /dev/null >"$ROOT/y.out" 2>&1
  gone=1; for r in zjunk1 zbig2 ztwoyr3 zbar8; do [ -e "$STORAGE/$r" ] && gone=0; done
  [ "$gone" = 1 ] \
    && ok "interactive --apply + y prunes the plan, rules the ratchet would hold included" \
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

# A phase that reads every repo runs for minutes on a real seed, and a terminal that says
# nothing looks the same whether the walk is slow or hung, so operators kill runs that were
# working. The shim makes rule E's walk outlast a tick on any machine.
build_fixture; assert_isolated
shimdir="$ROOT/shim"; mkdir -p "$shimdir"
cp "$HERE/slow-git-shim" "$shimdir/git"; chmod +x "$shimdir/git"
slow=(env "PATH=$shimdir:$PATH" DISK_AWARE=0 CACHE=0 JOBS=1 RULES=E)
out=$("${slow[@]}" PROGRESS_SECS=1 "$SCRIPT" 2>&1)
grep -qE '^#   \[[0-9]+/[0-9]+\] rule E: [0-9]+ of [0-9]+ repos \([0-9]+%\), [0-9]' <<<"$out" \
  && ok "a slow walk says how many repos it has read and how long is left" \
  || no "rule E printed no progress during a walk long enough to need it"

# What a phase cost is the number an operator tuning JOBS or RULES reaches for, and on a
# terminal it is the only trace the redrawn line leaves behind.
grep -qE "^# rule E: $NREPOS repos in [0-9]" <<<"$out" \
  && ok "a finished phase says how many repos it read and how long it took" \
  || no "rule E never reported what the phase cost"

# The same run with the reporting off, so the two checks above cannot pass on a line that some
# other part of the script prints anyway.
out=$("${slow[@]}" PROGRESS_SECS=0 "$SCRIPT" 2>&1)
{ grep -qE '^#   \[[0-9]+/[0-9]+\] rule E:' <<<"$out" \
    || grep -qE "^# rule E: $NREPOS repos in " <<<"$out"; } \
  && no "PROGRESS_SECS=0 reported progress anyway" \
  || ok "PROGRESS_SECS=0 prints no progress at all"

# On a terminal the reading is redrawn in place instead, so a run that takes minutes never
# scrolls its own output away, and the line is wiped when the phase ends rather than left
# frozen at whatever it last read.
if command -v script >/dev/null 2>&1; then
  script -qec "env 'PATH=$shimdir:$PATH' DISK_AWARE=0 CACHE=0 JOBS=1 RULES=E '$SCRIPT'" \
    /dev/null >"$ROOT/tty.out" 2>&1
  { grep -qE $'\r''.*\[=* *\] +[0-9]+%' "$ROOT/tty.out" \
      && ! grep -qE '^#   \[[0-9]+/[0-9]+\] rule E:' "$ROOT/tty.out"; } \
    && ok "a terminal gets one line redrawn in place, not a line per tick" \
    || no "the terminal progress line was not drawn, or the log form was used instead"
else
  skip "terminal progress line (no util-linux 'script' for a pty)"
fi

# The ticker is a background process holding the run's own stderr. One left behind keeps
# printing into a terminal whose run has ended, so the phase that started it stops it. It is
# caught by watching whether the run's stderr keeps growing after the run has exited.
tickerlog="$ROOT/ticker.err"
"${slow[@]}" PROGRESS_SECS=1 "$SCRIPT" >/dev/null 2>"$tickerlog"
settled=$(wc -c < "$tickerlog"); sleep 2; grown=$(wc -c < "$tickerlog")
[ "$settled" = "$grown" ] \
  && ok "a finished run leaves no ticker printing behind it" \
  || no "a ticker outlived the run and kept writing to its stderr"

# The output of a run has to end when the run does. The ticker waits between readings in a
# child process of its own, which inherits the run's stdout and stderr, so one left behind
# holds the pipe open and `rad prune | anything` waits out the whole interval after the plan
# is already printed. Read through a pipe here, since a file cannot show the difference.
started=$SECONDS
DISK_AWARE=0 PROGRESS_SECS=60 "${NOTTY[@]}" "$SCRIPT" </dev/null 2>&1 | cat >/dev/null
took=$(( SECONDS - started ))
[ "$took" -lt 30 ] \
  && ok "the output of a run ends when the run does" \
  || no "reading the run's output waited ${took}s for something left behind"

# Rule E reads every repo it flagged a second time, to see whose links they are. That walk is
# as slow as the harvest that fed it, it is the one walk a run can skip entirely, and it
# counts flagged repos rather than storage, so it reports on its own terms.
build_fixture; assert_isolated
shimdir="$ROOT/shim"; mkdir -p "$shimdir"
cp "$HERE/slow-rad-shim" "$shimdir/rad"; chmod +x "$shimdir/rad"
flagged=(env RSP_REAL_RAD="$RAD" RAD="$shimdir/rad" LINK_MIN_REPOS=3 LINK_MIN_SCORE=2 \
         DISK_AWARE=0 CACHE=0 RULES=E)
out=$("${flagged[@]}" PROGRESS_SECS=1 "$SCRIPT" 2>&1)
nflagged=$(grep -oE '^# re-reading [0-9]+ flagged' <<<"$out" | grep -oE '[0-9]+' || true)
{ [ -n "$nflagged" ] && [ "$nflagged" -gt 0 ] && [ "$nflagged" -lt "$NREPOS" ]; } \
  && ok "the delegate re-check says how many flagged repos it is about to read" \
  || no "the delegate re-check started without saying what it was reading"

# A count that never moves is what a missing per-repo marker looks like, and it reads as a
# hung walk, which is the thing this reporting exists to rule out.
grep -qE "^#   \[[0-9]+/[0-9]+\] delegates: [1-9][0-9]* of $nflagged repos" <<<"$out" \
  && ok "the delegate re-check counts up as it finishes repos" \
  || no "the delegate re-check never counted a repo it had finished"
grep -qE "^# delegates: $nflagged repos in [0-9]" <<<"$out" \
  && ok "the delegate re-check reports what it cost, over its own repos" \
  || no "the delegate re-check never reported what it cost"

# Nothing flagged means no second walk, and a phase that did not happen may not report itself.
out=$("${flagged[@]/LINK_MIN_SCORE=2/LINK_MIN_SCORE=99}" PROGRESS_SECS=1 "$SCRIPT" 2>&1)
{ grep -q '^# re-reading' <<<"$out" || grep -q '^# delegates: ' <<<"$out"; } \
  && no "a run that flagged nothing reported a delegate walk anyway" \
  || ok "a run with nothing to re-check reports no delegate walk"

# ---- end of sections -------------------------------------------------------
summary
