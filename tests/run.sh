#!/usr/bin/env bash
#
# Test suite for radicle-seed-prune. Builds a throwaway Radicle home (a fake `rad` on PATH,
# real bare git repos with set dates and sizes) and runs the real script against it.
#
#   tests/run.sh                 everything, in order, in one process
#   tests/run.sh -k quarantine   only the sections that mention "quarantine"
#   tests/run.sh -n 7            only the 7th section, in a process of its own
#   tests/run.sh -e              every section, each in a process of its own
#
# A section runs from one fixture rebuild to the next and must set up everything it reads,
# because it is also run on its own.
#
set -uo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
SCRIPT="$HERE/../rad-prune"
PASS=0; FAIL=0
ok(){ PASS=$((PASS+1)); printf 'ok   - %s\n' "$1"; }
no(){ FAIL=$((FAIL+1)); printf 'FAIL - %s\n' "$1"; }
# This machine cannot run the check. Printed, so a check skipped for good stays visible.
skip(){ printf 'skip - %s\n' "$1"; }
# true when plan text $1 holds a row for rid $2
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
zmediacob\tissueclip\t2\tpublic\t0\t60\t100\ta clip in the delegate own issue
zmediapast\toldattach\t2\tpublic\t0\t60\t100\ta clip in an older comment
zmediazip\tzippedclip\t2\tpublic\t0\t60\t100\tone archive
zbatch1\tgallery\t2\tpublic\t0\t60\t100\tholiday pictures
zbatch2\talbum\t2\tpublic\t0\t60\t100\tsome things I made
zbatch3\treel\t2\tpublic\t0\t60\t100\tstuff
zbatch4\tmontage\t2\tpublic\t0\t60\t100\ta few videos
zbatch5\tclipset\t2\tpublic\t0\t60\t100\tmy own dump
zbatchodd\tsolocam\t2\tpublic\t0\t60\t100\tone of a kind
zbatchbig\tlongbatch\t2\tpublic\t0\t60\t100\tthe batch clip in a documented project
zmediagz\tcsvdata\t2\tpublic\t0\t60\t100\tcompressed data
zmediagzv\tgzclip\t2\tpublic\t0\t60\t100\ta compressed clip named like data
zmediahost\tseed.example.org\t2\tpublic\t0\t60\t100\ta seed logo
zmediahostbig\tseed.example.net\t2\tpublic\t0\t60\t100\ta clip under a hostname
zmediapng\twallpapers.png\t2\tpublic\t0\t60\t100\ta dump named like a file
zmediagzt\tgznotes\t2\tpublic\t0\t60\t100\ta compressed tar named like notes
zmediagzu\tutfnotes\t2\tpublic\t0\t60\t100\tcompressed UTF-16 notes
zmediagzw\tutfnotes32\t2\tpublic\t0\t60\t100\tcompressed UTF-32 notes
zmediagzb\tutfnotesbe\t2\tpublic\t0\t60\t100\tcompressed UTF-16BE notes
zmediapkg\treleasezip\t2\tpublic\t0\t60\t100\ta big clip, a release archive and a readme
zmediamake\tmakeclip\t2\tpublic\t0\t60\t100\ta clip beside a makefile
zmediasrc\tsrcclip\t2\tpublic\t0\t60\t100\ta clip beside a script
zmediaratio\tbigclip\t2\tpublic\t0\t60\t100\ta big clip and a readme
zmediaratio3\tbigclipdoc\t2\tpublic\t0\t60\t100\ta big clip and a licence
zmediaratio4\tbigclipdocs\t2\tpublic\t0\t60\t100\ta big clip and two readmes
zmediaratio7\tbigclipnotes\t2\tpublic\t0\t60\t100\ta big clip and a long readme
zmediahtm\tbigclippage\t2\tpublic\t0\t60\t100\ta big clip and a readme page
zmediapkg2\treleasebin\t2\tpublic\t0\t60\t100\ta big clip, a renamed release and a readme
zmediacobr\tclipissues\t2\tpublic\t0\t60\t100\ta readme, and a big clip in its issues
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

# Rule D judges whole batches. Each batch is 9 repos of one age, size and name skeleton, and
# each differs from zspam in one variable, so a failure names its own cause.
#   zspam*   name has a random-id slot AND all 9 share one description template  -> pruned
#   zdecoy*  same name shape, but every repo carries its OWN real description    -> kept
#   zenum*   descriptions agree, but the slot is an enumeration, by default no id -> kept
#   znodesc* random-id slot, but no descriptions at all, so only ONE signal      -> kept
#   zdate*   descriptions agree, but a 6+ digit slot with no letter is a date    -> kept
# 90 days old: too young for rules A and C, too small for B, so any hit is rule D's.
build_batches(){
  local i rows=""
  local hex=(- 33ed7115 6cf239e8 28036e03 1d9ce82f e9a0b26f
             df68129a 944f76e9 283bed8c 9e1437e9)
  # a mirror farm's descriptions differ in words, as real ones do, not only in a number
  local word=(- gyroscope barometer thermometer altimeter magnetometer
               hygrometer photodiode tachometer voltmeter)
  # rids start at 1: 0 is not base58, so a "zspam0" would be rejected as malformed.
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
  # refs one day old: too young for rule D on ref dates, so only the ledger's date reaches it
  rows+="zspamaged\tflatten-13-8f2a4d61\t5\tpublic\t0\t1\t2000"
  rows+="\tFlatten a nested array. Variant 13.\n"
  printf '%b' "$rows"
}
MANIFEST_ROWS="$MANIFEST_ROWS"$'\n'"$(build_batches)"
NREPOS=130

# A peer that pushes into zmediapeer and zvictimten without being a delegate of either.
STRANGER_NID=zSTRANGERxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
# Rule F counts an op only once its author's ed25519 signature over the op's tree id checks
# out, so repos whose delegates write ops get a throwaway key and the node id it spells.
COB_KEY=$HERE/fixtures/throwaway-test-key.pem
COB_NID=z6Mkei8KLNDCqpfdk9KbvUNQJ4YrTep1EWMJqjTsKWw1pR4X
# The node id this fixture hands out as a delegate of $1. It has to survive the script's base58
# filter, so the rid's own characters are mapped into the alphabet and the rest is padding.
dlg(){
  case $1 in
    zmediacob|zmediapast|zmediamirr|zmediacobm|zmediapeer|zmediacobr) printf '%s' "$COB_NID"; return ;;
  esac
  local n="zDLG$1"
  printf '%s' "$n"
  local i=${#n}; while [ "$i" -lt 45 ]; do printf x; i=$((i+1)); done
}
# Re-signs commit $1 of $GIT_DIR as a Radicle op: ed25519 over the 20-byte tree id, an SSH
# signature under "gpgsig", the node id as email. Prints the new commit id. $2 and $3
# sign with another key and its node id.
hex(){ od -An -tx1 -v | tr -d ' \n'; }
u32(){ printf '%08x' "$1"; }
sshstr(){ local h; h=$(printf '%s' "$1" | hex); printf '%s%s' "$(u32 $(( ${#h} / 2 )))" "$h"; }
sign_op(){
  local c=$1 keyfile=${2:-$COB_KEY} nid=${3:-$COB_NID} w tree pub sig kblob sblob blob
  w=$(mktemp -d -p "$ROOT")
  tree=$(git rev-parse "$c^{tree}")
  printf '%s' "$tree" | sed 's/../\\x&/g' | xargs -0 printf > "$w/msg"
  openssl pkeyutl -sign -inkey "$keyfile" -rawin -in "$w/msg" -out "$w/sig"
  pub=$(openssl pkey -in "$keyfile" -pubout -outform DER | hex); pub=${pub:24}
  sig=$(hex < "$w/sig")
  kblob="$(sshstr ssh-ed25519)$(u32 32)$pub"; sblob="$(sshstr ssh-ed25519)$(u32 64)$sig"
  blob="$(printf SSHSIG | hex)$(u32 1)$(u32 $(( ${#kblob} / 2 )))$kblob$(sshstr radicle)"
  blob="$blob$(u32 0)$(sshstr sha256)$(u32 $(( ${#sblob} / 2 )))$sblob"
  { git cat-file commit "$c" | sed -n '/^$/q; s/ <[^>]*> / <op@'"$nid"'> /; p'
    echo "gpgsig -----BEGIN SSH SIGNATURE-----"
    printf '%s' "$blob" | sed 's/../\\x&/g' | xargs -0 printf | base64 -w 70 | sed 's/^/ /'
    echo " -----END SSH SIGNATURE-----"
    git cat-file commit "$c" | sed '1,/^$/d' | sed '1i\\'
  } > "$w/commit"
  git hash-object -t commit -w "$w/commit"
  rm -rf "$w"
}
# Prints the hex bytes $1 in base58, a "1" for each leading zero byte.
base58(){
  awk -v h="$1" 'BEGIN {
    a = "123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz"; x = "0123456789abcdef"
    for (i = 1; i < length(h); i += 2) {
      c = (index(x, substr(h, i, 1)) - 1) * 16 + index(x, substr(h, i + 1, 1)) - 1
      if (c == 0 && n == 0) { zeros = zeros "1"; continue }
      for (j = 0; j < n; j++) { c += b[j] * 256; b[j] = c % 58; c = int(c / 58) }
      while (c > 0) { b[n++] = c % 58; c = int(c / 58) }
    }
    printf "%s", zeros
    for (j = n - 1; j >= 0; j--) printf "%s", substr(a, b[j] + 1, 1) }'
}
# Makes a throwaway ed25519 key at $ROOT/keys/<node id>.pem and prints the node id it spells:
# "z", then base58 of the bytes ed 01 followed by the public key.
new_key(){
  local pem pub nid
  mkdir -p "$ROOT/keys"; pem=$(mktemp -p "$ROOT/keys")
  openssl genpkey -algorithm ed25519 -out "$pem" 2>/dev/null
  pub=$(openssl pkey -in "$pem" -pubout -outform DER | hex); pub=${pub:24}
  nid=z$(base58 "ed01$pub")
  mv "$pem" "$ROOT/keys/$nid.pem"
  printf '%s' "$nid"
}
# Prints a tree that names one subtree twice, and that one the next twice, $2 levels down:
# 2^$2 paths from $2 small trees, written into git dir $1. Each name is $3 bytes long.
bomb_tree(){
  local t mode=100644 kind=blob i pad
  pad=$(printf "%$(( ${3:-1} - 1 ))s" '' | tr ' ' x)
  t=$(printf '' | GIT_DIR="$1" git hash-object -w --stdin)
  for ((i = 0; i < $2; i++)); do
    t=$(printf '%s %s %s\ta%s\n%s %s %s\tb%s\n' "$mode" "$kind" "$t" "$pad" \
               "$mode" "$kind" "$t" "$pad" | GIT_DIR="$1" git mktree)
    mode=040000; kind=tree
  done
  printf '%s\n' "$t"
}
# Replaces one ref of $rid with a tree of exactly the given "name:bytes" files. Random bytes
# keep sizes exact. The force-push leaves the manifest loop's commit unreachable, so a
# rule F reading the object store instead of the tree would reach another verdict.
e_tree(){
  local rid=$1 days=$2 ref=$3; shift 3
  local w spec; w=$(mktemp -d -p "$ROOT")
  git -C "$w" init -q -b master
  git -C "$w" config user.email a@b; git -C "$w" config user.name a
  # Builds on what the ref holds, so a second call adds a commit as a COB gains an op. Each
  # call lists the whole tree; files left out stay only in history.
  if GIT_DIR="$STORAGE/$rid" git rev-parse --verify -q "$ref" >/dev/null 2>&1; then
    git -C "$w" fetch -q "$STORAGE/$rid" "$ref" && git -C "$w" reset -q --hard FETCH_HEAD
    find "$w" -maxdepth 1 -type f -delete
  fi
  # "name:bytes" is random filler; a kind suffix writes a real file header for the content
  # sniff to recognise. "same" pads with zeros, so two repos given it hold one blob.
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
      # An MPEG transport stream opening on the SDT packet, as ffmpeg and OBS write one.
      ts)   printf '\107\100\021\020' > "$w/$name"
            head -c "$((bytes-4))" /dev/urandom >> "$w/$name" ;;
      zip)  printf 'PK\3\4' > "$w/$name"
            head -c "$((bytes-4))" /dev/urandom >> "$w/$name" ;;
      zip0) printf 'PK\3\4' > "$w/$name"
            head -c "$((bytes-4))" /dev/zero >> "$w/$name" ;;
      # gzip output a little bigger than "bytes": text in one, a video in the other.
      gztext) head -c "$bytes" /dev/urandom | base64 | gzip -c > "$w/$name" ;;
      gzmp4)  { printf '\0\0\0\40ftypisom'; head -c "$((bytes-12))" /dev/urandom; } \
                | gzip -c > "$w/$name" ;;
      # A tar's first 512 bytes are a header: a file name, then NUL padding.
      gztar)  { printf 'clip.mp4'; head -c 504 /dev/zero
                head -c "$((bytes-512))" /dev/urandom; } | gzip -c > "$w/$name" ;;
      # Text full of NUL bytes, opening with the byte-order mark that says what it is.
      gzu16)  head -c "$bytes" /dev/urandom | base64 | iconv -f ascii -t UTF-16LE \
                | { printf '\377\376'; cat; } | gzip -c > "$w/$name" ;;
      gzu16be) head -c "$bytes" /dev/urandom | base64 | iconv -f ascii -t UTF-16BE \
                | { printf '\376\377'; cat; } | gzip -c > "$w/$name" ;;
      gzu32)  head -c "$bytes" /dev/urandom | base64 | iconv -f ascii -t UTF-32BE \
                | { printf '\0\0\376\377'; cat; } | gzip -c > "$w/$name" ;;
      *)    head -c "$bytes" /dev/urandom > "$w/$name" ;;
    esac
  done
  git -C "$w" add -A
  local ts; ts=$(date -u -d "$days days ago" +%s)
  GIT_AUTHOR_DATE="@$ts +0000" GIT_COMMITTER_DATE="@$ts +0000" git -C "$w" commit -q -m m
  local tip=master
  case $ref in
    refs/namespaces/$COB_NID/refs/cobs/*) tip=$(GIT_DIR="$w/.git" sign_op HEAD) ;;
  esac
  git -C "$w" push -q --force "$STORAGE/$rid" "$tip:$ref"
  rm -rf "$w"
  touch -d "10 days ago" "$STORAGE/$rid"
}

# The fixture costs about 700 git calls, so it is built once as a template and each section
# restores a copy of it (a few MB, a reflink where the filesystem has them).
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
  # Clear the last test's ROOT, unreadable dirs included, or the next fixture is its
  # leftovers. ROOT is reused for the whole process, so failing to clear it aborts.
  if [ -e "$ROOT" ]; then
    chmod -R u+rwX "$ROOT" 2>/dev/null
    rm -rf "$ROOT"
    [ -e "$ROOT" ] && { echo "ABORT: could not clear the fixture at $ROOT"; exit 3; }
  fi
  mkdir -p "$ROOT"
  cp -a --reflink=auto "$TEMPLATE/." "$ROOT/"
}

# Building takes about 18s, most of what one section costs. The template is kept under
# TMPDIR, keyed by this file's header and the rad stub, so editing a test reuses it. Its
# dates are relative to build time, so it expires after an hour, before they drift past
# the thresholds tests sit near. RSP_FIXTURE_CACHE=0 turns it off.
cached_template(){
  local key dir staging old
  key=$( { sed -n '1,/^# ---- end of header/p' "$0"; cat "$HERE/rad-stub"; } \
         | sha1sum | cut -c1-12 )
  dir="${TMPDIR:-/tmp}/rsp-fixture-$(id -u)-$key"      # never another user's, on a shared /tmp
  if [ -d "$dir" ] && [ -z "$(find "$dir" -maxdepth 0 -mmin +60)" ]; then
    printf '%s\n' "$dir"; return 0
  fi
  _build_fixture >&2
  # Filled beside the target and renamed onto it, so a concurrent suite sees the old or the
  # new template, never half. The old one is renamed away first: `rm -rf` in place leaves
  # a window where a copy gets no storage, which fails as unrelated tests.
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
  # The key changes with the fixture, so older templates are dead weight.
  find "${TMPDIR:-/tmp}" -maxdepth 1 -name "rsp-fixture-$(id -u)-*" -type d -mtime +0 \
    -exec rm -rf {} + 2>/dev/null
  printf '%s\n' "$dir"
}

# Paths and inputs for the script under test. Apart from building, because a process that
# restores the template needs them too.
_fixture_env(){
  # Debian seeds run mawk, which ignores {n} interval regexes and prints integers over 2^31
  # as %.6g. Test under it where present, or awk that only works under gawk ships green.
  AWKBIN=${AWK:-$(command -v mawk || command -v awk)}
  export PATH="$ROOT/bin:$PATH"

  export RSP_HOME="$ROOT/rad-home"
  export RSP_NID="z6MkourNodexxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
  export RSP_MANIFEST="$ROOT/manifest.tsv"

  # ISOLATION: pin every input the script reads, so a test never touches the real Radicle home
  # even if the caller exported RAD_HOME and the rest. STORAGE confines every deletion to
  # the temp dir (the script only rm's paths under "$STORAGE"/z*).
  export RAD="$ROOT/bin/rad"
  export RAD_HOME="$RSP_HOME"
  export STORAGE="$RSP_HOME/storage"
  export CONFIG="$RSP_HOME/config.json"
  export AUDIT_DIR="$RSP_HOME/prune-audit"
  unset OUR_NID   # read from the stub's `rad self --did`, so that path runs in every test
  export SERVICE="rsp-test-does-not-exist.service"
  # Some shells and CI runners export FORCE_COLOR; a test that wants colour asks for it.
  unset FORCE_COLOR NO_COLOR
  # Ignore global and system git config, so fixture commits never use the user's signing key
  # or identity.
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

  mkdir -p "$STORAGE"
  printf '{ "web": { "pinned": { "repositories": ["rad:zpin6"] } } }\n' > "$CONFIG"

  while IFS=$'\t' read -r rid name _seeds vis own days size desc; do
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
    # refs/rad/id holds the identity document (embeds/radicle.json) that names the delegates.
    # Only the local node writes it, so a stranger's push cannot move it. Committed at the
    # repo's own date to leave its activity clocks alone. zmediapeer's description names the
    # stranger by did:key, which does not make them a delegate.
    w=$(mktemp -d -p "$ROOT")
    git -C "$w" -c init.defaultBranch=master init -q
    git -C "$w" config user.email a@b; git -C "$w" config user.name a
    local iddesc=$desc
    [ "$rid" = zmediapeer ] && iddesc="$desc, thanks did:key:$STRANGER_NID"
    mkdir -p "$w/embeds"
    local idvis=""; [ "$vis" = private ] && idvis=',"visibility":{"type":"private"}'
    printf '{"delegates":["did:key:%s"],"payload":{"xyz.radicle.project":%s},"threshold":1%s}\n' \
           "$(dlg "$rid")" \
           "{\"defaultBranch\":\"master\",\"description\":\"$iddesc\",\"name\":\"$name\"}" \
           "$idvis" > "$w/embeds/radicle.json"
    git -C "$w" add -A
    GIT_AUTHOR_DATE="@$ts +0000" GIT_COMMITTER_DATE="@$ts +0000" git -C "$w" commit -q -m id
    git -C "$w" push -q "$d" master:refs/rad/id 2>/dev/null
    rm -rf "$w"
    # A repo is ours when this node has signed refs in it, as rad ls decides.
    [ "$own" = 1 ] && GIT_DIR="$d" git update-ref "refs/namespaces/$RSP_NID/refs/rad/sigrefs" \
                        "$(GIT_DIR="$d" git rev-parse refs/rad/id)"
    touch -d "10 days ago" "$d"        # keep every dir out of the freshness guard
  done < "$RSP_MANIFEST"

  # zspamfresh: a 90-day-old root plus a COB from yesterday, as real spam looks. Only a rule
  # D that clocks creation, not last activity, prunes it.
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

  # zspamaged's refs are a day old, but the ledger saw it 400 days ago, the date rule D uses.
  mkdir -p "$AUDIT_DIR"
  printf 'zspamaged\t%s\n' "$(date -u -d "400 days ago" +%s)" > "$AUDIT_DIR/first-seen.tsv"
  # The batch member seen first is spared as the original. zspam9 is seen the same day, so
  # zspamaged is not that lone first member and stays prunable.
  printf 'zspam9\t%s\n' "$(date -u -d "400 days ago" +%s)" >> "$AUDIT_DIR/first-seen.tsv"
  # A crash mid-write leaves a torn ledger line.
  printf 'zfresh4\tnot-a-date\n' >> "$AUDIT_DIR/first-seen.tsv"
  # zbatch3 published the shared clip first, so the batch path has to leave it alone.
  printf 'zbatch3\t%s\n' "$(date -u -d "400 days ago" +%s)" >> "$AUDIT_DIR/first-seen.tsv"

  touch "$STORAGE/zinfetch"        # a fetch landing right now: inside the freshness guard

  # Rule F fixtures. Each replaces the manifest loop's tree. The suite runs with
  # MEDIA_MIN_BYTES=20000 to stay fast; sizes straddle that and MEDIA_TEXT_MAX_BYTES (2048),
  # and each repo differs from zmediaone in ONE thing.
  e_tree zmediaone   60 master "clip.mp4:40000"                 # media only          -> pruned
  e_tree zmediatwo   60 master "clip.mp4:40000" "README.md:8192" # a real README       -> kept
  e_tree zmediabin   60 master "payload.bin:40000:mp4"          # a video renamed     -> pruned
  e_tree zmediaraw   60 master "payload.bin:40000"               # unknown, and really -> kept
  e_tree zmediamd    60 master "notes.md:400000:mp4"            # a video called .md  -> pruned
  e_tree zmediatiny  60 master "thumb.png:10000"                 # under the byte bar  -> kept
  # A repo is young only if every ref is, identity included, so zmediafresh also has a 5-day
  # manifest row.
  e_tree zmediafresh  5 master "clip.mp4:40000"                  # too young           -> kept
  e_tree zmediazero  60 master "clip.mp4:40000"                  # no other seeds      -> kept
  # The same clip in a namespace twice. zmediacob's is the delegate's own issue. zmediapeer's
  # is a stranger's, and counting it would let anyone get a near-empty repo deleted by
  # pushing it a video. Both branches hold 100 bytes of text, so whose namespace it is, is
  # the ONLY difference.
  e_tree zmediacob   60 master "notes.txt:100"
  e_tree zmediacob   60 "refs/namespaces/$(dlg zmediacob)/refs/cobs/xyz.radicle.issue/aaa" \
                        "clip.mp4:40000"
  e_tree zmediazip   60 master "payload.dat:40000:zip"          # a zip of something  -> pruned
  # An attachment in an earlier op. The COB's tip holds only the later reply, so reading the
  # tip alone sees no media.
  local past
  past=refs/namespaces/$(dlg zmediapast)/refs/cobs/xyz.radicle.issue/ccc
  e_tree zmediapast  60 master   "notes.txt:100"
  e_tree zmediapast  60 "$past"  "clip.mp4:40000"
  e_tree zmediapast  60 "$past"  "reply.txt:50"
  # The batch path: five repos publish the SAME clip behind a README too big for the
  # single-repo budget. zbatchodd has the same README over its own clip, so sharing the
  # file is the only difference.
  e_tree zbatch1     60 master "clip.mp4:40000:same" "README.md:4096"
  e_tree zbatch2     60 master "clip.mp4:40000:same" "README.md:4096"
  e_tree zbatch3     60 master "clip.mp4:40000:same" "README.md:4096"
  e_tree zbatch4     60 master "clip.mp4:40000:same" "README.md:4096" "run.sh:40"
  e_tree zbatch5     60 master "clip.mp4:40000:same" "README.md:4096" "Makefile:10"
  e_tree zbatchodd   60 master "clip.mp4:40000:mp4"  "README.md:4096"
  # The same clip behind a README that clears every budget. The clip sorts first, so a listing
  # that stops at too much text has seen it; it still must not count as a holder.
  e_tree zbatchbig   60 master "Aclip.mp4:40000:same" "README.md:70000"
  # Shapes of a real seed's false positives, each differing from zmediaone in ONE thing.
  e_tree zmediagz    60 master "rows.csv.gz:40000:gztext"       # data, compressed    -> kept
  e_tree zmediagzv   60 master "rows.csv.gz:40000:gzmp4"        # a video, compressed -> pruned
  e_tree zmediahost  60 master "logo.png:40000"                 # a hostname for name -> kept
  e_tree zmediahostbig 60 master "clip.mp4:1100000:same"        # more than a logo    -> pruned
  e_tree zmediapng   60 master "logo.png:40000"                 # named like a file   -> pruned
  e_tree zmediagzt   60 master "notes.txt.gz:40000:gztar"       # a tar, compressed   -> pruned
  e_tree zmediagzu   60 master "notes.txt.gz:40000:gzu16"       # UTF-16, compressed  -> kept
  e_tree zmediagzw   60 master "notes.txt.gz:40000:gzu32"       # UTF-32, compressed  -> kept
  e_tree zmediagzb   60 master "notes.txt.gz:40000:gzu16be"     # UTF-16BE, compressed -> kept
  # The Makefile is empty, so it holds the very same blob as Blank.png, which git lists first.
  e_tree zmediamake  60 master "Blank.png:0" "clip.mp4:40000" "Makefile:0"    # -> kept
  # A name with a non-ASCII byte, which git quotes unless told not to.
  e_tree zmediasrc   60 master "clip.mp4:40000" "café/main.py:50"   # a source file    -> kept
  # The ratio path: a README too big for the dump budget but tiny beside the clip. Zero-filled
  # clips stay small on disk, and each size is unique, so no other repo holds the same
  # blob.
  e_tree zmediaratio  60 master "clip.mp4:6400001:same" "README.md:3000"            # -> pruned
  e_tree zmediaratio  60 refs/heads/dev "README.md:3100"            # the same README, edited
  e_tree zmediaratio3 60 master "clip.mp4:6400003:same" "LICENSE:3000"              # -> kept
  e_tree zmediaratio4 60 master "clip.mp4:6400013:same" "README.md:1500" "docs/README.md:1500"
  e_tree zmediaratio7 60 master "clip.mp4:6400007:same" "README.md:7000"            # -> kept
  e_tree zmediahtm    60 master "clip.mp4:6400019:same" "README.html:3000"          # -> kept
  e_tree zmediapkg    60 master "clip.mp4:6400005:same" "rel.zip:70000:zip0" "README.md:3000"
  e_tree zmediapkg2   60 master "clip.mp4:6400017:same" "rel.bin:70000:zip0" "README.md:3000"
  e_tree zmediacobr   60 master "README.md:3000"
  e_tree zmediacobr   60 "refs/namespaces/$(dlg zmediacobr)/refs/cobs/xyz.radicle.issue/aaa" \
                        "clip.mp4:6400015:same"
  # A file named a lone "[" is not a valid regex, so a regex name match dies on it. A README
  # between the two text budgets is only looked past when the guard uses the wider one.
  e_tree zmediabrk    60 master "clip.mp4:40000:mp4" "[:20"
  # A COB op is a tree of files named 0, 1, ... beside a "manifest". They count as text
  # unopened, so a 4 KB one blows the budget despite a video header. That is the price of
  # not opening the millions a seed carries.
  e_tree zmediaop     60 master "clip.mp4:40000:mp4" "0:4096:mp4"
  e_tree zmediaman    60 master "clip.mp4:40000:mp4" "manifest:4096:mp4"
  # A path may hold spaces, so a classifier reading the line's last word sees "0" here and
  # waves the file through as a COB op payload.
  e_tree zmediaspc    60 master "clip.mp4:40000:mp4" "notes 0:4096:mp4"
  # Every other fixture repo has two refs, so a cap of 2 singles this one out.
  e_tree zmediarefs   60 master "clip.mp4:40000:mp4"
  e_tree zmediarefs   60 extra  "other.mp4:40000:mp4"
  e_tree zmediawide   60 master "payload.dat:40000:mp4" "README.md:70000"
  # The docs/ subtree is deleted after the push, so the walk sees the clip, then fails before
  # the README that would spare the repo. A short list must not read as a repo holding less.
  e_tree zmediatorn   60 master "clip.mp4:40000:mp4" "docs/README.md:4096"
  torn_tree=$(GIT_DIR="$STORAGE/zmediatorn" git rev-parse 'master^{tree}:docs')
  rm -f "$STORAGE/zmediatorn/objects/${torn_tree:0:2}/${torn_tree:2}"
  # The README alone exceeds every text budget, so the walk can stop there. The rest is
  # unreadable as in zmediatorn: reading on reports the repo unjudged, stopping does not.
  e_tree zmediacut    60 master "README.md:70000" "clip.mp4:40000:mp4" "docs/note.md:4096"
  cut_tree=$(GIT_DIR="$STORAGE/zmediacut" git rev-parse 'master^{tree}:docs')
  rm -f "$STORAGE/zmediacut/objects/${cut_tree:0:2}/${cut_tree:2}"
  e_tree zmediapeer  60 master "notes.txt:100"
  local stranger=$STRANGER_NID
  # A README on the branch and a clip on the delegate's own issue, replicated by a peer.
  # Replication mirrors the branch, so a stranger's refs hold the README too. Subtracting
  # that leaves the un-mirrored clip, and a real repo looking like a dump.
  e_tree zmediamirr  60 master "README.md:8192"
  e_tree zmediamirr  60 "refs/namespaces/$(dlg zmediamirr)/refs/cobs/xyz.radicle.issue/aaa" \
                        "clip.mp4:40000"
  GIT_DIR="$STORAGE/zmediamirr" git update-ref \
    "refs/namespaces/$stranger/refs/heads/master" \
    "$(GIT_DIR="$STORAGE/zmediamirr" git rev-parse master)"
  e_tree zmediapeer  60 "refs/namespaces/$stranger/refs/cobs/xyz.radicle.issue/aaa" \
                        "clip.mp4:40000"
  # The same trap one layer in: the text is in the delegate's own issue thread, and
  # replication mirrors COB refs too. Subtracting them leaves only the branch's clip, the
  # dump shape exactly.
  e_tree zmediacobm  60 master "clip.mp4:70000:mp4" "README.md:64"
  e_tree zmediacobm  60 "refs/namespaces/$(dlg zmediacobm)/refs/cobs/xyz.radicle.issue/aaa" \
                        "0:60000"
  GIT_DIR="$STORAGE/zmediacobm" git update-ref \
    "refs/namespaces/$stranger/refs/cobs/xyz.radicle.issue/aaa" \
    "$(GIT_DIR="$STORAGE/zmediacobm" git rev-parse \
        "refs/namespaces/$(dlg zmediacobm)/refs/cobs/xyz.radicle.issue/aaa")"

  # Rule G fixture. Three peers push one clip ("same", so one blob) into three repos none of
  # them delegates. Only the first is a parasite: the second delegates zparaown, the third
  # also wrote something. Each repo has a README on its branch, so none is a media dump.
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

# Defense in depth: refuse to run if STORAGE is not inside the temp fixture.
assert_isolated(){
  case "$STORAGE" in
    "$ROOT"/*) : ;;
    *) echo "ABORT: STORAGE=$STORAGE is not under the test root $ROOT"; exit 3 ;;
  esac
}

# run the real script against the fixture; echoes combined output
# shellcheck disable=SC2120  # no caller passes flags today; they must still reach the script
run(){ local out; out=$("$SCRIPT" "$@" 2>&1); printf '%s' "$out"; }
# One past applied run, as the ratchet reads it: an audit log and its history.log line.
# $1 = which run (1-9, oldest first), then any of "reason:count" for what it pruned,
# "held:<rule>" for a rule it held back, "rules:<letters>" for the rules it ran with.
past_run(){
  local i=$1 spec reason count r log="prune-2026010${1}T000000Z.log" rules="" held=""
  shift
  for spec in "$@"; do
    case $spec in rules:*) rules="  rules=${spec#rules:}" ;; held:*) held+=" ${spec#held:}" ;; esac
  done
  mkdir -p "$AUDIT_DIR"
  { printf '# What one rad prune run removed from storage or blocked, one repo per row.\n'
    printf '# 2026-01-0%sT00:00:00Z  pressure=0%%%s\n' "$i" "$rules"
    for r in $held; do printf '# held back: rule %s, 99 repos (usual 0, limit 20)\n' "$r"; done
    for spec in "$@"; do
      case $spec in rules:*|held:*) continue ;; esac
      reason=${spec%%:*}; count=${spec#*:}
      for r in $(seq 1 "$count"); do
        printf 'zpast%s%s%s\t1\t1\t1\t%s\tpast\t1\t\n' "$i" "${reason//-/}" "$r" "$reason"
      done
    done; } > "$AUDIT_DIR/$log"
  printf '2026-01-0%sT00:00:00Z\tdeleted=1\taudit=%s\n' "$i" "$log" >> "$AUDIT_DIR/history.log"
}
# A past where every rule but C pruned plenty and C nothing, so only C is over its usual.
# The fixture plans 4 of rule A, 1 of B, 4 of C, 12 of D and 14 of F. The link-farm rows
# stand for audit logs written while rule E existed.
USUAL_BUT_C="junk-name:20 junk-id:20 size-outlier:20 spam-batch:50 link-farm:50 media-dump:50"
# The same past for every rule but C, which each test then writes its own history for.
REST="junk-name:20 junk-id:20 size-outlier:20 spam-batch:50 media-dump:50"

# drop the tty for the non-interactive --apply test
NOTTY=(); command -v setsid >/dev/null && NOTTY=(setsid)

# $1 = a dir filled with symlinks to everything on PATH except the commands named after it.
# Mirrored, not listed, because a hand-kept list goes stale and then fails as "the tool
# needs git" when it means "the test forgot cut".
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

# The rule G fixture's peers: the parasite, the one who also wrote, and the delegate.
# Defined here because six sections read them.
PARA=zPARASITExxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
WRITER=zWRITERxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
CONTRIB=$(dlg zparaown)

# A past run's audit log as the undo reads it: $1 names the file, $2 is its stamp line after
# "# ", and stdin holds its rows and "#" lines as a run writes them.
undo_log(){
  mkdir -p "$AUDIT_DIR"
  { printf '# What one rad prune run removed from storage or blocked, one repo per row.\n'
    printf '# %s\n' "$2"
    cat; } > "$AUDIT_DIR/prune-$1.log"
}
# One plan row of such a log: $1 rid, $2 bytes, $3 reason.
undo_row(){ printf '%s\t%s\t1\t400\t%s\tpast\t0\t\n' "$1" "$2" "$3"; }
# Blocks standing on the node before the run, as `rad seed` lists them.
undo_block(){ local r; for r in "$@"; do echo "block rad:$r" >> "$RSP_HOME/.stub_policy"; done; }
# The state unprune-plan.tsv gives repo $1, or nothing when it has no row.
undo_state(){ awk -F'\t' -v r="$1" '$1 == r { print $2 }' "$AUDIT_DIR/last-run/unprune-plan.tsv"; }

summary(){
  [ -n "${ROOT:-}" ] && rm -rf "$ROOT" 2>/dev/null
  echo "-----------------------------------------"
  echo "passed: $PASS   failed: $FAIL"
  [ "$FAIL" = 0 ]
}

# ---- end of header ---------------------------------------------------------
# Below the marker is one straight-line script, cut into sections by the fixture rebuild
# that opens each. This prints the sections asked for, or in count mode how many there are.
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

# Settings every section runs under. PLAN_FULL because most assertions look for one repo's
# row; folding gets its own test. DISK_AWARE=0 lets rules B and C act at any free space,
# which the host's disk would otherwise decide.
export DISK_AWARE=0 ABS_SIZE_FLOOR_MB=1 MEDIA_MIN_BYTES=20000 PLAN_FULL=1 RULES=ABCDFGH

# Running less than the whole file in one process:
#
#   tests/run.sh -k quarantine   the sections whose text matches this regex: a test name,
#                                a rid, a knob or a rule letter.
#   tests/run.sh -n 7            the 7th section alone, in a process of its own.
#   tests/run.sh -e              every section, each in a process of its own. Slower; it
#                                fails a section that passes only after the one above it.
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
    # Each section prints its own tally; drop those and count the ok and FAIL lines instead.
    for i in $(seq 1 "$total"); do
      bash "$0" -n "$i" || echo "# section $i exited $?, see above"
    done | grep -vE '^(-+$|passed: )' | tee "$printed"
    PASS=$(grep -c '^ok   - ' "$printed")
    FAIL=$(grep -c '^FAIL - ' "$printed")
    # A section that died part-way hid its remaining assertions from both counts.
    [ "$FAIL" -gt 0 ] || FAIL=$(grep -c '^# section [0-9]* exited ' "$printed")
    rm -f "$printed"
    summary
    exit
    ;;
esac

# ============================================================================
# Split into sections so -k on a rule reaches a few runs. Several rebuild the default plan,
# since a section that borrowed it could not run on its own.
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

# --- pruning the last copy WE KNOW OF, only on conclusive evidence --- No other seed having
# it marks generated bulk as worthless and anything else as worth keeping, so rule A's two
# branches take separate seed floors and rule C never prunes the last copy.
has "$plan" "zhexzero27" && grep -qE "^zhexzero27 .*junk-id" <<<"$plan" \
  && ok "zero-seed random-id name is pruned (junk-id prunes the last copy)" \
  || no "zero-seed junk-id pruned"
! has "$plan" "zwordzero28" \
  && ok "zero-seed 'test-orphan' is kept (a word in a name is a guess, not proof)" \
  || no "zero-seed junk-name kept"
has "$plan" "zspamzero" && grep -qE "^zspamzero .*spam-batch" <<<"$plan" \
  && ok "zero-seed spam batch member is pruned" || no "zero-seed spam-batch pruned"

# Both floors must be able to say no.
plan_i=$(JUNK_ID_MIN_SEEDS=1 run)
! has "$plan_i" "zhexzero27" && has "$plan_i" "zhexid23" \
  && ok "JUNK_ID_MIN_SEEDS=1 spares the zero-seed id repo, keeps the seeded one" \
  || no "JUNK_ID_MIN_SEEDS check is vacuous"
# zwordzero28 must survive because of the floor, not because it fails every other rule.
# With the floor dropped it has to appear.
plan_w=$(JUNK_MIN_SEEDS=0 run)
grep -qE "^zwordzero28 .*junk-name" <<<"$plan_w" \
  && ok "JUNK_MIN_SEEDS=0 does reach the zero-seed word repo (so the keep above is real)" \
  || no "zero-seed junk-name keep is vacuous"
plan_s=$(SPAM_MIN_SEEDS=1 run)
! has "$plan_s" "zspamzero" && has "$plan_s" "zspam1" \
  && ok "SPAM_MIN_SEEDS=1 spares the zero-seed spam repo, keeps the seeded ones" \
  || no "SPAM_MIN_SEEDS check is vacuous"

# A repo whose description quotes an rid ("...used for the site in rad:z3U9...") is filed under
# its OWN rid, the first rad: token on the row, not under the rid it mentions.
grep -qE "^zridin25 .*ridquoter$" <<<"$plan" \
  && ok "a description quoting an rid still files under the row's own rid" \
  || no "row filed under its own rid"
# A name with a space keeps all of it: rule D skeletonises "Blog e64", not "Blog".
grep -qE "^zspaced26 .*Blog e64$" <<<"$plan" \
  && ok "a name containing spaces survives the parse" \
  || no "spaced name survives the parse"

# --- disk-pressure: at full pressure, stale window shrinks + seed floor drops to 1 ---
plan_hi=$(DISK_AWARE=1 ABS_SIZE_FLOOR_MB=1 \
          PRESSURE_CRIT_PCT=100 PRESSURE_CRIT_GB=99999999 \
          PRESSURE_RELAX_PCT=100 PRESSURE_RELAX_GB=999999999 run)
has "$plan_hi" "zbwid9" \
  && ok "pressure prunes a repo that was kept at p=0"   \
  || no "pressure widens the net"
has "$plan_hi" "zfews5" \
  && ok "pressure drops seed floor to 1 (under-seeded now pruned)" \
  || no "pressure drops seed floor"
! has "$plan_hi" "zfresh4" \
  && ok "pressure still keeps a fresh repo"          \
  || no "pressure keeps fresh repo"
# A repo with every ref dated 1970 has no usable date, so its age comes from the day this
# seed first saw it: still judged, not counted unreadable.
for ref in $(GIT_DIR="$STORAGE/zspam1" git for-each-ref --format='%(refname)'); do
  GIT_DIR="$STORAGE/zspam1" git cat-file -e "$ref^{commit}" 2>/dev/null || continue
  c=$(GIT_DIR="$STORAGE/zspam1" GIT_AUTHOR_NAME=a GIT_AUTHOR_EMAIL=a@b \
      GIT_COMMITTER_NAME=a GIT_COMMITTER_EMAIL=a@b \
      GIT_AUTHOR_DATE="@0 +0000" GIT_COMMITTER_DATE="@0 +0000" \
      git commit-tree -m m "$ref^{tree}")
  GIT_DIR="$STORAGE/zspam1" git update-ref "$ref" "$c"
done
touch -d "10 days ago" "$STORAGE/zspam1"
mkdir -p "$AUDIT_DIR"
printf 'zspam1\t%s\n' "$(date -d '30 days ago' +%s)" >> "$AUDIT_DIR/first-seen.tsv"
# A ref dated in the year 3000 would keep ztwoyr3 looking active for good.
c=$(GIT_DIR="$STORAGE/ztwoyr3" GIT_AUTHOR_NAME=a GIT_AUTHOR_EMAIL=a@b \
    GIT_COMMITTER_NAME=a GIT_COMMITTER_EMAIL=a@b \
    GIT_AUTHOR_DATE="@32503680000 +0000" GIT_COMMITTER_DATE="@32503680000 +0000" \
    git commit-tree -m m "$(GIT_DIR="$STORAGE/ztwoyr3" git rev-parse 'HEAD^{tree}')")
GIT_DIR="$STORAGE/ztwoyr3" git update-ref refs/heads/future "$c"
touch -d "10 days ago" "$STORAGE/ztwoyr3"
plan_e=$(run)
{ grep -qE '^zspam1 .* spam-batch ' <<<"$plan_e" \
    && ! grep -qE '[1-9][0-9]* with no readable refs' <<<"$plan_e"; } \
  && ok "a repo whose refs are all dated 1970 is aged from when the seed first saw it" \
  || no "refs dated 1970 left a spam repo ageless"
grep -qE '^ztwoyr3 .* stale ' <<<"$plan_e" \
  && ok "a ref dated far ahead does not keep a repo looking active" \
  || no "a ref dated in the year 3000 shielded a stale repo"


build_fixture; assert_isolated
# --- rule A spares an import: a junk-named repo whose history predates its rad init.
# Both repos' init is 380 days ago. master's author date moves back 20 days for zjunk1,
# past IMPORT_SPARE_DAYS, and 12 for zbar8, short of it. Committer dates stay at the
# init, so only the author date counts.
init=$(date -u -d "380 days ago" +%s)
for spec in zjunk1:20 zbar8:12; do
  d="$STORAGE/${spec%%:*}"
  old=$(( init - ${spec#*:} * 86400 ))
  for ref in refs/heads/master refs/rad/id; do
    author=$init; [ "$ref" = refs/heads/master ] && author=$old
    c=$(GIT_AUTHOR_DATE="@$author +0000" GIT_COMMITTER_DATE="@$init +0000" \
        git -c user.name=a -c user.email=a@b --git-dir="$d" \
          commit-tree "$(git --git-dir="$d" rev-parse "$ref^{tree}")" -m c)
    git --git-dir="$d" update-ref "$ref" "$c"
  done
  touch -d "10 days ago" "$d"
done
plan=$(run)
{ ! has "$plan" "zjunk1" && grep -qE '^#        zjunk1 +test-old$' <<<"$plan" \
  && [ "$(grep -v '^#' "$AUDIT_DIR/last-run/A-junk-name-kept-imports.tsv")" = "$(printf 'zjunk1\ttest-old')" ]; } \
  && ok "rule A spares a junk-named import, and names it" \
  || no "rule A spares a junk-named import"
grep -qE "^zbar8 .*junk-name +[^ ]*import" <<<"$plan" \
  && ok "rule A prunes a repo 12 days short of an import, marked near" \
  || no "rule A spared a repo under IMPORT_SPARE_DAYS, or did not mark it near"


build_fixture; assert_isolated
plan=$(run)

# --- rule D: generated-bulk batches, decided by the corpus ---
# All nine zspam members must be pruned, the last included, since the batch-extension pass
# carries those whose random slot came out all digits.
spamhits=$(grep -cE "^zspam[1-9] .*spam-batch" <<<"$plan" || true)
[ "$spamhits" = 9 ] \
  && ok "templated batch (id slot + one description) pruned (spam-batch)" \
  || no "spam batch pruned (got $spamhits/9)"
# Repos pushed in the shape of an older one must not take the older one with them.
printf 'zspam3\t%s\n' "$(date -u -d "800 days ago" +%s)" >> "$AUDIT_DIR/first-seen.tsv"
plan_orig=$(run)
{ ! has "$plan_orig" "zspam3" && grep -qE "^zspam4 .*spam-batch" <<<"$plan_orig" \
  && grep -q 'spared 1 repo as the first.*rad:zspam3' <<<"$plan_orig"; } \
  && ok "the batch member this seed saw before every other one is spared" \
  || no "a spam batch took along the repo it was shaped after"
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

# The check must be able to say no: with the threshold above the batch size the same repos
# must survive.
plan_k=$(SPAM_MIN_BATCH=13 run)   # the flatten batch is 12 members
[ "$(grep -cE "^zspam[1-9] " <<<"$plan_k" || true)" = 0 ] \
  && ok "SPAM_MIN_BATCH above the batch size spares it" \
  || no "SPAM_MIN_BATCH check is vacuous"
# Opting out of the random-id requirement is what reaches an enumeration-only batch.
plan_id=$(SPAM_REQUIRE_ID=0 run)
idhits=$(grep -cE "^zenum[1-9] .*spam-batch" <<<"$plan_id" || true)
iddecoy=$(grep -cE "^zdecoy[1-9] " <<<"$plan_id" || true)
{ [ "$idhits" = 9 ] && [ "$iddecoy" = 0 ]; } \
  && ok "SPAM_REQUIRE_ID=0 reaches enumeration batches, still not the decoy" \
  || no "SPAM_REQUIRE_ID=0 reaches enum batch (got $idhits/9 enum, $iddecoy/9 decoy)"
# --- rule D clocks CREATION, not last activity ---
# A spammer appending a COB every few days resets a last-activity clock forever. Creation
# only moves forward.
has "$plan" "zspamfresh" && grep -qE "^zspamfresh .*spam-batch" <<<"$plan" \
  && ok "spam repo created 90d ago but touched yesterday is still pruned" \
  || no "rule D clocks creation"
# ...and the window must still be able to spare a batch that is genuinely new.
plan_b=$(SPAM_STALE_DAYS=99999 run)
[ "$(grep -cE "^zspam" <<<"$plan_b" || true)" = 0 ] \
  && ok "SPAM_STALE_DAYS spares a batch younger than the window" \
  || no "rule D creation window is vacuous"


build_fixture; assert_isolated
plan=$(run)

# --- rule F: media dumps --- A repo tracking a video and nothing else uses the seed as
# file hosting. Each fixture differs from the others in one thing.
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
# zmediapast's issue has two ops and zmediacob's one, so a cap of one leaves only the
# first unjudged. Judged on its newest op alone zmediapast would also leave the plan, so
# the unjudged list is what shows the cap.
plan_fo=$(MEDIA_MAX_OPS=1 run)
{ ! has "$plan_fo" "zmediapast" && grep -qE "^zmediacob .*media-dump" <<<"$plan_fo" \
  && cut -f1 "$RSP_HOME/prune-audit/last-run/F-media-unjudged.tsv" | grep -qx zmediapast; } \
  && ok "a repo over MEDIA_MAX_OPS issue and patch ops is left unjudged, the rest judged" \
  || no "MEDIA_MAX_OPS is vacuous"
! has "$plan" "zmediagz" \
  && ok "compressed data is judged by what it unpacks to: text" \
  || no "a .csv.gz of text counted as media"
grep -qE "^zmediagzv .*media-dump" <<<"$plan" \
  && ok "a video compressed and named like data is still a video" \
  || no "a .csv.gz name hid the video inside it"
! has "$plan" "zmediahost" \
  && ok "a seed's logo under its hostname is not a dump" \
  || no "a hostname-named repo holding a logo was judged a dump"
grep -qE "^zmediahostbig .*media-dump" <<<"$plan" \
  && ok "a hostname spares no more media than a logo needs" \
  || no "a hostname-named repo spared a clip over MEDIA_HOST_MAX_BYTES"
grep -qE "^zmediapng .*media-dump" <<<"$plan" \
  && ok "a name ending in a media extension is not a hostname" \
  || no "a repo named wallpapers.png passed as a seed's logo"
grep -qE "^zmediagzt .*media-dump" <<<"$plan" \
  && ok "a tar compressed and named like text counts as media" \
  || no "a .txt.gz holding binary data passed as text"
{ ! has "$plan" "zmediagzu" && ! has "$plan" "zmediagzw" && ! has "$plan" "zmediagzb"; } \
  && ok "UTF-16 and UTF-32 text with a byte-order mark counts as text" \
  || no "compressed UTF-16 or UTF-32 notes were judged media"
{ ! has "$plan" "zmediamake" && ! has "$plan" "zmediasrc"; } \
  && ok "a build file or a source file spares a repo from the dump path" \
  || no "a build or source file did not spare a clip"
grep -qE "^zmediaratio .*media-ratio" <<<"$plan" \
  && ok "a README tiny beside a big clip does not spare it, on any branch (media-ratio)" \
  || no "the ratio path missed a big clip behind a short README"
! has "$plan" "zmediaratio3" \
  && ok "a licence in place of the README spares that clip" \
  || no "the ratio path ignored a file that is not a README"
! has "$plan" "zmediaratio4" \
  && ok "two READMEs beside that clip spare it" \
  || no "the ratio path ignored MEDIA_RATIO_MAX_FILES"
! has "$plan" "zmediaratio7" \
  && ok "a README over 0.1% of that clip spares it" \
  || no "the ratio path ignored MEDIA_RATIO_TEXT_PER_MILLE"
! has "$plan" "zmediahtm" \
  && ok "a page named README beside that clip is not a README, and spares it" \
  || no "a README.html with its pictures was judged a dump"
! has "$plan" "zmediacobr" \
  && ok "the ratio path weighs only the media at the tips, not the issues' attachments" \
  || no "a README beside a clip attached to an issue was judged a dump"
{ ! has "$plan" "zmediapkg" && ! has "$plan" "zmediapkg2"; } \
  && ok "a release archive beside that clip spares it, by name or by content" \
  || no "a release zip and a short README were judged a dump"
! has "$(MEDIA_RATIO_MIN_BYTES=6400002 run)" "zmediaratio" \
  && ok "MEDIA_RATIO_MIN_BYTES sets how much media the ratio path needs" \
  || no "the ratio path ignored MEDIA_RATIO_MIN_BYTES"

# Shapes a real 11k-repo seed threw at rule F: names a naive match misreads, and COB
# files it need not open.
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
# The fragment a half-finished listing leaves holds the clip and not the README, so judging
# it would delete the repo on the evidence that failed to arrive.
{ ! has "$plan" "zmediatorn" && grep -q 'could not judge 1 repo,' <<<"$plan"; } \
  && ok "a repo whose listing dies part-way is left unjudged, not pruned on the fragment" \
  || no "rule F judges a repo on a partial listing"
# zmediacut is the same break behind a README that clears the widest budget. Only
# zmediatorn is unjudged, so the walk stopped at that README. Reading on would make the
# unjudged count 2.
{ ! has "$plan" "zmediacut" && grep -q 'could not judge 1 repo,' <<<"$plan"; } \
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

# --- rule F leaves a repo unjudged when the stage shaping its listing dies --- The git
# readers before it see only a closed pipe, so only that stage's exit shows it.
# zmediatwo's README spares it, and the cut listing holds the clip alone.
build_fixture; assert_isolated
tornawk="$ROOT/torn-awk"; mkdir -p "$tornawk"
cp "$HERE/torn-awk-shim" "$tornawk/awk"; chmod +x "$tornawk/awk"
plan=$(PATH="$tornawk:$PATH" run)
{ ! has "$plan" "zmediatwo" \
    && grep -q '^zmediatwo'$'\t' "$AUDIT_DIR/last-run/F-media-unjudged.tsv"; } \
  && ok "a listing whose last stage dies leaves the repo unjudged, not pruned on the rest" \
  || no "rule F judged a repo on a listing cut short by its last stage"

# --- rule F counts only ops a delegate signed, and a repo it cannot list whole is unjudged ---
# zmediapeer's delegate replies to the stranger's op, which makes it a parent of the reply,
# so the stranger's clip sits in the history of the delegate's own COB ref. The stranger's
# commit names the delegate as author and carries the delegate's signature, copied from the
# reply. Only a signature over the commit's own tree shows who made it.
# zmediacob gains a branch whose tip is gone from the object store. What it held is
# unknown, so the repo cannot be judged on what is left.
# A stranger's branch at the newest op of zmediapast's issue must not hide the older clip.
build_fixture; assert_isolated
d="$STORAGE/zmediapeer"
ts=$(date -u -d "60 days ago" +%s)
reply=$(printf '100644 blob %s\t0\n' \
          "$(printf '{"body":"thanks"}' | GIT_DIR="$d" git hash-object -w --stdin)" \
        | GIT_DIR="$d" git mktree)
c=$(GIT_DIR="$d" GIT_AUTHOR_DATE="@$ts +0000" GIT_COMMITTER_DATE="@$ts +0000" \
      git -c user.name=a -c user.email=a@b commit-tree -m reply "$reply")
sigblock=$(GIT_DIR="$d" git cat-file commit "$(GIT_DIR="$d" sign_op "$c")" \
             | sed -n '/^gpgsig /,/END SSH SIGNATURE/p')
s=$(GIT_DIR="$d" git rev-parse "refs/namespaces/$STRANGER_NID/refs/cobs/xyz.radicle.issue/aaa")
forged=$({ GIT_DIR="$d" git cat-file commit "$s" \
             | sed -n "/^\$/q; s/ <[^>]*> / <op@$COB_NID> /; p"
           printf '%s\n\n' "$sigblock"
           GIT_DIR="$d" git cat-file commit "$s" | sed '1,/^$/d'; } \
         | GIT_DIR="$d" git hash-object -t commit -w --stdin)
c=$(GIT_DIR="$d" GIT_AUTHOR_DATE="@$ts +0000" GIT_COMMITTER_DATE="@$ts +0000" \
      git -c user.name=a -c user.email=a@b commit-tree -p "$forged" -m reply "$reply")
GIT_DIR="$d" git update-ref "refs/namespaces/$COB_NID/refs/cobs/xyz.radicle.issue/eee" \
  "$(GIT_DIR="$d" sign_op "$c")"
touch -d "10 days ago" "$d"
e_tree zmediacob 60 extra "README.md:4096"
gone=$(GIT_DIR="$STORAGE/zmediacob" git rev-parse extra)
rm -f "$STORAGE/zmediacob/objects/${gone:0:2}/${gone:2}"
d="$STORAGE/zmediapast"
GIT_DIR="$d" git update-ref "refs/namespaces/$STRANGER_NID/refs/heads/hide" \
  "refs/namespaces/$COB_NID/refs/cobs/xyz.radicle.issue/ccc"
touch -d "10 days ago" "$d"
# zmediaone gains a directory of small trees listing only 2^11 paths, but ones 11 KB
# long, over MEDIA_TIP_BYTES in all.
d="$STORAGE/zmediaone"
root=$({ GIT_DIR="$d" git ls-tree master
         printf '040000 tree %s\tx\n' "$(bomb_tree "$d" 11 1000)"; } | GIT_DIR="$d" git mktree)
c=$(GIT_DIR="$d" GIT_AUTHOR_DATE="@$ts +0000" GIT_COMMITTER_DATE="@$ts +0000" \
      git -c user.name=a -c user.email=a@b commit-tree -p master -m more "$root")
GIT_DIR="$d" git update-ref refs/heads/master "$c"; touch -d "10 days ago" "$d"
plan=$(run)
! has "$plan" "zmediapeer" \
  && ok "a stranger's op a delegate replied to is not the repo's, whoever it names as author" \
  || no "rule F counted a stranger's op reached through a delegate's reply"
{ ! has "$plan" "zmediacob" && grep -q 'could not judge 3 repos ' <<<"$plan"; } \
  && ok "a branch whose tip is gone leaves the repo unjudged, not judged on the rest" \
  || no "rule F judged a repo on the branches it could still read"
grep -qE "^zmediapast .*media-dump" <<<"$plan" \
  && ok "a stranger's branch cannot hide a delegate's issue ops from rule F" \
  || no "a stranger's branch on an op hid the clip in the issue's history"
! has "$plan" "zmediaone" \
  && ok "a repo whose tips list as too many paths is left unjudged" \
  || no "rule F judged a repo whose tree repeats itself into 22 MB of paths"


build_fixture; assert_isolated

# --- rule F: the batch path, and every threshold behind a media verdict ---
plan=$(run)

# The batch path. A README clears the single-repo budget, so only other repos holding the
# same file reach these. zbatch4's script spares nothing here; zbatch5's Makefile does.
[ "$(grep -cE "^zbatch[124] .*media-batch" <<<"$plan" || true)" = 3 ] \
  && ok "repos reposting one clip behind a README are pruned (media-batch)" \
  || no "the batch path prunes a reposted dump"
! has "$plan" "zbatch5" \
  && ok "a build file spares a repo from the batch path" \
  || no "a build file did not spare a reposted clip"
! has "$plan" "zbatch3" \
  && ok "the repo that published the clip first is not in its own batch" \
  || no "the batch path spares the first holder"
! has "$plan" "zbatchodd" \
  && ok "the same README over a clip nobody else holds still spares the repo" \
  || no "the batch path is about the sharing, not the README"
plan_fk=$(MEDIA_MIN_BATCH=6 run)
[ "$(grep -cE "^zbatch[1-5] " <<<"$plan_fk" || true)" = 0 ] \
  && ok "MEDIA_MIN_BATCH=6 spares all five, and a repo with too much text is no holder" \
  || no "MEDIA_MIN_BATCH is vacuous"
plan_fc=$(MEDIA_TEXT_CEIL_BYTES=100 run)
[ "$(grep -cE "^zbatch[1-5] " <<<"$plan_fc" || true)" = 0 ] \
  && ok "a ceiling under their README spares them, batch or no batch" \
  || no "MEDIA_TEXT_CEIL_BYTES is vacuous"

# Each threshold must be able to say no and yes on its own: a rule that only spares looks
# like one that never runs. zmediarefs is a dump until its third ref passes the cap, and
# the run must say so instead of counting it clean.
grep -qE "^zmediarefs .*media-dump" <<<"$plan" \
  && ok "a dump under MEDIA_MAX_REFS is judged" || no "the extra ref alone spares zmediarefs"
plan_fr=$(MEDIA_MAX_REFS=2 run)
{ ! has "$plan_fr" "zmediarefs" && grep -q 'unjudged' <<<"$plan_fr" \
  && grep -qE "^zmediaone .*media-dump" <<<"$plan_fr"; } \
  && ok "a repo over MEDIA_MAX_REFS is left unjudged, said so, and the rest still run" \
  || no "MEDIA_MAX_REFS is vacuous"
plan_ft=$(MEDIA_TEXT_MAX_BYTES=99999 run)
grep -qE "^zmediatwo .*media-dump" <<<"$plan_ft" \
  && ok "a bigger text budget reaches the repo its README was sparing" \
  || no "MEDIA_TEXT_MAX_BYTES is vacuous"
# zmediawide's README sits between the two budgets and its media is found only by
# reading, so raising one budget past the other must move the read guard too.
grep -qE "^zmediawide .*media-dump" <<<"$plan_ft" \
  && ok "raising the text budget past the ceiling still reads the files it needs" \
  || no "the read guard uses the narrower budget"
! has "$plan" "zmediawide" \
  && ok "that same long README spares it at the default budget" \
  || no "a 70KB README should clear a 2KB budget"
plan_fx=$(MEDIA_EXTS='bin' run)
{ grep -qE "^zmediabin .*media-dump" <<<"$plan_fx" && ! has "$plan_fx" "zmediaone"; } \
  && ok "MEDIA_EXTS decides what counts as media, both ways" || no "MEDIA_EXTS is vacuous"

# Rule F may prune the last copy we know of: its evidence is what the repo itself holds.
grep -qE "^zmediazero .*media-dump" <<<"$plan" \
  && ok "a media dump no other node seeds is pruned by default" \
  || no "the default seed floor spared a dump nobody else seeds"
plan_fz=$(MEDIA_MIN_SEEDS=1 run)
! has "$plan_fz" "zmediazero" \
  && ok "MEDIA_MIN_SEEDS=1 keeps the last copy we know of" \
  || no "MEDIA_MIN_SEEDS is vacuous"
# Sparing it silently would make the seed floor a hiding place, so the run names it.
{ grep -qx '# REVIEW 1 media dump no other node seeds, not pruned' <<<"$plan_fz" \
    && grep -qE '^#        zmediazero +media-dump' <<<"$plan_fz"; } \
  && ok "the dump it kept is named for a human to look at" \
  || no "the review list names what it kept"


# Repos first seen in one run tie in the ledger. The original is then the repo whose
# storage dir was made first, never the lowest id, since a pusher can grind an id.
# zbatch3 loses its ledger row so all five tie, and the others are made again a second
# later, after zbatch3.
build_fixture; assert_isolated
sed -i '/^zbatch3\t/d' "$AUDIT_DIR/first-seen.tsv"
sleep 1
for r in zbatch1 zbatch2 zbatch4; do
  cp -a "$STORAGE/$r" "$STORAGE/$r.new"; rm -rf "${STORAGE:?}/$r"
  mv "$STORAGE/$r.new" "$STORAGE/$r"
done
plan_tie=$(run)
{ ! has "$plan_tie" "zbatch3" && grep -qE "^zbatch1 .*media-batch" <<<"$plan_tie"; } \
  && ok "in a first-seen tie the repo stored first keeps the clip, whatever its id" \
  || no "a first-seen tie went to the repo whose id sorts first"
build_fixture; assert_isolated

# --- plan folding --- A corpus verdict folds to one line once its group is big; a verdict
# on one repo's own metadata never folds, because those rows want eyes.
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

# --- RULES turns any rule off ---
noa=$(RULES=BCDFG run)
{ ! has "$noa" "zjunk1" && has "$noa" "zbig2"; } \
  && ok "a rule left out of RULES puts nothing in the plan" \
  || no "RULES=BCDFG still pruned a rule A repo, or took rule B down with it"
nof=$(RULES=ABCD run)
{ ! has "$nof" "zmediamd" && ! grep -q 'measuring repo trees' <<<"$nof" \
  && has "$nof" "zjunk1"; } \
  && ok "a rule left out of RULES does not even run its scan" \
  || no "RULES=ABCD still ran or planned rule F"
# Rule E is gone, and a cron line from an older release still names it. Refusing the
# letter would prune nothing until somebody read the error.
withe=$(RULES=ABCDEFGH "$SCRIPT" 2>&1); rc=$?
{ [ "$rc" = 0 ] && grep -qE '^zspam1 .* spam-batch ' <<<"$withe" \
  && grep -qxF '# WARN the link-farm rule (E) was removed in 0.8.0; E in RULES is ignored.' \
       <<<"$withe"; } \
  && ok "an E in RULES is ignored with a warning, and the other rules still plan" \
  || no "an E in RULES stopped the run, planned nothing, or went unmentioned (rc=$rc)"
dflt=$(env -u RULES "$SCRIPT" 2>&1)
{ ! grep -q 'off: not in RULES' <<<"$dflt" && ! grep -q 'link-farm' <<<"$dflt" \
  && has "$dflt" "zjunk1"; } \
  && ok "the default RULES runs every rule" \
  || no "the default RULES leaves a rule out, names E, or runs nothing at all"
onlye=$(RULES=E "$SCRIPT" 2>&1); rc=$?
{ [ "$rc" = 0 ] && grep -qxF '# WARN without the E, RULES is empty, so no rule runs.' <<<"$onlye" \
  && ! grep -qE '^z' <<<"$onlye"; } \
  && ok "RULES naming only E says no rule runs" \
  || no "RULES naming only E ran a rule, failed, or ran none without saying so (rc=$rc)"

# Rules B and C prune for space alone, so they wait while free space is above the relaxed
# threshold. The calm run's relaxed threshold of 0 free is never above free space, and the
# tight run's whole disk always is, so this machine's disk decides nothing. Under pressure
# B's endpoints match the relaxed values, so zbig2 qualifies either way.
calm=$(DISK_AWARE=1 PRESSURE_RELAX_PCT=0 PRESSURE_RELAX_GB=0 PRESSURE_CRIT_PCT=0 \
         PRESSURE_CRIT_GB=0 run)
tight=$(DISK_AWARE=1 PRESSURE_RELAX_PCT=100 PRESSURE_RELAX_GB=0 PRESSURE_CRIT_PCT=0 \
          PRESSURE_CRIT_GB=0 ABS_SIZE_FLOOR_MB_AGG=1 REL_PCTL_AGG=95 OUTLIER_STALE_DAYS_AGG=90 \
          run)
{ ! has "$calm" "zbig2" && ! has "$calm" "ztwoyr3" && has "$calm" "zjunk1" \
  && grep -q 'B size .*waiting: no disk pressure$' <<<"$calm" \
  && grep -qE "^zbig2 .* size-outlier " <<<"$tight" \
  && grep -qE "^ztwoyr3 .* stale " <<<"$tight"; } \
  && ok "rules B and C wait for disk pressure, and act once there is some" \
  || no "rules B and C pruned with no disk pressure, or not under pressure either"

# Turning a rule off must not spare a repo the other rules would prune: a dropped D verdict
# could hide the rule C verdict under it.
withd=$(STALE_YEARS_DAYS=30 RULES=ABCDFG run)
nod=$(STALE_YEARS_DAYS=30 RULES=ABCFG run)
{ has "$withd" "zspam1" && has "$nod" "zspam1" \
  && grep -qE "^zspam1 .* spam-batch " <<<"$withd" \
  && grep -qE "^zspam1 .* stale " <<<"$nod"; } \
  && ok "a repo a disabled rule would have claimed falls through to the next rule" \
  || no "RULES=ABCFG let a batch member escape rule C as well as rule D"

# --- check: a publisher's own public repos, judged as a seed would --- It runs on the
# publisher's node, so it blocks and removes nothing and writes nothing beside the
# operator's audit trail. It answers for a seed, so a repo this node's deny list names is
# still judged.
build_fixture; assert_isolated
# Ours: repos `rad ls` lists whose identity names this node. zcode4 is listed but names
# somebody else, as a fork does. zpin6 is pinned, which spares nothing on a seed. zpriv7 is
# private and quotes zmediaone, which stays public. zjunk1 is recent; a seed prunes it once
# quiet.
awk -F'\t' -v OFS='\t' '$1 ~ /^(zmediaone|zmediafresh|zpin6|zcode4|zpriv7|zspam1|zjunk1)$/ { $5 = 1 }
                         $1 == "zpriv7" { $8 = "notes on rad:zmediaone" } 1' \
  "$RSP_MANIFEST" > "$ROOT/manifest.new" && mv "$ROOT/manifest.new" "$RSP_MANIFEST"
for r in zmediaone zmediafresh zpin6 zown22 zpriv7 zspam1 zjunk1; do
  w=$(mktemp -d -p "$ROOT"); mkdir -p "$w/embeds"
  git -C "$w" -c init.defaultBranch=master init -q
  git -C "$w" config user.email a@b; git -C "$w" config user.name a
  vis=""; [ "$r" != zpriv7 ] || vis=',"visibility":{"type":"private"}'
  printf '{"delegates":["did:key:%s"],"payload":{},"threshold":1%s}\n' "$RSP_NID" "$vis" \
    > "$w/embeds/radicle.json"
  # zjunk1 is not an import: its identity is as old as its history.
  when=""; [ "$r" != zjunk1 ] || when="@$(date -u -d '400 days ago' +%s) +0000"
  git -C "$w" add -A
  GIT_AUTHOR_DATE="$when" GIT_COMMITTER_DATE="$when" git -C "$w" commit -q -m id
  git -C "$w" push -q --force "$STORAGE/$r" master:refs/rad/id; rm -rf "$w"
  touch -d "10 days ago" "$STORAGE/$r"
done
# zmediafresh's commits are dated a day ahead, as a fast clock dates them. A seed waits out
# a repo's age, however young.
ahead="@$(date -u -d "1 day" +%s) +0000"
for ref in $(GIT_DIR="$STORAGE/zmediafresh" git for-each-ref --format='%(refname)'); do
  c=$(GIT_DIR="$STORAGE/zmediafresh" GIT_AUTHOR_NAME=a GIT_AUTHOR_EMAIL=a@b \
      GIT_COMMITTER_NAME=a GIT_COMMITTER_EMAIL=a@b \
      GIT_AUTHOR_DATE="$ahead" GIT_COMMITTER_DATE="$ahead" \
      git commit-tree -m m "$ref^{tree}")
  GIT_DIR="$STORAGE/zmediafresh" git update-ref "$ref" "$c"
done
touch -d "10 days ago" "$STORAGE/zmediafresh"
# File names a delegate chose reach the publisher's terminal, escape sequences included.
w=$(mktemp -d -p "$ROOT"); git clone -q -b master "$STORAGE/zmediaone" "$w"
printf x > "$w/$(printf 'a\033[2Jb.mp4')"; printf x > "$w/$(printf 'c\302\233d.mp4')"
git -C "$w" add -A; git -C "$w" -c user.email=a@b -c user.name=a commit -q -m m
git -C "$w" push -q "$STORAGE/zmediaone" HEAD:master; rm -rf "$w"
touch -d "10 days ago" "$STORAGE/zmediaone"
# A repo the node writes to while the check runs is not one it can call ok.
touch -d "+1 hour" "$STORAGE/zown22"
mkdir -p "$AUDIT_DIR"; echo zpin6 > "$AUDIT_DIR/deny.txt"
audit_before=$(find "$AUDIT_DIR" -type f -exec sha1sum {} + | sort)
out=$("$SCRIPT" check-mine 2>"$ROOT/check.err"); rc=$?
{ [ "$rc" = 6 ] && ! grep -q 'WARN' "$ROOT/check.err" \
  && grep -qxE 'would-prune +clipdump +rad:zmediaone +media-dump' <<<"$out" \
  && grep -qxE ' +39 KiB  master  clip\.mp4' <<<"$out" \
  && grep -qxE ' +1 B +master  cd\.mp4' <<<"$out" \
  && ! grep -qF $'\033' <<<"$out" && ! grep -qF $'\302\233' <<<"$out" \
  && grep -qxE 'would-prune +newclip +rad:zmediafresh +media-dump' <<<"$out" \
  && grep -qxE 'would-prune +flatten-1-[0-9a-f]+ +rad:zspam1 +spam-batch' <<<"$out" \
  && grep -qxE 'ok +pinnedproj +rad:zpin6' <<<"$out" \
  && grep -qxE 'unjudged +myproj +rad:zown22' <<<"$out" \
  && grep -qxE 'would-prune +test-old +rad:zjunk1 +junk-name' <<<"$out" \
  && [ "$(grep -cE '^(ok|would-prune|unjudged) ' <<<"$out")" = 6 ]; } \
  && ok "check judges the public repos you are a delegate of, pinned and young ones too" \
  || no "check misjudged your repos, judged a fork or somebody else's, warned, or exited $rc"
coloured=$(FORCE_COLOR=1 "$SCRIPT" check-mine 2>/dev/null)
{ grep -qF $'\033[' <<<"$coloured" \
  && [ "$(sed $'s/\033\\[[0-9;]*m//g' <<<"$coloured")" = "$out" ]; } \
  && ok "check in colour is the same text as check in a pipe" \
  || no "check's coloured text differs from its plain text, or carries no colour"
{ [ "$(find "$AUDIT_DIR" -type f -exec sha1sum {} + | sort)" = "$audit_before" ] \
  && [ ! -s "$RSP_HOME/.stub_policy" ] && [ ! -s "$RSP_HOME/.stub_unseed" ]; } \
  && ok "check writes nothing to the audit dir and changes no policy" \
  || no "check left something in the audit dir or changed a policy"
# A repo the media rule (F) cannot read in full is not one the check can call ok.
out=$(MEDIA_MAX_REFS=1 "$SCRIPT" check-mine 2>/dev/null); rc=$?
{ [ "$rc" = 6 ] && grep -qxE 'unjudged +clipdump +rad:zmediaone' <<<"$out" \
  && grep -q '^             The media rule (F) could not judge it' <<<"$out"; } \
  && ok "check calls a repo the media rule (F) could not read unjudged" \
  || no "check judged, or called ok, a repo the media rule (F) could not read (rc=$rc)"
out=$("$SCRIPT" check-mine --apply 2>&1); rc=$?
[ "$rc" = 2 ] \
  && ok "check refuses --apply" || no "check took --apply (rc=$rc)"
# With the dumps and the batch member unlisted, nothing of ours is pruned, though zpriv7
# quotes zmediaone, whose identity still names this node. None of these fail the check:
# an unjudged repo, an empty routing table (a seed's count is not this node's), a stopped
# node (rad reads what a check needs from disk).
awk -F'\t' -v OFS='\t' '$1 ~ /^(zmediaone|zmediafresh|zspam1|zjunk1)$/ { $5 = 0 } 1' \
  "$RSP_MANIFEST" > "$ROOT/manifest.new" && mv "$ROOT/manifest.new" "$RSP_MANIFEST"
out=$(RSP_NO_ROUTING=1 RSP_NODE_DOWN=1 "$SCRIPT" check-mine 2>/dev/null); rc=$?
{ [ "$rc" = 0 ] && grep -qxE 'ok +pinnedproj +rad:zpin6' <<<"$out"; } \
  && ok "check exits 0 when no repo of yours would be pruned" \
  || no "check flagged a clean set of repos (rc=$rc)"


build_fixture; assert_isolated

# --- rule G: parasite peers --- Three peers put one clip in the same three repos. Only
# one is accused, so each exemption is what separates it from the other two.
# Exported, not prefixed: an assignment before a shell function does not reach the
# script it launches.
export PARASITE_MIN_REPOS=3 PARASITE_MIN_BYTES=65536 PARASITE_TEXT_MAX_BYTES=4096
gplan=$(run)
grep -q "REVIEW 1 parasite peer the" <<<"$gplan" && grep -q "$PARA" <<<"$gplan" \
  && ok "a peer posting one file into repos it is not a delegate of is reported (rule G)" \
  || no "rule G missed a peer republishing one file across repos it is not a delegate of"
! grep -q "$CONTRIB" <<<"$gplan" \
  && ok "a peer who delegates a repo somewhere in storage is never accused" \
  || no "rule G accused a delegate, whose block would stop their own repo replicating"
! grep -q "$WRITER" <<<"$gplan" \
  && ok "a peer who also wrote something is not a parasite" \
  || no "rule G accused a peer that contributed text"
{ ! has "$gplan" "zpara1" && ! has "$gplan" "zpara2" && ! has "$gplan" "zpara3"; } \
  && ok "rule G puts no repo in the plan; the peer is the finding" \
  || no "rule G pruned a repo somebody else pushed into"
unset PARASITE_MIN_REPOS PARASITE_MIN_BYTES PARASITE_TEXT_MAX_BYTES


build_fixture; assert_isolated

# --- numbers must not follow the operator's locale --- mawk honours LC_NUMERIC, so a comma
# locale hands back "2,52e+10" and the reader gets 2. The script pins LC_ALL=C; this
# compares the plan byte for byte.
if locale -a 2>/dev/null | grep -qix 'de_AT.utf8'; then
  # Plan rows only: the banner has a timestamp. Both sides are pinned, because the host may
  # itself be on a comma locale, and an unpinned baseline would then prove nothing.
  # Exported because run is a shell function.
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


build_fixture; assert_isolated

# --- the clocks a row is judged on --- Both checks below read one default plan.
fs_rows=$(grep -v '^#' "$AUDIT_DIR/first-seen.tsv")
plan=$(run)

# --- a push cannot reset the creation clock --- A repo's dates are set by its pusher, so
# force-pushing fresh dates would renew rules D and F forever. They use the older of that
# and this seed's first-seen date, which nobody outside can reach.
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
# The fixture's ledger has no header, as older versions wrote it, and the run above added
# one by rewriting the file. A dropped row would come back dated today, handing age back
# to the pusher, so zspamaged still planned as a year-old member shows its row survived.
nhead=$(grep -c '^#' "$AUDIT_DIR/first-seen.tsv")
plan_fs2=$(run)
{ head -n1 "$AUDIT_DIR/first-seen.tsv" | grep -q '^# ' \
  && grep -qE "^zspamaged .*spam-batch" <<<"$plan_fs2" \
  && ! grep -vxFf "$AUDIT_DIR/first-seen.tsv" <<<"$fs_rows" \
  && [ "$(grep -c '^#' "$AUDIT_DIR/first-seen.tsv")" = "$nhead" ]; } \
  && ok "a ledger without a header gets one, once, and keeps every row it had" \
  || no "adding the ledger's header lost rows or stacked a second header"
! grep -q 'integer expression' <<<"$plan" \
  && ok "a torn ledger line is skipped, not fed to an arithmetic comparison" \
  || no "a torn ledger line is skipped"

# --- what the run left alone is counted in the report, not silently absent ---
skipped_re='^# skipped (.*, )?1 written in the last 2 days$'
{ ! has "$plan" "zinfetch" \
    && grep -qE "$skipped_re" <<<"$plan"; } \
  && ok "a repo written mid-run is skipped and counted in the report" \
  || no "the freshness guard is reported"
plan_fg=$(FRESH_GUARD_DAYS=0 run)
grep -qE "^zinfetch .*stale" <<<"$plan_fg" \
  && ok "FRESH_GUARD_DAYS=0 reaches it, so the skip above is the guard" \
  || no "the freshness guard is vacuous"


build_fixture; assert_isolated

# --- what a run cannot read is reported, never quietly dropped --- The run names each
# case and finishes or aborts loudly.

# --- an empty `rad ls` warns: blank names and a blind rule D would look like a clean seed ---
# With no listing, own and private repos are found from the repo itself. Otherwise --apply
# would quarantine and block them.
# zbig2 names this node as delegate, nests a private visibility in a payload placed
# first, and has a root branch named like our signed refs. Its delegates can write all
# three, so it stays in the plan. zpriv7's delegate is on the deny list but, kept with
# its repo, is not blocked.
d="$STORAGE/zbig2"
w=$(mktemp -d -p "$ROOT")
printf '%s' '{"payload":{"x.y":{"visibility":{"type":"private"}}},' \
  "\"delegates\":[\"did:key:$(dlg zbig2)\",\"did:key:$RSP_NID\"],\"threshold\":1}" > "$w/doc"
# Dated like the document it replaces, so the repo's age does not move.
ts=$(GIT_DIR="$d" git log -1 --format=%ct refs/rad/id)
c=$(GIT_DIR="$d" GIT_AUTHOR_DATE="@$ts +0000" GIT_COMMITTER_DATE="@$ts +0000" \
      git -c user.name=a -c user.email=a@b commit-tree -p refs/rad/id -m id \
      "$(printf '100644 blob %s\tradicle.json\n' "$(GIT_DIR="$d" git hash-object -w "$w/doc")" \
         | GIT_DIR="$d" git mktree | xargs printf '040000 tree %s\tembeds\n' \
         | GIT_DIR="$d" git mktree)")
GIT_DIR="$d" git update-ref refs/rad/id "$c"; rm -rf "$w"
GIT_DIR="$d" git update-ref "refs/heads/refs/namespaces/$RSP_NID/refs/rad/sigrefs" refs/rad/id
touch -d "10 days ago" "$d"
# zheavy is private in a document rad would not write, its allow list after the type.
d="$STORAGE/zheavy"
w=$(mktemp -d -p "$ROOT")
printf '%s' "{\"delegates\":[\"did:key:$(dlg zheavy)\"],\"payload\":{},\"threshold\":1," \
  '"visibility":{"type":"private","allow":[]}}' > "$w/doc"
ts=$(GIT_DIR="$d" git log -1 --format=%ct refs/rad/id)
c=$(GIT_DIR="$d" GIT_AUTHOR_DATE="@$ts +0000" GIT_COMMITTER_DATE="@$ts +0000" \
      git -c user.name=a -c user.email=a@b commit-tree -p refs/rad/id -m id \
      "$(printf '100644 blob %s\tradicle.json\n' "$(GIT_DIR="$d" git hash-object -w "$w/doc")" \
         | GIT_DIR="$d" git mktree | xargs printf '040000 tree %s\tembeds\n' \
         | GIT_DIR="$d" git mktree)")
GIT_DIR="$d" git update-ref refs/rad/id "$c"; rm -rf "$w"; touch -d "10 days ago" "$d"
printf 'did:key:%s\n' "$(dlg zpriv7)" > "$AUDIT_DIR/deny.txt"
out=$(RSP_NO_LS=1 DISK_AWARE=0 ABS_SIZE_FLOOR_MB=1 run)
{ grep -q "WARN .*returned no repos" <<<"$out" && ! grep -qE '^zspam[1-9] ' <<<"$out"; } \
  && ok "an empty repo listing is reported, not silently read as 'no spam'" \
  || no "empty repo listing warns"
# With no names, zmediahost's hostname cannot spare its logo, so its size has to.
{ ! grep -qE '^zmediahost ' <<<"$out" && grep -qE '^zmediahostbig .*media-dump' <<<"$out"; } \
  && ok "a repo with no name this run and only a logo's worth of media is not a dump" \
  || no "an empty rad ls left a seed's logo repo to rule F"
{ ! has "$out" zown22 && ! has "$out" zpriv7 && ! has "$out" zheavy && has "$out" zbig2 \
  && grep -qE '^#   zown22 +ours$' <<<"$out" && grep -qE '^#   zpriv7 +private$' <<<"$out" \
  && grep -qE '^#   zheavy +private$' <<<"$out"; } \
  && ok "own and private repos stay out of the plan when rad ls lists nothing, and only they" \
  || no "an empty rad ls put own or private repos in the plan, or a forged ref kept one"
! grep -q "$(dlg zpriv7)" <<<"$(grep '^#     ' <<<"$out")" \
  && ok "a listed delegate of a repo kept as private is not blocked" \
  || no "the deny list would block the delegate of a repo kept as private"
rm -f "$AUDIT_DIR/deny.txt"

# --- RAD_HOME reaches rad as environment --- A RAD_HOME rad cannot see sends it to the
# default home, which plans zero repos. Unset in the caller, so the stub sees only what
# the script exports from `rad path`.
: > "$RSP_HOME/.stub_radhome"
env -u RAD_HOME DISK_AWARE=0 ABS_SIZE_FLOOR_MB=1 "$SCRIPT" >/dev/null 2>&1; rc=$?
{ grep -qxF "$RSP_HOME" "$RSP_HOME/.stub_radhome" && [ "$rc" = 0 ]; } \
  && ok "resolved RAD_HOME is exported to rad" \
  || no "resolved RAD_HOME is exported to rad (rc=$rc)"

# --- blind runs abort instead of reporting a reassuring, meaningless "prune 0 repos" ---
out=$(RSP_LS_FAIL=1 DISK_AWARE=0 "$SCRIPT" 2>&1); rc=$?
{ [ "$rc" = 5 ] && grep -qE "ABORT\(dry-run\): '[^']* ls[^']*' failed" <<<"$out" \
  && grep -q "invalid repository id 'notarid'" <<<"$out"; } \
  && ok "a failing rad ls aborts: it is what keeps own and private repos out of the plan" \
  || no "a failing rad ls did not abort with its error (got exit $rc)"
out=$(OUR_NID=z6Mknotanid DISK_AWARE=0 "$SCRIPT" 2>&1); rc=$?
{ [ "$rc" = 5 ] && grep -q 'ABORT(dry-run): our node id is malformed' <<<"$out"; } \
  && ok "a malformed node id aborts" \
  || no "a malformed node id did not abort (got exit $rc)"
out=$(RSP_NO_ROUTING=1 DISK_AWARE=0 "$SCRIPT" 2>&1); rc=$?
{ [ "$rc" = 5 ] && grep -q 'routing table empty' <<<"$out" \
    && ! grep -q '# PLAN ' <<<"$out"; } \
  && ok "empty routing table aborts (exit 5, no plan)" \
  || no "empty routing aborts (got exit $rc)"

# --- an unreadable repo is reported and excluded, never fatal --- du failing on one dir
# makes xargs return 123, which `set -e` turns into a silent exit. The dir is inside the
# repo, so its refs stay readable and only the scan-error exclusion keeps ztwoyr3 out.
mkdir -p "$STORAGE/ztwoyr3/unreadable" && chmod 000 "$STORAGE/ztwoyr3/unreadable"
# creating the subdir bumped mtime; keep it out of the freshness guard
touch -d "10 days ago" "$STORAGE/ztwoyr3"
# a high blind-scan limit, so this tests the per-repo exclusion, not the aggregate guard
out=$(DISK_AWARE=0 ABS_SIZE_FLOOR_MB=1 MAX_SCAN_FAIL_PCT=50 "$SCRIPT" 2>&1); rc=$?
chmod 755 "$STORAGE/ztwoyr3/unreadable"; rmdir "$STORAGE/ztwoyr3/unreadable"
{ [ "$rc" = 0 ] && grep -q '# PLAN ' <<<"$out"; } \
  && ok "unreadable repo does not abort the scan" \
  || no "unreadable repo does not abort the scan (got exit $rc)"
grep -qE '^# WARN [0-9]+ scan error' <<<"$out" \
  && ok "scan errors are reported, not swallowed" \
  || no "scan errors reported"
{ ! has "$out" "ztwoyr3" && has "$out" "zjunk1"; } \
  && ok "unreadable repo excluded from plan, others still planned" \
  || no "unreadable repo excluded from plan"

# Every heartwood repo's refs/rad/sigrefs points at a blob, which has no creatordate, so
# `for-each-ref --sort=creatordate` lists it first with an empty date and its object id
# lands in the date field. Rules D and F then compare a hex string and spare the repo.
build_fixture; assert_isolated
blob=$(printf 'sigrefs\n' | GIT_DIR="$STORAGE/zmediaone" git hash-object -w --stdin)
GIT_DIR="$STORAGE/zmediaone" git update-ref refs/rad/sigrefs "$blob"
touch -d "10 days ago" "$STORAGE/zmediaone"        # update-ref just made the repo look fresh
out=$(DISK_AWARE=0 run)
{ grep -qE "^zmediaone .*media-dump" <<<"$out" \
  && ! grep -q 'integer expression' <<<"$out"; } \
  && ok "a ref with no date does not put an object id where the repo's age belongs" \
  || no "a dateless ref blinded the age rules, and the repo went unjudged"

# The terminal output is trimmed and scrolls away, so every run, dry ones too, writes the
# lists out whole. They must hold the rows the screen left out, and say where they are.
build_fixture; assert_isolated
L="$RSP_HOME/prune-audit/last-run"
short=$(DISK_AWARE=0 PLAN_COLLAPSE_ROWS=2 PLAN_FULL=0 run)
# Counted against the plan's own total: a file missing one row could still match a number
# written here.
planned=$(sed -n 's/^# PLAN   prune \([0-9]*\) repo.*/\1/p' <<<"$short")
screenrows=$(grep -cE '^z[1-9A-HJ-NP-Za-km-z]+ ' <<<"$short")
cols=$(printf '# rid\tsize_bytes\tother_seeds\tlast_activity_unix\treason')
cols=$cols$(printf '\tname\tage_from_unix\tnear_threshold')
# Read months later, a file of rids says nothing of what it holds or which run wrote it, so
# each opens with what it holds and the stamp of its run.
stamped=1
for f in "$L"/*; do
  head -n1 "$f" | grep -qE '^# [A-Z][a-z]' || stamped=0
  grep -qE '^# [0-9-]+T[0-9:]+Z  version=[0-9][0-9a-z.-]*  mode=DRY-RUN  rules=[A-H]+  storage=/' \
       "$f" || stamped=0
done
{ grep -q "^# files  $L/   plan.tsv" <<<"$short" \
  && grep -qxF "$cols" "$L/plan.tsv" \
  && [ "$(ls "$L" | wc -l)" -ge 14 ] \
  && [ "$(grep -vc '^#' "$L/plan.tsv")" = "${planned:-0}" ] \
  && [ "${planned:-0}" -gt "$screenrows" ] \
  && [ "$stamped" = 1 ] && [ ! -e "$L.new" ]; } \
  && ok "a dry run writes the whole plan out and says where, however folded the screen was" \
  || no "the rows the plan folded away were nowhere to be found after the run"

# The evidence files must carry what the tables trimmed. The screen shows five media
# dumps and the fixture has two, so six copies of one, each a repo to every rule, take
# the count past the cut.
build_fixture; assert_isolated
L="$RSP_HOME/prune-audit/last-run"
for i in 1 2 3 4 5 6; do cp -a "$STORAGE/zmediamd" "$STORAGE/zmediacopy$i"; done
screen=$(DISK_AWARE=0 MEDIA_MIN_SEEDS=99 PLAN_FULL=0 run)
kept=$(sed -n 's/^# REVIEW \([0-9]*\) media dump.*/\1/p' <<<"$screen")
# Rows the review table printed, which the cap acts on. The "...and N more" line has a
# row's indent and would count as one.
reviewrows() { awk '/^# REVIEW [0-9]+ media dump/ { inb = 1; next }
                    inb && /^#        \.\.\.and/ { next }
                    inb && /^#        / { n++; next }
                    inb { inb = 0 }
                    END { print n + 0 }'; }
{ [ "${kept:-0}" -gt 5 ] \
  && [ "$(grep -vc '^#' "$L/F-media-kept-few-seeds.tsv")" = "$kept" ] \
  && grep -qxF "$(printf '# rid\tverdict\tname')" "$L/F-media-kept-few-seeds.tsv" \
  && [ "$(reviewrows <<<"$screen")" = 5 ] \
  && grep -q "^#        ...and $((kept - 5)) more (PLAN_FULL=1 lists them)" <<<"$screen"; } \
  && ok "an evidence table the screen cut at five is written out in full" \
  || no "the evidence file was cut down to the same rows the screen showed"

# A count of repos rule F gave up on is useless until it names them. Every fixture repo is
# over the ref ceiling below.
unj=$(DISK_AWARE=0 MEDIA_MAX_REFS=0 CACHE=0 run)
nunj=$(sed -n 's/^# WARN the media rule (F) could not judge \([0-9]*\) repo.*/\1/p' <<<"$unj")
{ [ "${nunj:-0}" -gt 0 ] \
  && grep -q "^# files  $L/   .*F-media-unjudged.tsv" <<<"$unj" \
  && [ "$(grep -vc '^#' "$L/F-media-unjudged.tsv")" = "$nunj" ] \
  && grep -qE "^zmediamd"$'\t'"[0-9]+$" "$L/F-media-unjudged.tsv" \
  && grep -qE '^#      (.* )?zmediamd( |$)' <<<"$unj"; } \
  && ok "the repos rule F gave up on are named, not only counted" \
  || no "rule F warned about $nunj unjudged repos and named none of them"
# The same repos next run are the ones the warning already named, so they get a note instead.
again=$(DISK_AWARE=0 MEDIA_MAX_REFS=0 CACHE=0 run)
{ ! grep -q 'WARN the media rule (F)' <<<"$again" \
  && grep -q "^# the media rule (F) could not judge $nunj repos, all listed" <<<"$again"; } \
  && ok "repos rule F could not judge last run either are a note, not a warning" \
  || no "rule F warned again about the same unjudged repos"
# 0.7.0 wrote that list under another name, and the first run after an upgrade reads it.
grep -v '^#' "$L/F-media-unjudged.tsv" | cut -f1 > "$L/media-unjudged.tsv"
rm "$L/F-media-unjudged.tsv"
upgraded=$(DISK_AWARE=0 MEDIA_MAX_REFS=0 CACHE=0 run)
! grep -q 'WARN the media rule (F)' <<<"$upgraded" \
  && ok "the first run after an upgrade reads 0.7.0's list of unjudged repos" \
  || no "the first run after an upgrade called every unjudged repo new"

# A .ts recording shares TypeScript's extension, so only its bytes say video. Over
# MEDIA_SNIFF_TEXT_BYTES a text-named file is read and must not pass for code. The
# copies have no rad ls name, so each holds over 1 MiB of media, below which an unnamed
# repo is spared.
build_fixture; assert_isolated
L="$RSP_HOME/prune-audit/last-run"
cp -a "$STORAGE/zmediamd" "$STORAGE/zmediats"
e_tree zmediats 60 master "rec.ts:1200000:ts"
# Past MEDIA_SNIFF_MAX_FILES (200) unknown files, the smallest go unread. Unread bytes that
# could be text past the smallest budget leave the repo unjudged. A few that could not are
# counted as text and change nothing. The unread file sorts first, so only reading biggest
# first skips it.
cap=(); for i in $(seq -w 1 200); do cap+=("clip$i.bin:6000:mp4"); done
cp -a "$STORAGE/zmediamd" "$STORAGE/zmediacap"
e_tree zmediacap 60 master "${cap[@]}" "0tail.bin:2500"
cp -a "$STORAGE/zmediamd" "$STORAGE/zmediacap2"
e_tree zmediacap2 60 master "${cap[@]}" "0tail.bin:100"
# A video beside 200 small text files already past the widest budget. No verdict is in
# reach whatever the one unread file holds, so the repo is spared, not reported unjudged.
many=(); for i in $(seq -w 1 200); do many+=("t$i.bin:400"); done
cp -a "$STORAGE/zmediamd" "$STORAGE/zmediamany"
e_tree zmediamany 60 master "big.mp4:1200000:mp4" "${many[@]}" "0tail.bin:300"
plan=$(DISK_AWARE=0 CACHE=0 run)
grep -qE "^zmediats .*media-dump" <<<"$plan" \
  && ok "an MPEG recording named .ts is read as video, not trusted as TypeScript" \
  || no "an MPEG transport stream named .ts passed for text"
{ ! has "$plan" "zmediacap" && cut -f1 "$L/F-media-unjudged.tsv" | grep -qx 'zmediacap'; } \
  && ok "files past the read cap that could change the verdict leave the repo unjudged" \
  || no "a repo was judged on the 200 files read when the rest could have changed it"
grep -qE "^zmediacap2 .*media-dump" <<<"$plan" \
  && ok "a few unread bytes that cannot change the verdict do not block it" \
  || no "a repo with a tiny unread file was left unjudged"
{ ! has "$plan" "zmediamany" && ! cut -f1 "$L/F-media-unjudged.tsv" | grep -qx 'zmediamany'; } \
  && ok "a repo no verdict can reach is spared without being reported as unjudged" \
  || no "unread files were reported as able to change a verdict nothing could reach"


build_fixture; assert_isolated
# --- a scan that missed too much of storage reports no plan --- Three unreadable repos
# against a 1% limit, whatever the fixture size. A partial scan would otherwise give a
# plausible small plan.
for r in zjunk1 zbig2 zbar8; do chmod 000 "$STORAGE/$r"; done
out=$(DISK_AWARE=0 ABS_SIZE_FLOOR_MB=1 MAX_SCAN_FAIL_PCT=1 "$SCRIPT" 2>&1); rc=$?
for r in zjunk1 zbig2 zbar8; do chmod 755 "$STORAGE/$r"; done
{ [ "$rc" = 5 ] && grep -q "could not judge 3 of $NREPOS repos" <<<"$out" \
    && grep -q "0 vanished, 3 unreadable, 0 with no readable refs\." <<<"$out" \
    && ! grep -q '# PLAN ' <<<"$out"; } \
  && ok "blind scan aborts instead of reporting a small plan" \
  || no "blind scan aborts (got exit $rc)"

# --- a walk in the scan can fail mid-flight without ending the run --- A busy seed
# changes under find, and a failing find must not end the run before it prints anything.
shimdir="$ROOT/shim"; mkdir -p "$shimdir"
cp "$HERE/find-shim" "$shimdir/find"; chmod +x "$shimdir/find"
out=$(PATH="$shimdir:$PATH" DISK_AWARE=0 ABS_SIZE_FLOOR_MB=1 "$SCRIPT" 2>&1); rc=$?
{ [ "$rc" = 0 ] && grep -qE "^# \[1/[0-9]+\] sizes +$NREPOS repos " <<<"$out" && has "$out" "zjunk1"; } \
  && ok "a failing find in the scan is survived, not fatal" \
  || no "failing find survived (got exit $rc)"
grep -qE '^# WARN [0-9]+ scan error' <<<"$out" \
  && ok "a failing find is still reported as a scan error" \
  || no "failing find reported"

# --- unreadable storage aborts --- The wrong user reads zero repos, which would look like
# "nothing to do" when it means "could not look".
chmod 000 "$STORAGE"
out=$(DISK_AWARE=0 "$SCRIPT" 2>&1); rc=$?
chmod 755 "$STORAGE"
{ [ "$rc" = 1 ] && grep -q 'cannot read storage dir' <<<"$out" \
    && ! grep -q '# PLAN ' <<<"$out"; } \
  && ok "unreadable storage dir aborts (no empty plan)" \
  || no "unreadable storage aborts (got exit $rc)"

# A quarantine verb is checked against the commands it calls. restore reaches dirname
# through the keep file it writes, and without it restores a repo the next run prunes.
nodirname="$ROOT/nodirname"; path_without "$nodirname" dirname
out=$(PATH="$nodirname" "$SCRIPT" quarantine restore zjunk1 2>&1); rc=$?
{ [ "$rc" = 1 ] && grep -q 'missing required command(s): dirname$' <<<"$out"; } \
  && ok "a quarantine verb names the command it needs and does not half-run" \
  || no "quarantine restore ran without dirname (got exit $rc)"
noiconv="$ROOT/noiconv"; path_without "$noiconv" iconv
out=$(PATH="$noiconv" DISK_AWARE=0 ABS_SIZE_FLOOR_MB=1 "$SCRIPT" 2>&1); rc=$?
{ [ "$rc" = 1 ] && grep -q 'missing required command(s): iconv$' <<<"$out"; } \
  && ok "a scan without iconv stops and names it" \
  || no "a scan ran without iconv, or did not name it (got exit $rc)"
# An iconv that stops at the first non-UTF-8 byte, as BSD's does, keeps only what came before.
mkdir -p "$ROOT/stopiconv"
printf '#!/bin/sh\nLC_ALL=C sed "s/[^ -~].*//"\nexit 1\n' > "$ROOT/stopiconv/iconv"
chmod +x "$ROOT/stopiconv/iconv"
out=$(PATH="$ROOT/stopiconv:$PATH" DISK_AWARE=0 ABS_SIZE_FLOOR_MB=1 "$SCRIPT" 2>&1); rc=$?
{ [ "$rc" = 1 ] && grep -q '^iconv here stops at text that is not UTF-8' <<<"$out"; } \
  && ok "a scan with an iconv that stops at bad bytes stops and says so" \
  || no "a scan ran with an iconv that cuts text short (got exit $rc)"

# --- workers do not need bash on PATH --- A run started as `/nix/store/.../bash rad-prune`
# has bash only by absolute path. The stub's shebang is rewritten because `env bash`
# fails here too.
nobash="$ROOT/nobash"; path_without "$nobash" bash sh rad
realbash=$(command -v bash)
sed "1s|.*|#!$realbash|" "$HERE/rad-stub" > "$nobash/rad"; chmod +x "$nobash/rad"
out=$(PATH="$nobash" RAD="$nobash/rad" DISK_AWARE=0 ABS_SIZE_FLOOR_MB=1 \
      "$realbash" "$SCRIPT" 2>&1); rc=$?
{ [ "$rc" = 0 ] && has "$out" "zjunk1" \
    && ! grep -q 'No such file or directory' <<<"$out"; } \
  && ok "the workers run with bash off PATH" \
  || no "workers need bash on PATH (got exit $rc)"

# --- a walk that read nothing aborts --- A ref walk that dies wholesale leaves every repo
# ageless, the age rules skip them all, and the plan comes out empty.
nolife="$ROOT/nolife"; mkdir -p "$nolife"
cp "$HERE/no-life-xargs-shim" "$nolife/xargs"; chmod +x "$nolife/xargs"
out=$(PATH="$nolife:$PATH" DISK_AWARE=0 ABS_SIZE_FLOOR_MB=1 "$SCRIPT" 2>&1); rc=$?
{ [ "$rc" = 5 ] && grep -q 'with no readable refs\.' <<<"$out" \
    && ! grep -q '# PLAN ' <<<"$out"; } \
  && ok "a scan with no ref dates aborts (no empty plan)" \
  || no "ref-less scan aborts (got exit $rc)"

# --- a fetch still arriving is fresh, not ageless --- A repo dir that exists before its
# refs has no age, and counting it against the blind-scan limit aborts over a busy node.
git init -q --bare "$STORAGE/zinflightfetch"
touch "$STORAGE/zinflightfetch"
out=$(DISK_AWARE=0 ABS_SIZE_FLOOR_MB=1 "$SCRIPT" 2>&1); rc=$?
rm -rf "$STORAGE/zinflightfetch"
{ [ "$rc" = 0 ] && grep -q '^# skipped .*written in the last' <<<"$out" \
  && ! grep -q 'with no readable refs' <<<"$out"; } \
  && ok "a repo with no refs yet counts as freshly written, not as ageless" \
  || no "an in-flight fetch counted against the blind-scan limit (got exit $rc)"

# --- progress shows a share done and time left only once it can stand by them --- One repo
# can cost a thousand times another. The size walk runs calls of 64 repos ending at 2s,
# 4s and 24s: 64 repos is too few to project from, 128 is enough, and the last call's
# 20s is a stall the line must own up to. That needs a fixture of 129 to 192 repos.
[ "$NREPOS" -gt 128 ] && [ "$NREPOS" -le 192 ] || no "the progress test needs 129-192 repos"
slowdu="$ROOT/slowdu"; mkdir -p "$slowdu"
cp "$HERE/slow-du-shim" "$slowdu/du"; chmod +x "$slowdu/du"
PATH="$slowdu:$PATH" RSP_DU_CALLS="$ROOT/du-calls" RSP_DU_SLEEPS="2 2 20" JOBS=1 \
  PROGRESS_SECS=1 RULES=A DISK_AWARE=0 "${NOTTY[@]}" "$SCRIPT" </dev/null >"$ROOT/slow.out" 2>&1
sizes=$(grep '^# \[1/[0-9]*\] sizes  ' "$ROOT/slow.out")
{ grep -qx "# \[1/[0-9]*\] sizes  *64 of $NREPOS repos, [0-9]*s elapsed" <<<"$sizes" \
  && ! grep -E ' sizes +[0-9]{1,2} of ' <<<"$sizes" | grep -qE '%|left'; } \
  && ok "a phase too few repos into its walk shows neither a share done nor a time left" \
  || no "a phase too few repos into its walk projected a time left"
share=$(( 128 * 100 / NREPOS ))
grep -qx "# \[1/[0-9]*\] sizes  *128 of $NREPOS repos ($share%), [0-9]*s elapsed, <10s left" \
     <<<"$sizes" \
  && ok "a phase far enough into its walk shows its share done and a time left" \
  || no "a phase far enough into its walk shows no time left"
grep -qx "# \[1/[0-9]*\] sizes  *128 of $NREPOS repos, [0-9]*s elapsed, last done 1[5-9]s ago" \
     <<<"$sizes" \
  && ok "a phase stuck on one repo says how long instead of a time left" \
  || no "a phase stuck on one repo kept showing a time left"

# --- fail-safe: node down aborts --apply before touching anything ---
out=$(RSP_NODE_DOWN=1 DISK_AWARE=0 ABS_SIZE_FLOOR_MB=1 "$SCRIPT" --apply 2>&1); rc=$?
{ [ "$rc" = 5 ] && ! grep -q '# PLAN ' <<<"$out"; } \
  && ok "node-down aborts --apply (exit 5, no plan)" \
  || no "node-down aborts --apply (got exit $rc)"

# --- apply: non-interactive (cron path) applies; interactive prompt (pty) obeys y/N ---
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
{ grep -qx 'rad:zjunk1' "$RSP_HOME/.stub_block" \
  && grep -qx 'rad:zjunk1' "$RSP_HOME/.stub_unseed"; } \
  && ok "apply calls rad unseed + block on a pruned repo" \
  || no "apply calls unseed+block"

# After moving GiB out of storage, the next question is how to get the disk back.
grep -q 'quarantine delete --all' <<<"$aout" \
  && ok "the DONE line says how to reclaim the disk now" \
  || no "DONE line does not name the reclaim command"

# --- an apply that could block nothing --- The block stops a deleted repo being fetched
# back, so a repo it failed on stays. Every line must then agree with the disk, or a phase
# counting attempts shows the full plan above the warning that none of it happened.
build_fixture; assert_isolated
RSP_BLOCK_FAIL=1 DISK_AWARE=0 ABS_SIZE_FLOOR_MB=1 "${NOTTY[@]}" "$SCRIPT" --apply </dev/null \
  >"$ROOT/blockfail.out" 2>&1
bout=$(cat "$ROOT/blockfail.out")
planned=$(sed -n 's/^# PLAN   prune \([0-9]*\) repo.*/\1/p' <<<"$bout")
kept=1
for r in zjunk1 zbig2 ztwoyr3; do [ -e "$STORAGE/$r" ] || kept=0; done
{ [ -n "$planned" ] && [ "$kept" = 1 ] \
  && grep -qE "^# \[[0-9]+/[0-9]+\] pruning +0 of $planned repos " <<<"$bout" \
  && grep -q "^# WARN $planned of $planned deletions failed" <<<"$bout" \
  && grep -q '^#   WARN block failed, skipping delete: ' <<<"$bout"; } \
  && ok "an apply that blocked nothing deletes nothing and reports 0 of the plan pruned" \
  || no "a failed apply deleted repos or reported the whole plan as pruned"

# The quarantine advice covers this run's repos. A run that quarantined none prints none,
# and above all no delete --all, which would delete earlier runs' repos.
{ grep -q '^# DONE   quarantined 0 repos' <<<"$bout" \
  && ! grep -q 'quarantine delete --all' <<<"$bout"; } \
  && ok "a run that quarantined nothing leaves out the quarantine advice" \
  || no "quarantine advice printed after a run that quarantined nothing"

# --- a quarantine copy that could not be dated --- The purge window runs from the dir's
# date, so a copy that kept the repo's own date starts from one this run did not choose.
# It left storage, so it counts as pruned, but the closing line must not promise it the
# full undo.
build_fixture; assert_isolated
notouch="$ROOT/notouch"; mkdir -p "$notouch"
cp "$HERE/failing-touch-shim" "$notouch/touch"; chmod +x "$notouch/touch"
PATH="$notouch:$PATH" DISK_AWARE=0 ABS_SIZE_FLOOR_MB=1 "${NOTTY[@]}" "$SCRIPT" --apply \
  </dev/null >"$ROOT/undated.out" 2>&1
uout=$(cat "$ROOT/undated.out")
uplanned=$(sed -n 's/^# PLAN   prune \([0-9]*\) repo.*/\1/p' <<<"$uout")
{ [ -n "$uplanned" ] \
  && grep -q "^# DONE   quarantined $uplanned repo" <<<"$uout" \
  && grep -q "^#        $uplanned of them kept their own date, so their window runs from it and may" \
       <<<"$uout" \
  && grep -q 'kept its own date in quarantine' <<<"$uout" \
  && ! grep -q 'deletions failed' <<<"$uout"; } \
  && ok "a quarantine copy that kept its own date is pruned, and its short undo is reported" \
  || no "a copy that kept its own date was reported as recoverable for the full window"

# --- rule G's act, which judges a PERSON --- Blocking is permanent and the peer never
# hears of it, so it needs a human every time: --apply alone must not reach it, and
# --block-peers refuses with nobody to ask.
#
# Each section below sets rule G's thresholds again so it runs alone; one that judged no
# peer would pass these assertions for the wrong reason.
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

# The unattended form, behind two opt-ins because it blocks a peer across every repo with
# nobody reviewing. "Exclusions (never touched)" holds for every action: a kept repo
# keeps the parasite's refs, and the block alone stops anything new landing in it.
build_fixture; assert_isolated
export PARASITE_MIN_REPOS=3 PARASITE_MIN_BYTES=65536 PARASITE_TEXT_MAX_BYTES=4096
echo zpara3 > "$RSP_HOME/keep.txt"
# A block that fails leaves the peer and its refs as they were, for the run after.
out=$(RSP_BLOCK_NODE_FAIL=1 DISK_AWARE=0 ABS_SIZE_FLOOR_MB=1 KEEP_FILE="$RSP_HOME/keep.txt" \
        "${NOTTY[@]}" "$SCRIPT" --block-peers --yes </dev/null 2>&1); rc=$?
{ [ "$rc" = 1 ] && grep -q "WARN block failed, leaving refs alone: $PARA" <<<"$out"; } \
  && ok "a peer block that fails makes the run exit 1" \
  || no "a failed peer block went unreported in the exit code (rc=$rc)"
DISK_AWARE=0 ABS_SIZE_FLOOR_MB=1 KEEP_FILE="$RSP_HOME/keep.txt" "${NOTTY[@]}" \
  "$SCRIPT" --block-peers --yes </dev/null >"$ROOT/bk.out" 2>&1
{ grep -q "$PARA" "$RSP_HOME/.stub_block" 2>/dev/null \
  && grep -q "Blocking $PARA (--yes)" "$ROOT/bk.out" \
  && grep -q "blocked-peer.*$PARA" "$RSP_HOME/prune-audit/"prune-*.log; } \
  && ok "--block-peers --yes blocks without a terminal, says so, and records it" \
  || no "--block-peers --yes did not block the peer rule G named"
{ GIT_DIR="$STORAGE/zpara3" git for-each-ref "refs/namespaces/$PARA/" --format=x 2>/dev/null \
    | grep -q x \
  && ! GIT_DIR="$STORAGE/zpara1" git for-each-ref "refs/namespaces/$PARA/" --format=x \
       2>/dev/null | grep -q x; } \
  && ok "an excluded repo keeps the blocked peer's refs, its neighbours do not" \
  || no "the ref drop ignored the exclusions, or stopped dropping refs anywhere"
rm -f "$RSP_HOME/keep.txt"

# --yes alone must not block peers.
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
  # The peer prompt comes first. "n" then "y" must spare the peer and still apply the plan, so
  # the flag is no blanket licence to block.
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

  # --block-peers stands alone, so dealing with one peer never means pruning the plan. One "y",
  # since without --apply there is no plan prompt.
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
    && grep -q "no repo was pruned" "$ROOT/gsolo.out"; } \
    && ok "--block-peers on its own prunes nothing" \
    || no "--block-peers pruned repos without --apply"
else
  skip "no util-linux script(1); cannot drive the per-peer block prompt through a pty"
fi
unset PARASITE_MIN_REPOS PARASITE_MIN_BYTES PARASITE_TEXT_MAX_BYTES

# --- a failed deletion is never reported as reclaimed disk --- A read-only repo dir fails its
# move, since mv rewrites its "..". The audit log and GiB total come from the plan, so silence
# here would record disk that never freed.
build_fixture; assert_isolated
before=$(ls "$STORAGE" | wc -l)
chmod 555 "$STORAGE"/z*
out=$(DISK_AWARE=0 ABS_SIZE_FLOOR_MB=1 "${NOTTY[@]}" "$SCRIPT" --apply </dev/null 2>&1); rc=$?
chmod 755 "$STORAGE"/z*
after=$(ls "$STORAGE" | wc -l)
{ [ "$rc" = 1 ] && [ "$before" = "$after" ] && grep -q 'WARN quarantine failed' <<<"$out" \
    && grep -qE 'WARN [0-9]+ of [0-9]+ deletions failed' <<<"$out" \
    && grep -q 'DONE   quarantined 0 repos' <<<"$out" \
    && [ "$(tail -1 <<<"$out")" = '# exit 1' ] \
    && [ "$(tail -1 "$(ls "$AUDIT_DIR"/prune-*.log | tail -1)")" = '# exit 1' ]; } \
  && ok "a failed quarantine move is reported, not counted as reclaimed, and exits 1" \
  || no "failed quarantine reported (rc=$rc)"
# The failed run's blocks are its own, so the run that later removes those repos must not
# record them as somebody else's, or the undo never lifts them.
grep -q '^# prune-failed: rad:zjunk1$' "$AUDIT_DIR"/prune-*.log 2>/dev/null; failed_logged=$?
# A middle run whose blocks fail plans zjunk1 again and must carry that line forward.
mid=$(RSP_UNSEED_FAIL=1 RSP_BLOCK_FAIL=1 DISK_AWARE=0 ABS_SIZE_FLOOR_MB=1 "${NOTTY[@]}" \
        "$SCRIPT" --apply </dev/null 2>&1); midrc=$?
grep -q 'WARN block failed, skipping delete: zjunk1' <<<"$mid" || midrc=bad
out=$(DISK_AWARE=0 ABS_SIZE_FLOOR_MB=1 "${NOTTY[@]}" "$SCRIPT" --apply </dev/null 2>&1); rc=$?
last=$(ls "$AUDIT_DIR"/prune-*.log | tail -1)
{ [ "$failed_logged" = 0 ] && [ "$midrc" = 1 ] && [ "$rc" = 0 ] && [ ! -e "$STORAGE/zjunk1" ] \
    && grep -q '^zjunk1' "$last" && ! grep -q '^# was-blocked: rad:zjunk1$' "$last"; } \
  && ok "a block left by a failed prune stays rad-prune's own" \
  || no "a failed prune's block was recorded as somebody else's (rc=$rc, middle run $midrc)"

# --- an audit log is never overwritten --- Logs are named by the second, and a log is its
# run's only record of what it pruned. The first name this run tries is taken.
build_fixture; assert_isolated
mkdir -p "$AUDIT_DIR"
echo "# another run" > "$AUDIT_DIR/prune-20300101T000000Z.log"
printf '%s\n' 20300101T000000Z 20300101T000001Z > "$ROOT/stamps"
fixdate="$ROOT/fixdate"; mkdir -p "$fixdate"
cp "$HERE/fixed-date-shim" "$fixdate/date"; chmod +x "$fixdate/date"
out=$(PATH="$fixdate:$PATH" RSP_STAMPS="$ROOT/stamps" DISK_AWARE=0 ABS_SIZE_FLOOR_MB=1 \
        "${NOTTY[@]}" "$SCRIPT" --apply </dev/null 2>&1); rc=$?
{ [ "$rc" = 0 ] && [ "$(cat "$AUDIT_DIR/prune-20300101T000000Z.log")" = "# another run" ] \
    && grep -q '^# plan=' "$AUDIT_DIR/prune-20300101T000001Z.log"; } \
  && ok "a run whose log name is taken waits for a free one" \
  || no "a run wrote over another run's audit log (rc=$rc)"

# --- an audit dir the run cannot write stops it before the scan --- A block with no log record
# is one the undo cannot tell from somebody else's. A file where the dir should be defeats
# mkdir -p even for root.
build_fixture; assert_isolated
: > "$RSP_HOME/.stub_block"
rm -rf "$AUDIT_DIR"; : > "$AUDIT_DIR"
out=$(DISK_AWARE=0 ABS_SIZE_FLOOR_MB=1 timeout 120 "${NOTTY[@]}" "$SCRIPT" \
        --apply </dev/null 2>&1); rc=$?
pout=$(PARASITE_MIN_REPOS=3 PARASITE_MIN_BYTES=65536 PARASITE_TEXT_MAX_BYTES=4096 \
         DISK_AWARE=0 ABS_SIZE_FLOOR_MB=1 timeout 120 "${NOTTY[@]}" "$SCRIPT" --block-peers --yes \
         </dev/null 2>&1); prc=$?
{ [ "$rc" = 1 ] && grep -q 'cannot write the audit dir' <<<"$out" && [ -d "$STORAGE/zjunk1" ] \
    && [ "$prc" = 1 ] && grep -q 'cannot write the audit dir' <<<"$pout" \
    && [ ! -s "$RSP_HOME/.stub_block" ]; } \
  && ok "an audit dir that cannot be written stops --apply and --block-peers before any block" \
  || no "an unwritable audit dir let a run block or prune (rc=$rc, --block-peers rc=$prc)"

# --- one changing run at a time --- A second changing run could delete the copy the first just
# quarantined. Without flock the run goes ahead and says it is not kept apart.
build_fixture; assert_isolated
mkdir -p "$AUDIT_DIR/quarantine/zlockq"; touch -d '30 days ago' "$AUDIT_DIR/quarantine/zlockq"
: > "$RSP_HOME/.stub_block"
if command -v flock >/dev/null 2>&1; then
  exec 8>> "$AUDIT_DIR/run.lock"; flock -n 8
  out=$(DISK_AWARE=0 "${NOTTY[@]}" "$SCRIPT" --apply --yes </dev/null 2>&1); rc=$?
  qout=$("$SCRIPT" quarantine purge 2>&1); qrc=$?
  exec 8>&-
  { [ "$rc" = 5 ] && [ "$qrc" = 5 ] && grep -qF "holds $AUDIT_DIR/run.lock" <<<"$out" \
      && grep -qF "holds $AUDIT_DIR/run.lock" <<<"$qout" \
      && [ -d "$STORAGE/zjunk1" ] && [ -d "$AUDIT_DIR/quarantine/zlockq" ] \
      && [ ! -s "$RSP_HOME/.stub_block" ]; } \
    && ok "a run that would change storage or the quarantine stops while another holds the lock" \
    || no "a second run went ahead under another's lock (--apply rc=$rc, purge rc=$qrc)"
else
  skip "the run lock (flock is not installed)"
fi
path_without "$ROOT/noflock" flock
qout=$(PATH="$ROOT/noflock" "$SCRIPT" quarantine purge 2>&1); qrc=$?
{ [ "$qrc" = 0 ] && grep -q 'WARN flock is not installed' <<<"$qout" \
    && [ ! -e "$AUDIT_DIR/quarantine/zlockq" ]; } \
  && ok "without flock a run says it is not kept apart from another, and goes ahead" \
  || no "a missing flock stopped the run, or went unsaid (rc=$qrc)"

# --- a block a failed removal left is lifted once the repo is spared --- The repo never left
# storage, and keep.txt spares a repo without unblocking it, so nothing else lifts it.
build_fixture; assert_isolated
undo_log 20000101T000000Z '2026-01-01T00:00:00Z  version=0.9.0  pressure=0%' <<EOF
$(undo_row zjunk1 1048576 junk-name)
$(undo_row zbar8 1048576 junk-name)
$(undo_row zbig2 1048576 size-outlier)
$(undo_row zpin6 1048576 denied)
$(undo_row zpriv7 1048576 junk-name)
# prune-failed: rad:zjunk1
# prune-failed: rad:zbar8
# prune-failed: rad:zbig2
# prune-failed: rad:zpin6
# prune-failed: rad:zpriv7
EOF
# zcode4's verdict is one this release withdrew.
undo_log 19990101T000000Z '1999-01-01T00:00:00Z  pressure=0%' <<EOF
$(undo_row zcode4 1048576 link-farm)
# prune-failed: rad:zcode4
EOF
# UNDO_LIFT names LIFTONE as wrongly pruned for its junk name, which it no longer has.
LIFTONE=z26kA476mDX7H1GWiUfCqTWPKLa6i
cp -a "$STORAGE/zcode7" "$STORAGE/$LIFTONE"
printf '%s\thonestapp\t5\tpublic\t0\t90\t2000\ta real project\n' "$LIFTONE" >> "$RSP_MANIFEST"
undo_log 19980101T000000Z '1998-01-01T00:00:00Z  pressure=0%' <<EOF
$(undo_row "$LIFTONE" 1048576 junk-name)
# prune-failed: rad:$LIFTONE
EOF
undo_block zjunk1 zbar8 zbig2 zpin6 zpriv7 zcode4 "$LIFTONE"
echo zjunk1 > "$AUDIT_DIR/keep.txt"
# The log names no delegates for zpriv7, so the repo's own identity document has to.
echo "did:key:$(dlg zpriv7)" > "$AUDIT_DIR/deny.txt"
# RULES=A leaves zbig2's rule out, so this run does not plan it either.
out=$(RULES=A DISK_AWARE=0 "${NOTTY[@]}" "$SCRIPT" --apply </dev/null 2>&1); rc=$?
log=$(ls "$AUDIT_DIR"/prune-2*Z.log | tail -1)
{ [ "$rc" = 0 ] && [ -d "$STORAGE/zjunk1" ] \
    && grep -q '^# unblocked: rad:zjunk1 why=prune-failed reason=junk-name ' "$log" \
    && grep -qx 'unseed rad:zjunk1' "$RSP_HOME/.stub_policy"; } \
  && ok "a kept repo a failed removal left blocked has the block lifted" \
  || no "a failed removal's block outlived the verdict (rc=$rc)"
grep -q '^# unblocked: rad:zcode4 why=prune-failed reason=link-farm ' "$log" \
  && ok "a failed removal under a withdrawn verdict has the block lifted" \
  || no "a failed removal's block outlived its withdrawn verdict"
grep -q "^# unblocked: rad:$LIFTONE why=prune-failed reason=junk-name " "$log" \
  && ok "a failed removal of a repo UNDO_LIFT names has the block lifted" \
  || no "a failed removal's block outlived its UNDO_LIFT entry"
{ [ ! -e "$STORAGE/zbar8" ] && ! grep -q 'unblocked: rad:zbar8' "$log"; } \
  && ok "a failed removal planned again keeps its block" \
  || no "the block was lifted on a repo this run prunes"
# Missing from the plan is no withdrawn verdict. A block the deny list made, by repo or by
# delegate, is the deny list's to keep.
{ [ -d "$STORAGE/zbig2" ] && ! grep -q 'unblocked: rad:zbig2' "$log" \
    && ! grep -q 'unblocked: rad:zpin6' "$log" && ! grep -q 'unblocked: rad:zpriv7' "$log"; } \
  && ok "a failed removal nothing spares, or that the deny list made, keeps its block" \
  || no "a block was lifted on a repo merely missing from the plan, or denied"

# --- keep.txt is read whole or not at all --- Every id on a line counts. An unreadable list
# stops the run, since read as empty it lets every repo on it be pruned again.
build_fixture; assert_isolated
mkdir -p "$AUDIT_DIR"
printf 'zjunk1 rad:zbar8  # both\n- zbig2\n' > "$AUDIT_DIR/keep.txt"
out=$(run)
{ ! has "$out" zjunk1 && ! has "$out" zbar8 && ! has "$out" zbig2 \
    && grep -q 'neither a repo id nor an identity' <<<"$out"; } \
  && ok "every id on a keep.txt line keeps its repo, and a stray token is named" \
  || no "keep.txt kept only the first id on a line, or dropped a token silently"
if [ "$(id -u)" != 0 ]; then
  chmod 000 "$AUDIT_DIR/keep.txt"
  out=$(DISK_AWARE=0 "${NOTTY[@]}" "$SCRIPT" --apply --yes </dev/null 2>&1); rc=$?
  chmod 644 "$AUDIT_DIR/keep.txt"
  { [ "$rc" = 5 ] && [ -d "$STORAGE/zjunk1" ] && grep -q 'cannot read .*keep.txt' <<<"$out"; } \
    && ok "an unreadable keep.txt stops the run before anything is pruned" \
    || no "an unreadable keep.txt was read as empty (rc=$rc)"
else
  skip "running as root, which reads a mode-000 file anyway"
fi

# --- a quarantine the run cannot write stops it before the scan --- Repos are blocked before
# they move, so carrying on would leave the plan blocked and still in storage, and its log
# would count as pruned next run. A file where the quarantine goes defeats mkdir even for root.
build_fixture; assert_isolated
before=$(ls "$STORAGE" | wc -l)
mkdir -p "$AUDIT_DIR"; : > "$AUDIT_DIR/quarantine"
: > "$RSP_HOME/.stub_unseed"; : > "$RSP_HOME/.stub_block"
out=$(DISK_AWARE=0 ABS_SIZE_FLOOR_MB=1 "${NOTTY[@]}" "$SCRIPT" --apply </dev/null 2>&1); rc=$?
{ [ "$rc" = 1 ] && grep -q 'cannot write the quarantine' <<<"$out" \
    && [ "$(ls "$STORAGE" | wc -l)" = "$before" ] \
    && [ ! -s "$RSP_HOME/.stub_unseed" ] && [ ! -s "$RSP_HOME/.stub_block" ] \
    && ! ls "$AUDIT_DIR"/prune-*.log >/dev/null 2>&1; } \
  && ok "a quarantine that cannot be made stops the run before any repo is blocked" \
  || no "the run went on without a quarantine (rc=$rc)"
# A quarantine that exists but is read-only passes mkdir -p. Root writes it regardless.
if [ "$(id -u)" != 0 ]; then
  rm -f "$AUDIT_DIR/quarantine"; mkdir "$AUDIT_DIR/quarantine"; chmod 555 "$AUDIT_DIR/quarantine"
  out=$(DISK_AWARE=0 ABS_SIZE_FLOOR_MB=1 "${NOTTY[@]}" "$SCRIPT" --apply </dev/null 2>&1); rc=$?
  chmod 755 "$AUDIT_DIR/quarantine"
  { [ "$rc" = 1 ] && grep -q 'cannot write the quarantine' <<<"$out" \
      && [ ! -s "$RSP_HOME/.stub_block" ]; } \
    && ok "a read-only quarantine stops the run before any repo is blocked" \
    || no "the run went on with a read-only quarantine (rc=$rc)"
else
  skip "running as root, which writes a read-only quarantine anyway"
fi
# A storage dir the run can read but not write fails every repo the same way.
chmod 555 "$STORAGE"
out=$(DISK_AWARE=0 ABS_SIZE_FLOOR_MB=1 "${NOTTY[@]}" "$SCRIPT" --apply </dev/null 2>&1); rc=$?
chmod 755 "$STORAGE"
if [ "$(id -u)" != 0 ]; then
  { [ "$rc" = 1 ] && grep -q 'cannot write storage dir' <<<"$out" \
      && [ ! -s "$RSP_HOME/.stub_block" ]; } \
    && ok "a read-only storage dir stops --apply before any repo is blocked" \
    || no "--apply went on with a read-only storage dir (rc=$rc)"
else
  skip "running as root, which writes a read-only storage dir anyway"
fi
# Read as off, a typo meant as "on" would delete outright.
out=$(QUARANTINE=yes DISK_AWARE=0 ABS_SIZE_FLOOR_MB=1 "${NOTTY[@]}" "$SCRIPT" --apply \
        </dev/null 2>&1); rc=$?
{ [ "$rc" = 2 ] && grep -q 'QUARANTINE must be 0 or 1' <<<"$out" \
    && [ "$(ls "$STORAGE" | wc -l)" = "$before" ]; } \
  && ok "a mistyped QUARANTINE stops the run instead of deleting outright" \
  || no "QUARANTINE=yes was read as off (rc=$rc)"

# --- quarantine --- The floor-0 verdicts may prune the network's last known copy, so
# re-fetching is no undo for them. QUARANTINE=0 has no undo, so it must delete exactly the
# plan.
build_fixture; assert_isolated
Q="$RSP_HOME/prune-audit/quarantine"
DISK_AWARE=0 ABS_SIZE_FLOOR_MB=1 QUARANTINE=0 "${NOTTY[@]}" "$SCRIPT" --apply \
  </dev/null >/dev/null 2>&1
kept=1
for r in zfresh4 zpin6 zpriv7 zown22 zbwid9 zfews5 zdecoy1 zenum1; do
  [ -e "$STORAGE/$r" ] || kept=0
done
{ [ ! -e "$STORAGE/zjunk1" ] && [ ! -e "$Q/zjunk1" ] && [ "$kept" = 1 ]; } \
  && ok "QUARANTINE=0 deletes the plan outright and nothing outside it" \
  || no "QUARANTINE=0 parked a copy, or deleted a repo outside the plan"

# The quarantine subcommands let an operator act on one wrong verdict after its run is over,
# without hand-moving directories under a live node's storage.
build_fixture; assert_isolated
Q="$RSP_HOME/prune-audit/quarantine"
DISK_AWARE=0 ABS_SIZE_FLOOR_MB=1 "${NOTTY[@]}" "$SCRIPT" --apply </dev/null >/dev/null 2>&1
{ [ ! -e "$STORAGE/zjunk1" ] && [ -d "$Q/zjunk1" ] \
  && GIT_DIR="$Q/zjunk1" git rev-parse --verify -q master >/dev/null 2>&1; } \
  && ok "a pruned repo is moved to quarantine intact, not destroyed" \
  || no "a pruned repo was not recoverable from quarantine"
out=$("$SCRIPT" quarantine list 2>&1)
{ grep -qE '^zjunk1 .* junk-name +test-old$' <<<"$out" && grep -q 'HELD' <<<"$out"; } \
  && ok "quarantine list names what a past run pruned, why, and the repo's name" \
  || no "quarantine list did not show the quarantined repo, why it went, or its name"

# Restoring puts back the directory, the block policy and the verdict, or the next run plans
# the repo again. rad seed only rewrites an existing policy row's scope, so on a blocked repo
# it succeeds and changes nothing. rad unseed deletes the row whatever its policy, which
# drops the block, and exists on every rad version.
# Both stubs are emptied first so the prune's own calls cannot pass this.
: > "$RSP_HOME/.stub_unseed"; : > "$RSP_HOME/.stub_seed"
# The keep list's last line has no newline, as some editors save it.
mkdir -p "$RSP_HOME/prune-audit"; printf 'zkeepme' > "$RSP_HOME/prune-audit/keep.txt"
out=$("$SCRIPT" quarantine restore zjunk1 2>&1)
{ [ -d "$STORAGE/zjunk1" ] && [ ! -e "$Q/zjunk1" ] \
  && GIT_DIR="$STORAGE/zjunk1" git rev-parse --verify -q master >/dev/null 2>&1 \
  && grep -qx 'rad:zjunk1' "$RSP_HOME/.stub_unseed" \
  && grep -qx 'rad:zjunk1' "$RSP_HOME/.stub_seed" \
  && grep -qxE 'zjunk1  # restored [0-9]{4}-[0-9]{2}-[0-9]{2}, was junk-name test-old' \
       "$RSP_HOME/prune-audit/keep.txt" \
  && grep -qx 'zkeepme' "$RSP_HOME/prune-audit/keep.txt" \
  && [ "$(head -c1 "$RSP_HOME/prune-audit/keep.txt")" = z ]; } \
  && ok "quarantine restore puts the repo back, clears its block and keeps it" \
  || no "quarantine restore left the repo blocked, gone, or still condemned"

grep -q 'zjunk1' <<<"$(DISK_AWARE=0 ABS_SIZE_FLOOR_MB=1 run)" \
  && no "a restored repo was planned for pruning all over again" \
  || ok "a repo on the keep list is left out of the next plan"

# quarantine delete frees one repo's disk before its window runs out.
build_fixture; assert_isolated
Q="$RSP_HOME/prune-audit/quarantine"
mkdir -p "$Q/zdead1" "$Q/zdead2"
"$SCRIPT" quarantine delete zdead1 >/dev/null 2>&1
{ [ ! -e "$Q/zdead1" ] && [ -d "$Q/zdead2" ]; } \
  && ok "quarantine delete removes exactly the repo it was given" \
  || no "quarantine delete deleted the wrong repo, or none"

# A kept repo waits in the quarantine for the next run to put it back, so --all leaves it.
mkdir -p "$Q/zkeptd3"
echo zkeptd3 >> "$RSP_HOME/prune-audit/keep.txt"
"$SCRIPT" quarantine delete --all >/dev/null 2>&1
{ [ ! -e "$Q/zdead2" ] && [ -d "$Q/zkeptd3" ]; } \
  && ok "quarantine delete --all empties it, except a repo keep.txt lists" \
  || no "quarantine delete --all left a repo behind, or deleted a kept one"

# Every verb builds a path from its argument, so one that is no repo id must never reach rm or
# mv.
build_fixture; assert_isolated
Q="$RSP_HOME/prune-audit/quarantine"
canary="$ROOT/canary"; mkdir -p "$canary"
out=$("$SCRIPT" quarantine delete "../../../../../..${canary}" 2>&1 || true)
{ [ -d "$canary" ] && grep -q 'not a repo id' <<<"$out"; } \
  && ok "a quarantine verb refuses an argument that is not a repo id" \
  || no "a path argument reached rm through a quarantine verb"

# purge applies a run's window on demand. A copy is due three hours early, so a weekly run a
# few seconds or a daylight-saving hour early still purges it. zedgeq1 is two hours short,
# zfreshq1 four.
build_fixture; assert_isolated
Q="$RSP_HOME/prune-audit/quarantine"
mkdir -p "$Q/zexpq1" "$Q/zedgeq1" "$Q/zfreshq1"; touch -d "40 days ago" "$Q/zexpq1"
week=$(( $(date +%s) - 7*86400 ))
touch -d "@$(( week + 7200 ))" "$Q/zedgeq1"; touch -d "@$(( week + 14400 ))" "$Q/zfreshq1"
# A repo in keep.txt is a person's word to keep it, so its window never runs out.
mkdir -p "$Q/zkeptq1"; touch -d "40 days ago" "$Q/zkeptq1"
printf 'rad:zkeptq1  # a person keeps it\n' > "$RSP_HOME/prune-audit/keep.txt"
listed=$("$SCRIPT" quarantine list 2>&1)
out=$("$SCRIPT" quarantine purge 2>&1)
{ [ ! -e "$Q/zexpq1" ] && [ ! -e "$Q/zedgeq1" ] && [ -d "$Q/zfreshq1" ] \
  && grep -q 'purged 2 repo' <<<"$out"; } \
  && ok "quarantine purge deletes what is past its window, less 3 hours, and nothing else" \
  || no "quarantine purge deleted the wrong repos"
{ [ -d "$Q/zkeptq1" ] && grep -qE '^zkeptq1 .* kept +-$' <<<"$listed"; } \
  && ok "quarantine purge keeps a repo in keep.txt past its window, and list says so" \
  || no "quarantine purge deleted a repo in keep.txt, or list called it due"

# --- the run cache --- Rules F and G read every repo's contents and reuse their per-repo
# output between runs. The danger is a verdict resting on evidence that is no longer true.
build_fixture; assert_isolated
first=$(DISK_AWARE=0 run)
grep -qE "^zmediaone .*media-dump" <<<"$first" \
  || no "the cold run never condemned zmediaone, so the cache checks below are moot"
second=$(DISK_AWARE=0 run 2>&1)
{ grep -q 'cache  media reuses' <<<"$second" \
  && [ "$(grep -c 'media-dump' <<<"$first")" = "$(grep -c 'media-dump' <<<"$second")" ]; } \
  && ok "a second run reuses the first run's reading and plans the same repos" \
  || no "the warm cache changed the plan, or was never used"

# A repo that no longer looks like a dump must not be pruned on last week's reading.
e_tree zmediaone 60 master "clip.mp4:40000:mp4" "README.md:9000"
grep -qE "^zmediaone .*media-dump" <<<"$(DISK_AWARE=0 run)" \
  && no "a repo was condemned on cached evidence it no longer matches" \
  || ok "a repo that changed is read again, not judged on the cached reading"

# A threshold the operator has just tuned must not leave last week's verdicts standing.
build_fixture; assert_isolated
DISK_AWARE=0 run >/dev/null
out=$(DISK_AWARE=0 MEDIA_MIN_BYTES=999999999 "${NOTTY[@]}" "$SCRIPT" </dev/null 2>&1)
{ grep -q 'cache  cold' <<<"$out" && ! has "$out" "zmediaone"; } \
  && ok "changing a threshold drops the whole cache" \
  || no "a tuned threshold reused verdicts measured under the old one"

# A cold start drops the keys of EVERY cached rule. Stamping the fingerprint per rule would
# leave a run that dies between two rules looking warm with half its keys from old settings.
build_fixture; assert_isolated
CACHEDIR="$RSP_HOME/prune-audit/cache"
DISK_AWARE=0 run >/dev/null
[ -f "$CACHEDIR/keys-media" ] \
  || no "the first run wrote no media keys, so the next check is moot"
DISK_AWARE=0 RULES=G MEDIA_MIN_BYTES=999999999 "${NOTTY[@]}" "$SCRIPT" \
  </dev/null >/dev/null 2>&1
[ ! -f "$CACHEDIR/keys-media" ] \
  && ok "a cold start drops the keys of the rules it does not run, not just its own" \
  || no "a rule that sat out a cold run kept keys measured under the settings that changed"

# STORAGE is operator-supplied and the already-answered list is built from it. A '#' in it ends
# sed's delimiter, re-walking every repo and pasting its cached rows beside fresh ones.
build_fixture; assert_isolated
odd="$RSP_HOME/st#or&age"
cp -r "$STORAGE" "$odd"
DISK_AWARE=0 STORAGE="$odd" "${NOTTY[@]}" "$SCRIPT" </dev/null >/dev/null 2>&1
out=$(DISK_AWARE=0 STORAGE="$odd" "${NOTTY[@]}" "$SCRIPT" </dev/null 2>&1)
{ ! grep -q 'unknown option' <<<"$out" && grep -q 'cache  media reuses' <<<"$out"; } \
  && ok "a storage path holding shell and sed metacharacters still caches correctly" \
  || no "a '#' in STORAGE broke the already-read list"

# Rule G judges a peer across all storage, adding cached and fresh rows. A repo counted twice,
# or banked from an unfinished walk, moves the byte totals the accusation rests on.
build_fixture; assert_isolated
export PARASITE_MIN_REPOS=3 PARASITE_MIN_BYTES=65536 PARASITE_TEXT_MAX_BYTES=4096
cold=$(DISK_AWARE=0 run)
warm=$(DISK_AWARE=0 run 2>&1)
{ grep -q 'cache  peer reuses' <<<"$warm" \
  && grep -q "REVIEW 1 parasite peer the" <<<"$cold" \
  && [ "$(grep -c 'REVIEW 1 parasite peer the' <<<"$warm")" = 1 ]; } \
  && ok "a warm run reaches rule G's verdict from cached rows unchanged" \
  || no "reusing rule G's reading changed which peers it accused"
unset PARASITE_MIN_REPOS PARASITE_MIN_BYTES PARASITE_TEXT_MAX_BYTES

# The window runs from when the repo ARRIVED in quarantine. mv keeps the source mtime, and
# rules B and C pick repos untouched for 90 to 730 days, so their copy would purge on the next
# run. zrot1 is the stale fixture.
build_fixture; assert_isolated
Q="$RSP_HOME/prune-audit/quarantine"
# Age the dir itself, or mv carries a fresh mtime and the check cannot tell fixed from broken.
touch -d "200 days ago" "$STORAGE/zrot1"
DISK_AWARE=0 ABS_SIZE_FLOOR_MB=1 STALE_YEARS_DAYS=30 "${NOTTY[@]}" "$SCRIPT" --apply \
  </dev/null >/dev/null 2>&1
[ -d "$Q/zrot1" ] || no "the stale fixture never reached quarantine, so the next check is moot"
out=$(DISK_AWARE=0 ABS_SIZE_FLOOR_MB=1 STALE_YEARS_DAYS=30 "${NOTTY[@]}" "$SCRIPT" --apply \
      </dev/null 2>&1)
{ [ -d "$Q/zrot1" ] && ! grep -q 'purged' <<<"$out"; } \
  && ok "a repo untouched for years still gets its full quarantine window" \
  || no "quarantine measured the window from the repo's own mtime, so it purged immediately"

# --- free space that something outside storage took --- Pressure reads one sample of free
# space, so a run warns when it fell by far more than storage and the quarantine grew. A last
# line with free_gb=99999 is a drop; free_gb=0 is none.
build_fixture; assert_isolated
calm_disk="DISK_AWARE=1 PRESSURE_RELAX_PCT=0 PRESSURE_RELAX_GB=0 PRESSURE_CRIT_PCT=0"
calm_disk="$calm_disk PRESSURE_CRIT_GB=0 RULES=AB"
mkdir -p "$AUDIT_DIR"
fresh=$(date -u -d "2 days ago" +%Y-%m-%dT%H:%M:%SZ)
printf '%s\tdeleted=0\tfree_gb=99999.0\tused_gb=0.0\taudit=x.log\n' "$fresh" \
  > "$AUDIT_DIR/history.log"
dropped=$(env $calm_disk "$SCRIPT" 2>&1)
printf '%s\tdeleted=0\tfree_gb=0.0\tused_gb=0.0\taudit=x.log\n' "$fresh" \
  > "$AUDIT_DIR/history.log"
steady=$(env $calm_disk "$SCRIPT" 2>&1)
# A month-old line is no baseline: logs and caches outside storage grow that much on their own.
printf '%s\tdeleted=0\tfree_gb=99999.0\tused_gb=0.0\taudit=x.log\n' \
  "$(date -u -d "30 days ago" +%Y-%m-%dT%H:%M:%SZ)" > "$AUDIT_DIR/history.log"
stale=$(env $calm_disk "$SCRIPT" 2>&1)
env $calm_disk "${NOTTY[@]}" "$SCRIPT" --apply </dev/null >/dev/null 2>&1
{ grep -q "WARN free space fell from 99999.0 to .* since $fresh," <<<"$dropped" \
  && ! grep -q 'WARN free space fell' <<<"$steady" \
  && ! grep -q 'WARN free space fell' <<<"$stale" \
  && tail -1 "$AUDIT_DIR/history.log" \
     | grep -qE $'\taudit=prune-[^\t]+\tfree_gb=[0-9.]+\tused_gb=[0-9.]+$'; } \
  && ok "a run records free space and warns when something outside storage took it" \
  || no "free space that left from outside storage went unrecorded or unwarned"
# Rule B waited in that run. If its log said B was on, the ratchet would read the week as B
# pruning nothing and pull its usual down.
grep -q '  rules=A$' "$(ls "$AUDIT_DIR"/prune-*.log | tail -1)" \
  && ok "a run records a rule waiting for disk pressure as not on" \
  || no "a waiting rule was recorded as on, a zero sample for the ratchet"

# --- pressure counts what the run's own purge frees --- The fake df shows a 10 MB disk with 1
# MB free. A 3 MB copy due out of the quarantine lifts it past the 2 MB relaxed threshold, so B
# and C wait. A df that prints nothing stops the run, since full pressure would empty the
# quarantine.
build_fixture; assert_isolated
fakedf="$ROOT/fakedf"; mkdir -p "$fakedf"
printf '#!/bin/sh\necho "Filesystem 1024-blocks Used Available Capacity Mounted"\n%s\n' \
  'echo "fake 10240 9240 1000 90% /"' > "$fakedf/df"
chmod +x "$fakedf/df"
small="DISK_AWARE=1 PRESSURE_RELAX_PCT=20 PRESSURE_RELAX_GB=0 PRESSURE_CRIT_PCT=0"
small="$small PRESSURE_CRIT_GB=0"
Q="$RSP_HOME/prune-audit/quarantine"
squeezed=$(env PATH="$fakedf:$PATH" $small "$SCRIPT" 2>&1)
mkdir -p "$Q/zdueq1"; head -c 3000000 /dev/zero > "$Q/zdueq1/pack"
touch -d "10 days ago" "$Q/zdueq1"
relieved=$(env PATH="$fakedf:$PATH" $small "$SCRIPT" 2>&1)
{ ! grep -q 'B size .*waiting' <<<"$squeezed" \
  && grep -q 'B size .*waiting: no disk pressure$' <<<"$relieved" \
  && grep -q '^# disk   .*GB due out of quarantine' <<<"$relieved"; } \
  && ok "pressure counts the quarantine a run is about to purge as free" \
  || no "a copy due out of the quarantine left the disk under pressure"
printf '#!/bin/sh\nexit 1\n' > "$fakedf/df"
out=$(env PATH="$fakedf:$PATH" DISK_AWARE=1 "${NOTTY[@]}" "$SCRIPT" --apply --yes </dev/null 2>&1)
rc=$?
{ [ "$rc" = 5 ] && [ -d "$Q/zdueq1" ] && grep -q 'cannot read the size of the disk' <<<"$out"; } \
  && ok "a disk whose size cannot be read stops the run, quarantine untouched" \
  || no "an unreadable disk size read as full pressure (rc=$rc)"

# A caught-up seed has an empty plan every week, so the purge runs then too, or quarantined
# disk never comes back.
build_fixture; assert_isolated
Q="$RSP_HOME/prune-audit/quarantine"
mkdir -p "$Q/zoldquar2"; touch -d "40 days ago" "$Q/zoldquar2"
out=$(DISK_AWARE=0 RULES='' "${NOTTY[@]}" "$SCRIPT" --apply </dev/null 2>&1)
{ [ ! -e "$Q/zoldquar2" ] && grep -q 'nothing to prune' <<<"$out"; } \
  && ok "an empty plan still purges quarantine past its window" \
  || no "a run with nothing to prune left expired quarantine on disk"

# RULES= set but empty means NO rules. Read as unset it would run every rule.
{ ! grep -qE '^z' <<<"$(RULES='' run)" && has "$(run)" "zjunk1"; } \
  && ok "RULES= means no rules, not the default set" \
  || no "an empty RULES fell back to running every rule"

# At the critical threshold the disk cannot afford recovery copies, so the whole quarantine
# goes, window or not. keep.txt still holds.
build_fixture; assert_isolated
Q="$RSP_HOME/prune-audit/quarantine"
mkdir -p "$Q/zfreshquar" "$Q/zkeptquar"
echo zkeptquar > "$RSP_HOME/prune-audit/keep.txt"
out=$(DISK_AWARE=1 PRESSURE_CRIT_PCT=100 PRESSURE_CRIT_GB=999999 ABS_SIZE_FLOOR_MB=1 \
        PRESSURE_RELAX_PCT=1 PRESSURE_RELAX_GB=0 "${NOTTY[@]}" "$SCRIPT" --apply </dev/null 2>&1)
{ [ ! -e "$Q/zfreshquar" ] && grep -q 'emptied the whole quarantine' <<<"$out"; } \
  && ok "a critical disk empties the whole quarantine, window or not" \
  || no "quarantine held disk hostage at the critical free-space threshold"
[ -d "$Q/zkeptquar" ] \
  && ok "a critical disk leaves a repo in keep.txt in the quarantine" \
  || no "a critical disk deleted a quarantined repo keep.txt keeps"
# The critical threshold here sits above the relaxed one, and the run must still act, and say
# so, at full pressure.
{ grep -q ' pressure 100% ' <<<"$out" && grep -q 'WARN the relaxed free-space threshold' <<<"$out"; } \
  && ok "a critical disk is full pressure even with the free-space thresholds inverted" \
  || no "the banner said less than full pressure while the quarantine was emptied"

# keep.txt is hand-written, sometimes on Windows, so a byte-order mark must not cost its first
# id its protection. A repo's name and description are its delegates' text, so an escape
# sequence in either must not reach the terminal.
build_fixture; assert_isolated
printf '\xef\xbb\xbfzmediaone\n' > "$RSP_HOME/keep.txt"
sed -i "s/^zmediazip\t[^\t]*/zmediazip\tevil$(printf '\033')[2J$(printf '\302\233')name/" \
  "$RSP_MANIFEST"
out=$(KEEP_FILE="$RSP_HOME/keep.txt" "$SCRIPT" 2>&1); rc=$?
rm -f "$RSP_HOME/keep.txt"
{ [ "$rc" = 0 ] && grep -qE "^zmediazip " <<<"$out" && ! has "$out" "zmediaone"; } \
  && ok "a keep list saved with a byte-order mark still keeps its first line" \
  || no "a byte-order mark cost the first repo in keep.txt its protection"
{ grep -qE "^zmediazip .*evil\[2Jname" <<<"$out" && ! grep -q $'\033' <<<"$out"; } \
  && ok "a control character in a repo's name never reaches the terminal" \
  || no "an escape sequence in a repo name reached the operator's terminal"

# rad prints a description as is, so a line break in it ends the row and what follows reads as
# rows. zbatchodd's forges a junk name for zcode7, and rows for three flatten-batch members
# whose own descriptions change, so dropping them would leave the rest agreeing. Rows for repos
# outside storage agree with the batch. znodesc*'s rows say "local" for visibility, as rad does
# for a repo this node does not seed, and their head must not read as a description all nine
# share.
build_fixture; assert_isolated
forge(){   # $1 = the description zbatchodd gets, then rid=description pairs for others
  local d=$1; shift
  FORGED=$d PAIRS="$*" awk -F'\t' -v OFS='\t' '
    BEGIN { n = split(ENVIRON["PAIRS"], p, " ")
            for (i = 1; i <= n; i++) { split(p[i], kv, "="); desc[kv[1]] = kv[2] } }
    $1 == "zbatchodd" { $8 = ENVIRON["FORGED"] }
    ($1 in desc)      { $8 = desc[$1] }
    $1 ~ /^znodesc/   { $4 = "local" }
    { print }' "$RSP_MANIFEST" > "$RSP_MANIFEST.new" && mv "$RSP_MANIFEST.new" "$RSP_MANIFEST"
}
rows="x\n| 0a1b2c3d4e5f rad:zcode7 public abc1234 y |"
for i in 1 2 3; do rows+="\n| a rad:zspam$i public abc1234 b |"; done
for r in zfakeone zfaketwo zfakethree zfakefour; do
  rows+="\n| flatten-9-ab12cd34 rad:$r public abc1234 Flatten a nested array. Variant 9. |"
done
rows+="\n| tail rad:zfakefive public abc1234 z"
forge "$rows" zspam1=Alpha zspam2=Beta zspam3=Gamma
out=$("$SCRIPT" 2>&1)
{ ! grep -qE "^zcode7 " <<<"$out" \
  && grep -qF "listed 4 repo(s) twice, such as rad:zcode7 rad:zspam1 rad:zspam2." <<<"$out" \
  && grep -qF "listed 5 repo(s) that are not in storage, such as" <<<"$out"; } \
  && ok "a line break in a description cannot give another repo a name" \
  || no "a description forged a row that put zcode7 in the plan"
! grep -qE "^zspam[1-9] .*spam-batch" <<<"$out" \
  && ok "forged rows cannot raise a batch's agreement on its description" \
  || no "forged rows pushed the flatten batch over its agreement bar"
! grep -qE "^znodesc[1-9] .*spam-batch" <<<"$out" \
  && ok "a repo rad lists as local has no head read as its description" \
  || no "the heads of repos listed as local made them agree on a description"
# A row forged into a whole batch, under zcode7's id, must not make zcode7 one of its members.
build_fixture; assert_isolated
sed -i 's/^\(zbatchodd\t.*\t\)one of a kind$/\1x\\n| flatten-14-1a2b3c4d rad:zcode7 public'\
' abc1234 Flatten a nested array. Variant 14./' "$RSP_MANIFEST"
out=$("$SCRIPT" 2>&1)
{ grep -qE "^zspam1 .*spam-batch" <<<"$out" && ! grep -qE "^zcode7 " <<<"$out"; } \
  && ok "a row forged into a batch does not make its repo a member" \
  || no "a forged row made zcode7 a member of the flatten batch"
out=$(SPAM_MIN_BATCH=13 "$SCRIPT" 2>&1)   # the flatten batch is 12 members
! grep -qE "^zspam[1-9] .*spam-batch" <<<"$out" \
  && ok "a forged row does not count towards the size a batch needs" \
  || no "a forged row made a batch one member short big enough"

# A repo with no identity ref has no row of its own to tell a forged one from, so a row naming
# it is not believed. zjunk1's refs are packed, refs/rad/id with them, and it keeps its name.
build_fixture; assert_isolated
GIT_DIR="$STORAGE/zcode7" git update-ref -d refs/rad/id; touch -d "90 days ago" "$STORAGE/zcode7"
sed -i '/^zcode7\t/d' "$RSP_MANIFEST"
sed -i 's/^\(zbatchodd\t.*\t\)one of a kind$/\1x\\n| 0a1b2c3d4e5f rad:zcode7 public abc1234 y |/' \
  "$RSP_MANIFEST"
GIT_DIR="$STORAGE/zjunk1" git pack-refs --all; touch -d "90 days ago" "$STORAGE/zjunk1"
out=$("$SCRIPT" 2>&1)
{ ! grep -qE "^zcode7 " <<<"$out" && grep -q '^# 1 row(s) of .* no refs/rad/id' <<<"$out"; } \
  && ok "a forged row cannot name a repo that has no identity" \
  || no "a forged row named zcode7, which has no identity, into the plan"
{ [ ! -e "$STORAGE/zjunk1/refs/rad/id" ] && grep -qE "^zjunk1 .*junk-name" <<<"$out"; } \
  && ok "a repo whose refs git has packed keeps its name" \
  || no "packing refs/rad/id lost zjunk1 its name"

# --- rule H: an identity whose repos read like a malware operation is named, not acted on ---
# zcode4 and zcode6 are named and described like an operation and signed by one identity, as
# is zcode7, a plain project with "rat" inside a longer word: two of three hit, and the one
# strong word is a plural. Their documents also name a victim, first, who signed refs there, as
# a clone would, but did not sign the commit creating either repo. zrot1 and zrot2 carry only
# weak words, like a security researcher's. Three more identities each miss one bar: two words,
# two of five repos, one repo. Single repos next. zrot3 has the strong word in a path too, on a
# tag, and zfarm2 in a commit subject with an escape sequence, both with history as new as the
# repo. zrot1 has one in a path but not its name, zbatch1 one in its name alone, and in a
# stranger's branch. zbatch2's path holds one, but its history is a year older than the repo,
# as a mirror's is. zcode6, the operation's, is left to the identity review.
build_fixture; assert_isolated
# The signer, the first nid or else $SIGNER, also signs the commit that creates the document
# when new_key made its key, and has signed refs there. The document is named $NAME, the name
# the repo was created with, and its description is the repo's fixture id, so no two are the
# same blob, which a repo id is named after.
set_delegate(){   # $1 = rid, then the nids its identity document names
  local rid=$1 w dids="" nid c signer=${SIGNER:-$2} name=${NAME:-$1}; shift
  w=$(mktemp -d -p "$ROOT")
  git -C "$w" -c init.defaultBranch=master init -q
  git -C "$w" config user.email a@b; git -C "$w" config user.name a
  mkdir -p "$w/embeds"
  for nid; do dids="$dids${dids:+,}\"did:key:$nid\""; done
  printf '{"delegates":[%s],"payload":{"xyz.radicle.project":%s},"threshold":1}\n' "$dids" \
    "{\"name\":\"$name\",\"description\":\"$rid\"}" > "$w/embeds/radicle.json"
  git -C "$w" add -A; git -C "$w" commit -q -m id
  if [ -f "$ROOT/keys/$signer.pem" ]; then
    c=$(GIT_DIR="$w/.git" sign_op HEAD "$ROOT/keys/$signer.pem" "$signer")
    git -C "$w" update-ref refs/heads/master "$c"
  fi
  git -C "$w" push -q --force "$STORAGE/$rid" master:refs/rad/id \
    "master:refs/namespaces/$signer/refs/rad/sigrefs"
  rm -rf "$w"; touch -d "10 days ago" "$STORAGE/$rid"
}
# A later revision of $1's document that also names $2, who signs refs there, as a delegate
# adding somebody who cloned the repo would. The first revision, and so the repo id, stay.
add_delegate(){
  local d="$STORAGE/$1" w; w=$(mktemp -d -p "$ROOT")
  git -C "$w" init -q -b master
  git -C "$w" fetch -q "$d" refs/rad/id && git -C "$w" reset -q --hard FETCH_HEAD
  jq -c --arg n "did:key:$2" '.delegates += [$n]' "$w/embeds/radicle.json" > "$w/doc"
  mv "$w/doc" "$w/embeds/radicle.json"
  git -C "$w" -c user.email=a@b -c user.name=a commit -qam 'add a delegate'
  git -C "$w" push -q --force "$d" master:refs/rad/id \
    "master:refs/namespaces/$2/refs/rad/sigrefs"
  rm -rf "$w"; touch -d "10 days ago" "$d"
}
OPS=$(new_key); VIC=$(new_key); RES=$(new_key)
FEW=$(new_key); THIN=$(new_key); ONE=$(new_key)
NAME=c2-panel SIGNER=$OPS set_delegate zcode4 "$VIC" "$OPS"
NAME=wallet_drainers SIGNER=$OPS set_delegate zcode6 "$VIC" "$OPS"
for r in zcode4 zcode6; do
  GIT_DIR="$STORAGE/$r" git update-ref "refs/namespaces/$VIC/refs/rad/sigrefs" refs/rad/id
  touch -d "10 days ago" "$STORAGE/$r"
done
set_delegate zcode7 "$OPS"
NAME=exploit-loader set_delegate zrot1 "$RES"
NAME=payload-panel set_delegate zrot2 "$RES"
NAME=stealer-panel set_delegate zfarm1 "$FEW"
NAME=stealer set_delegate zfarm2 "$FEW"
NAME=hvnc-panel set_delegate zbatch1 "$THIN"
NAME=botnet set_delegate zbatch2 "$THIN"
for r in zbatch3 zpoison5 zpoison9; do set_delegate "$r" "$THIN"; done
# zrot3's document also names this node, which never signs there.
NAME=hvnc-panel set_delegate zrot3 "$ONE" "$RSP_NID"
# Radicle names a repo after its first identity document's blob, and rule H credits a founder
# only where the id names that blob. So each repo whose founder matters moves to that id,
# spelled $CODE4 for zcode4 and so on.
rehome(){   # $1 = rid; prints the id it moves to
  local blob new
  blob=$(GIT_DIR="$STORAGE/$1" git rev-parse "refs/rad/id:embeds/radicle.json")
  new=z$(base58 "$blob")
  mv "$STORAGE/$1" "$STORAGE/$new"
  sed -i "s/^$1\t/$new\t/" "$RSP_MANIFEST"
  printf '%s' "$new"
}
CODE4=$(rehome zcode4); CODE6=$(rehome zcode6)
ROT1=$(rehome zrot1); ROT2=$(rehome zrot2); ROT3=$(rehome zrot3)
FARM1=$(rehome zfarm1); FARM2=$(rehome zfarm2)
BATCH1=$(rehome zbatch1); BATCH2=$(rehome zbatch2)
fresh_master(){   # $1 = rid, $2 = age in days, $3 = a path, $4 = the subject, $5 = a ref
  local w ref=${5:-refs/heads/master}; w=$(mktemp -d -p "$ROOT")
  git -C "$w" init -q -b master
  mkdir -p "$(dirname "$w/$3")"; echo x > "$w/$3"; git -C "$w" add -A
  GIT_AUTHOR_DATE=$(date -d "$2 days ago" -R) \
    git -C "$w" -c user.email=a@b -c user.name=a commit -q -m "$4"
  git -C "$w" push -q --force "$STORAGE/$1" "master:$ref"
  rm -rf "$w"; touch -d "10 days ago" "$STORAGE/$1"
}
fresh_master "$ROT3" 0 src/client.py 'add client'
fresh_master "$ROT3" 0 src/hvnc/client.py 'add client' refs/tags/v1
fresh_master "$FARM2" 0 main.py 'feat(stealers): save results'
# The subject's escapes include a C1 pair nested in another, written raw, since `git commit`
# would re-encode the stray bytes.
d="$STORAGE/$FARM2"
c=$({ GIT_DIR="$d" git cat-file commit master | sed '/^$/q'
      printf 'feat(stealers): save\033[2J\302\302\233\2332J\302\342\200\213\233 results'
      printf '\342\200\256'
      # Each lead byte here meets its continuation byte only once the one inside it is gone,
      # so a strip that repeats until nothing changes takes one pass per pair.
      head -c 100000 /dev/zero | tr '\0' '\302'; head -c 100000 /dev/zero | tr '\0' '\233'
      echo; } \
    | GIT_DIR="$d" git hash-object -t commit -w --stdin)
GIT_DIR="$d" git update-ref refs/heads/master "$c"; touch -d "10 days ago" "$d"
fresh_master "$ROT1" 0 notes/stealer.md 'notes'
fresh_master "$BATCH2" 400 botnet/main.go 'import'
fresh_master "$CODE6" 0 drainer.py 'add drainer'
fresh_master "$BATCH1" 0 main.py 'add main'
fresh_master "$BATCH1" 0 stealer.py 'add stealer' \
  "refs/namespaces/$STRANGER_NID/refs/heads/master"
# zheavy and zdigit24 are named with a strong word but have no branch, so no commit dates to
# judge them by. zheavy has a strong word in a tag's files too; zdigit24 has none anywhere.
for r in zheavy zdigit24; do
  GIT_DIR="$STORAGE/$r" git for-each-ref --format='delete %(refname)' refs/heads \
    | GIT_DIR="$STORAGE/$r" git update-ref --stdin
done
fresh_master zheavy 0 keylogger.c 'add' refs/tags/v1
# One sed edit per repo: its rid, then its new name and description.
rename(){
  printf -- '-e\ns/^%s\\t[^\\t]*\\(\\t.*\\)\\t[^\\t]*$/%s\\t%s\\1\\t%s/\n' "$1" "$1" "$2" "$3"
}
mapfile -t edits < <(
  rename "$CODE4" $'c2-\342\200\256panel' 'the loader'
  rename "$CODE6" wallet_drainers 'the payload'
  rename zcode7 pirate-separator 'a text tool'
  rename "$ROT1" exploit-loader 'research notes'
  rename "$ROT2" payload-panel 'research notes'
  rename "$FARM1" stealer-panel 'a tool'
  rename "$FARM2" stealer 'a tool'
  rename "$BATCH1" hvnc-panel 'the loader'
  rename "$BATCH2" botnet 'a tool'
  rename "$ROT3" hvnc-panel 'the loader'
  rename zheavy keylogger 'a tool'
  rename zdigit24 ransomware 'a tool')
sed -i "${edits[@]}" "$RSP_MANIFEST"
# Only rule H is on, so the applying run reports and blocks nobody. The time limit catches a
# strip that would stall, pass by pass, on zfarm2's subject.
out=$(RULES=H "${NOTTY[@]}" timeout 60 "$SCRIPT" --apply --block-peers --yes </dev/null 2>&1)
rc=$?
{ [ "$rc" = 0 ] \
  && grep -q 'REVIEW 1 identity the malware rule (H) named. Nothing' <<<"$out" \
  && grep -q "#        $OPS: 2 of its 3 repos match:" <<<"$out" \
  && grep -q "#          rad:$CODE4  # c2-panel (c2,panel)" <<<"$out" \
  && grep -qx "#          did:key:$OPS" <<<"$out" \
  && ! grep -q 'WARN no signature on the first identity revision' <<<"$out" \
  && ! grep -q 'credits to their creator hold no project name' <<<"$out"; } \
  && ok "an identity whose repos read like a malware operation is named for review" \
  || no "rule H missed the operation's identity"
! grep -q "$VIC" <<<"$out" \
  && ok "naming somebody as a co-delegate of those repos does not name them" \
  || no "rule H named a delegate who signed nothing in the repos"
! grep -qE "$RES|$FEW|$THIN|$ONE" <<<"$out" \
  && ok "no strong word, two words, two repos of five, or one repo: nobody else is named" \
  || no "rule H named an identity under one of its bars"
{ grep -q 'REVIEW 2 repos the malware rule (H) flagged' <<<"$out" \
  && grep -qxF "#        rad:$ROT3  # hvnc-panel (hvnc,panel,loader; path: src/hvnc/client.py)" \
       <<<"$out" \
  && grep -qxF \
       "#        rad:$FARM2  # stealer (stealer; subject: feat(stealers): save[2J2J results)" \
       <<<"$out" \
  && ! grep -q $'\033' <<<"$out" && ! grep -q $'\302\233' <<<"$out"; } \
  && ok "one repo with a strong word in its name and its files or commits is named" \
  || no "rule H missed a single malware repo, or named a mirror or an operation's repo again"
{ grep -q 'WARN 1 repo(s) hold a strong malware word' <<<"$out" \
  && grep -qxF '#   rad:zheavy  # keylogger (keylogger; path: keylogger.c)' <<<"$out"; } \
  && ok "a repo with words and evidence but no commit dates to judge by is called out" \
  || no "rule H passed over a repo it could not date without a word, or warned with no evidence"
grep -qxF "$FARM2"$'\t'"stealer"$'\t'"subject: feat(stealers): save[2J2J results"$'\t'"stealer" \
  "$AUDIT_DIR/last-run/H-malware-repos.tsv" \
  && ok "last-run/H-malware-repos.tsv holds every single repo named" \
  || no "rule H's single repos did not reach last-run"
row=$(printf '%s\t2\t3\t%s\tdrainer\twallet_drainers' "$OPS" "$CODE6")
grep -qxF "$row" "$AUDIT_DIR/last-run/H-malware-identities.tsv" \
  && ok "last-run/H-malware-identities.tsv holds every repo that matched" \
  || no "rule H's evidence did not reach last-run"
# The malware verdicts in the last plan, as "rid verdict" pairs.
plan_h(){ awk -F'\t' '$5 ~ /^malware-/ { print $1, $5 }' "$AUDIT_DIR/last-run/plan.tsv" \
            | sort | tr '\n' ' '; }
# A run where rule H only reports is no sample of what it prunes, so it is not among the rules.
{ [ -z "$(plan_h)" ] && [ ! -e "$RSP_HOME/.stub_block" ] \
  && grep -q '  rules=-  ' "$AUDIT_DIR/last-run/plan.tsv"; } \
  && ok "by default the malware rule (H) puts nothing in the plan, and blocks nobody" \
  || no "rule H planned or blocked without MALWARE_PRUNE=1: $(plan_h)"
# When no first revision's signature checks out, Radicle may have changed how it signs them.
mkdir -p "$ROOT/nosig"
printf '#!/bin/sh\ncase "$*" in *founder/sig*) exit 1 ;; esac\nexec %s "$@"\n' \
  "$(command -v openssl)" > "$ROOT/nosig/openssl"
chmod +x "$ROOT/nosig/openssl"
nosig=$(PATH="$ROOT/nosig:$PATH" "$SCRIPT" 2>&1)
{ grep -q 'WARN no signature on the first identity revision of' <<<"$nosig" \
  && ! grep -q 'REVIEW [0-9]* identit' <<<"$nosig"; } \
  && ok "no founder signature checking out at all is called out" \
  || no "rule H went quiet without saying no signature checked out"
# When no first revision holds a project name, Radicle may have moved it.
mkdir -p "$ROOT/noname"
printf '#!/bin/sh\ncase "$*" in *xyz.radicle.project*) cat >/dev/null; exit 0 ;; esac\n' \
  > "$ROOT/noname/jq"
printf 'exec %s "$@"\n' "$(command -v jq)" >> "$ROOT/noname/jq"
chmod +x "$ROOT/noname/jq"
noname=$(PATH="$ROOT/noname:$PATH" "$SCRIPT" 2>&1)
{ grep -qE 'WARN ([0-9]+) of the \1 repo\(s\) the malware rule \(H\) credits' <<<"$noname" \
  && ! grep -q 'REVIEW [0-9]* identit' <<<"$noname"; } \
  && ok "no first revision holding a project name is called out" \
  || no "rule H went quiet without saying no first revision holds a name"
# Under MALWARE_PRUNE=1 every repo the operation's identity is a delegate of is planned,
# zcode7 too, whose name matched nothing. A single repo stays a review, an undatable one a
# warning.
out=$(MALWARE_PRUNE=1 "$SCRIPT" 2>&1); rc=$?
want=$(printf '%s %s\n' "$CODE4" malware-op "$CODE6" malware-op zcode7 malware-op \
         | sort | tr '\n' ' ')
{ [ "$rc" = 0 ] && [ "$(plan_h)" = "$want" ] \
  && grep -qx "#          rad block $OPS" <<<"$out" \
  && grep -q 'REVIEW 2 repos the malware' <<<"$out" \
  && grep -qxF "#        rad:$ROT3  # hvnc-panel (hvnc,panel,loader; path: src/hvnc/client.py)" \
       <<<"$out" \
  && grep -q 'WARN 1 repo(s) hold a strong malware word' <<<"$out"; } \
  && ok "MALWARE_PRUNE=1 plans an operation's repos and only reports single repos" \
  || no "MALWARE_PRUNE=1 planned the wrong repos (rc=$rc): $(plan_h)"
# The deny list blocks identities and vouches for none, so a listed co-delegate who signed refs
# in an operation's repo does not spare the operation's identity a block.
DENIED=$(new_key)
first=$(GIT_DIR="$STORAGE/$CODE4" git rev-parse refs/rad/id)
add_delegate "$CODE4" "$DENIED"
echo "did:key:$DENIED" > "$AUDIT_DIR/deny.txt"
out=$(MALWARE_PRUNE=1 "$SCRIPT" 2>&1); rc=$?
rm -f "$AUDIT_DIR/deny.txt"
GIT_DIR="$STORAGE/$CODE4" git update-ref -d "refs/namespaces/$DENIED/refs/rad/sigrefs"
GIT_DIR="$STORAGE/$CODE4" git update-ref refs/rad/id "$first"
touch -d "10 days ago" "$STORAGE/$CODE4"
{ [ "$rc" = 0 ] && grep -qx "#          rad block $OPS" <<<"$out"; } \
  && ok "a deny-listed co-delegate does not spare the operation's identity a block" \
  || no "a deny-listed identity's signed refs kept the operation's identity unblocked (rc=$rc)"
# A repo signed by an identity this seed vouches for, the pinned repo's delegate, is spared,
# and the operation's identity, its delegate, is not blocked. A hand-made block is the
# operator's, so no run advises lifting it.
PIN=$(dlg zpin6)
set_delegate zcode7 "$OPS" "$PIN"
GIT_DIR="$STORAGE/zcode7" git update-ref "refs/namespaces/$PIN/refs/rad/sigrefs" refs/rad/id
touch -d "10 days ago" "$STORAGE/zcode7"
"$RAD" block "$OPS" >/dev/null
out=$(MALWARE_PRUNE=1 "${NOTTY[@]}" "$SCRIPT" --block-peers --yes </dev/null 2>&1); rc=$?
rm -f "$RSP_HOME/.stub_block"; sed -i "/ $OPS\$/d" "$RSP_HOME/.stub_policy"
{ [ "$rc" = 0 ] && [ "$(plan_h)" = "${want/zcode7 malware-op /}" ] \
  && ! grep -qx "#          rad block $OPS" <<<"$out" \
  && ! grep -q "rad unfollow $OPS" <<<"$out"; } \
  && ok "a repo a vouched identity signed is spared, and its named delegate is not blocked" \
  || no "rule H planned a repo a vouched identity signed, or blocked its delegate (rc=$rc)"
GIT_DIR="$STORAGE/zcode7" git update-ref -d "refs/namespaces/$PIN/refs/rad/sigrefs"
set_delegate zcode7 "$OPS"
# A publisher's check names a repo of theirs that seeds list for review as possible malware.
sed -i "s/^\($ROT3\t[^\t]*\t[^\t]*\t[^\t]*\t\)0/\11/" "$RSP_MANIFEST"
out=$("$SCRIPT" check-mine 2>/dev/null); rc=$?
sed -i "s/^\($ROT3\t[^\t]*\t[^\t]*\t[^\t]*\t\)1/\10/" "$RSP_MANIFEST"
{ [ "$rc" = 6 ] && grep -qxE "flagged +hvnc-panel +rad:$ROT3 +possible malware" <<<"$out" \
  && grep -q 'A seed lists it for its operator to read' <<<"$out"; } \
  && ok "check names a repo of yours that seeds list for review as possible malware" \
  || no "check missed a single malware repo of yours (rc=$rc)"
mkdir -p "$ROOT/noed"; printf '#!/bin/sh\nexit 1\n' > "$ROOT/noed/openssl"
chmod +x "$ROOT/noed/openssl"
out=$(PATH="$ROOT/noed:$PATH" "$SCRIPT" check-mine 2>&1); rc=$?
{ [ "$rc" = 1 ] && grep -q 'install OpenSSL 3' <<<"$out" \
  && ! grep -q 'out of RULES' <<<"$out"; } \
  && ok "check asks for OpenSSL 3, since it cannot leave rules out" \
  || no "check gave advice it cannot follow when openssl cannot check ed25519 (rc=$rc)"
# A delegate can add anyone who cloned a repo as a co-delegate, and a clone signs its own refs.
# FRAMED is added that way to the operation's two repos, in a later revision of each document.
FRAMED=$(dlg zframed)
for r in "$CODE4" "$CODE6"; do add_delegate "$r" "$FRAMED"; done
out=$("$SCRIPT" 2>&1); rc=$?
{ [ "$rc" = 0 ] && ! grep -q "$FRAMED" <<<"$out" \
  && grep -q "#        $OPS: 2 of its 3 repos match:" <<<"$out"; } \
  && ok "an identity added as a co-delegate after a repo was created is not named for it" \
  || no "rule H named an identity only added as a co-delegate later"
# The fixture's own repos have made-up ids, so some start from a document their id does not
# name already.
foreign=$(sed -n 's/^# WARN \([0-9]*\) repo(s) start from another repo.s first.*/\1/p' \
            <<<"$out")
for r in "$CODE4" "$CODE6"; do
  GIT_DIR="$STORAGE/$r" git update-ref refs/rad/id refs/rad/id~1
  GIT_DIR="$STORAGE/$r" git update-ref -d "refs/namespaces/$FRAMED/refs/rad/sigrefs"
  touch -d "10 days ago" "$STORAGE/$r"
done
# The signature covers only the first revision's tree, so zcode4's, with OPS's signed refs, can
# be copied into another repo. Its id names another document, so the copy is not OPS's.
d="$STORAGE/$ROT2"
first=$(GIT_DIR="$d" git rev-parse refs/rad/id)
GIT_DIR="$d" git fetch -q "$STORAGE/$CODE4" +refs/rad/id:refs/rad/id
GIT_DIR="$d" git update-ref "refs/namespaces/$OPS/refs/rad/sigrefs" refs/rad/id
touch -d "10 days ago" "$d"
out=$("$SCRIPT" 2>&1); rc=$?
{ [ "$rc" = 0 ] && grep -q "#        $OPS: 2 of its 3 repos match:" <<<"$out" \
  && grep -q "WARN $((foreign + 1)) repo(s) start from another repo's first identity" \
       <<<"$out"; } \
  && ok "a first revision copied into a repo with another id counts for nobody, and is named" \
  || no "a copied first revision counted for its signer, or went unmentioned"
GIT_DIR="$d" git update-ref -d "refs/namespaces/$OPS/refs/rad/sigrefs"
GIT_DIR="$d" git update-ref refs/rad/id "$first"
touch -d "10 days ago" "$d"
# Any delegate can rename a repo, so a repo matches only on the words it used both when
# created and now. REN created an admin panel and a c2 image loader, which a co-delegate
# renamed to read like an operation's: three weak words survive, but no strong one. OP2
# created two operation repos and two plain ones, renamed later with weak words: those still
# count toward OP2's repos, so 2 of 4 match.
REN=$(new_key); OP2=$(new_key)
copy_plain(){   # $1 = rid, $2 = the nid that creates it, $3 = the name it is created with
  cp -a "$STORAGE/zcode7" "$STORAGE/$1"
  GIT_DIR="$STORAGE/$1" git update-ref -d "refs/namespaces/$OPS/refs/rad/sigrefs"
  printf '%s\n' "$(sed -n "s/^zcode7\t/$1\t/p" "$RSP_MANIFEST")" >> "$RSP_MANIFEST"
  NAME=$3 set_delegate "$1" "$2"
  rehome "$1"
}
renamed=()
renamed+=("$(copy_plain zren1 "$REN" admin-panel)")
renamed+=("$(copy_plain zren2 "$REN" c2-image-loader)")
renamed+=("$(copy_plain zop21 "$OP2" stealer-panel)")
renamed+=("$(copy_plain zop22 "$OP2" keylogger-c2)")
renamed+=("$(copy_plain zop23 "$OP2" notes)")
renamed+=("$(copy_plain zop24 "$OP2" tool)")
renamed+=("$(copy_plain zren3 "$REN" notes)")
renamed+=("$(copy_plain zren4 "$REN" tool)")
mapfile -t edits < <(rename "${renamed[0]}" stealer-panel 'the loader'
                     rename "${renamed[1]}" keylogger-loader-c2 'the payload'
                     rename "${renamed[2]}" stealer-panel 'a tool'
                     rename "${renamed[3]}" keylogger-c2 'a tool'
                     rename "${renamed[4]}" loader-notes 'a tool'
                     rename "${renamed[5]}" payload-tool 'a tool'
                     rename "${renamed[6]}" loader-notes 'a tool'
                     rename "${renamed[7]}" payload-tool 'a tool')
sed -i "${edits[@]}" "$RSP_MANIFEST"
out=$("$SCRIPT" 2>&1); rc=$?
{ [ "$rc" = 0 ] && ! grep -q "$REN" <<<"$out" \
  && grep -q "#        $OP2: 2 of its 4 repos match:" <<<"$out"; } \
  && ok "words a co-delegate renamed a repo to do not count against its founder" \
  || no "rule H judged a founder on words only a later rename added (rc=$rc)"
# OP2 also signs two plain repos of REN's as a co-delegate. They matched only after a rename,
# so they count as plain repos of OP2's, and 2 of 6 is under the share.
for r in "${renamed[6]}" "${renamed[7]}"; do add_delegate "$r" "$OP2"; done
out=$("$SCRIPT" 2>&1); rc=$?
for r in "${renamed[@]}"; do
  rm -rf "${STORAGE:?}/$r"; sed -i "/^$r"$'\t'"/d" "$RSP_MANIFEST"
done
{ [ "$rc" = 0 ] && ! grep -q "$OP2" <<<"$out"; } \
  && ok "a repo renamed into matching counts as plain for its co-delegates too" \
  || no "a co-delegate's share rose when a founder renamed their own repo (rc=$rc)"
# A kept repo vouches for every delegate it names, one who never signed there included, since
# the deny list would not block them either.
add_delegate "$FARM1" "$OPS"
GIT_DIR="$STORAGE/$FARM1" git update-ref -d "refs/namespaces/$OPS/refs/rad/sigrefs"
echo "$FARM1" > "$RSP_HOME/keep.txt"
out=$(KEEP_FILE="$RSP_HOME/keep.txt" "$SCRIPT" 2>&1); rc=$?
rm -f "$RSP_HOME/keep.txt"
{ [ "$rc" = 0 ] && ! grep -q "$OPS" <<<"$out" && ! grep -q "rad:$FARM2" <<<"$out"; } \
  && ok "an identity delegating a kept repo, signed or not, is not named, nor its repos" \
  || no "rule H named an identity that delegates a repo in keep.txt"
echo "did:key:$OPS  # cleared" > "$RSP_HOME/keep.txt"
out=$(KEEP_FILE="$RSP_HOME/keep.txt" "$SCRIPT" 2>&1); rc=$?
rm -f "$RSP_HOME/keep.txt"
{ [ "$rc" = 0 ] && ! grep -q "$OPS" <<<"$out"; } \
  && ok "an identity the keep list clears is not named" \
  || no "rule H named an identity whose did:key: line is in keep.txt"
# zfarm2 also names VIC, who never signed it; listing VIC has the deny list prune it.
add_delegate "$FARM2" "$VIC"
GIT_DIR="$STORAGE/$FARM2" git update-ref -d "refs/namespaces/$VIC/refs/rad/sigrefs"
printf '%s\n' "did:key:$OPS" "rad:$ROT3" "did:key:$VIC" > "$AUDIT_DIR/deny.txt"
out=$("$SCRIPT" 2>&1); rc=$?
rm -f "$AUDIT_DIR/deny.txt"
{ [ "$rc" = 0 ] && ! grep -q 'REVIEW [0-9]* identit' <<<"$out" \
  && ! grep -q "^#     rad:$ROT3 " <<<"$out" && ! grep -q "^#     rad:$FARM2 " <<<"$out"; } \
  && ok "an identity or a repo the deny list names or prunes is not named again" \
  || no "rule H named an identity or repo the deny list names, or a repo it prunes"
# A private repo is its delegates' choice, so it vouches for nobody and counts like any other.
# It is never named on its own, since the deny list does not prune one.
set_delegate zpriv7 "$OPS"
sed -i "s/^\($ROT3\t[^\t]*\t[^\t]*\t\)public/\1private/" "$RSP_MANIFEST"
out=$("$SCRIPT" 2>&1); rc=$?
{ [ "$rc" = 0 ] \
  && grep -q "#        $OPS: 2 of its 4 repos match:" <<<"$out"; } \
  && ok "an identity delegating a private repo is still named" \
  || no "a private repo kept its delegate from rule H"
! grep -q "^#     rad:$ROT3 " <<<"$out" \
  && ok "a private repo is not named on its own" \
  || no "rule H named a private repo, which the deny list would not prune"
out=$(MALWARE_STRONG_WORDS='stealer|' "$SCRIPT" 2>&1); rc=$?
[ "$rc" = 2 ] \
  && ok "a word list with an empty entry stops the run (exit 2)" \
  || no "MALWARE_STRONG_WORDS='stealer|' did not exit 2 (got $rc)"
# zhexid23's strong word sits on its branch, and three tags point at trees without one, the
# first of them sorting ahead of the branch's by hash. With room for one tree, the branch's is
# the one read. Its path is long and holds the word inside a longer one first, so the line
# shown is cut around the whole word, near its end.
long=docs/cryptergui/notes/$(printf 'deep%.0s/' $(seq 16))crypter.c
fresh_master zhexid23 0 "$long" 'init'
for t in 1 2 3; do fresh_master zhexid23 0 "README$t" 'docs' "refs/tags/v$t"; done
sed -i "$(rename zhexid23 crypter 'a tool' | tail -1)" "$RSP_MANIFEST"
# zspaced26's strong word is in a path that sorts after 2^18 others, past MALWARE_BYTES.
d="$STORAGE/zspaced26"
root=$(printf '040000 tree %s\ta\n100644 blob %s\tstealer.c\n' "$(bomb_tree "$d" 18)" \
         "$(printf x | GIT_DIR="$d" git hash-object -w --stdin)" | GIT_DIR="$d" git mktree)
GIT_DIR="$d" git update-ref refs/heads/master \
  "$(GIT_DIR="$d" git -c user.name=a -c user.email=a@b commit-tree -m init "$root")"
touch -d "10 days ago" "$d"
sed -i "$(rename zspaced26 stealer-kit 'a tool' | tail -1)" "$RSP_MANIFEST"
sed 's/^MALWARE_TREES=50 /MALWARE_TREES=1 /' "$SCRIPT" > "$ROOT/one-tree"
chmod +x "$ROOT/one-tree"
out=$("$ROOT/one-tree" 2>&1)
trees=$(GIT_DIR="$STORAGE/zhexid23" git rev-parse 'refs/tags/v1^{tree}' 'master^{tree}')
{ grep -q '^MALWARE_TREES=1 ' "$ROOT/one-tree" && [ "$(sort <<<"$trees")" = "$trees" ] \
  && grep -qE '^#        rad:zhexid23  # crypter \(crypter; \.\.\.deep/.*/crypter\.c\)$' \
       <<<"$out"; } \
  && ok "branches are read before tags, and a long path is cut around its word" \
  || no "MALWARE_TREES dropped the branch's tree, or the cut lost the word"
! grep -q '^#     rad:zspaced26 ' <<<"$out" \
  && ok "rule H reads a repo's paths only so far" \
  || no "rule H read past MALWARE_BYTES into a tree that repeats itself"
# Under MALWARE_PRUNE=1 a named identity's private repo alone is spared: the rest stay planned,
# and the delegate is not blocked, which would stop the private repo's updates. A dropped ref
# above may have rewritten packed-refs, which reads as a fetch in flight.
touch -d "10 days ago" "$STORAGE/$CODE4" "$STORAGE/$CODE6"
out=$(MALWARE_PRUNE=1 "${NOTTY[@]}" "$SCRIPT" --block-peers --yes </dev/null 2>&1)
{ grep -q "$CODE4 malware-op" <<<"$(plan_h)" && ! grep -q 'zpriv7' <<<"$(plan_h)" \
  && ! grep -qx "#          rad block $OPS" <<<"$out" && ! grep -q "WARN $OPS" <<<"$out"; } \
  && ok "a private repo of a named identity is spared, and the identity is not blocked" \
  || no "rule H planned a private repo, or meant to block a delegate of one"
set_delegate zpriv7 "$(dlg zpriv7)"
# Blocking an identity goes with pruning its repos, so a run where the ratchet holds rule H
# back blocks nobody. Four past runs in which rule H pruned nothing set its limit at 0.
for i in 1 2 3 4; do past_run "$i"; done
out=$(RULES=H MALWARE_PRUNE=1 RATCHET_FLOOR=0 "${NOTTY[@]}" "$SCRIPT" --apply --block-peers \
        --yes </dev/null 2>&1); rc=$?
rm -f "$AUDIT_DIR"/prune-*.log "$AUDIT_DIR/history.log"
{ [ "$rc" = 4 ] && grep -q '^# HELD BACK the malware rule (H): ' <<<"$out" \
  && [ -e "$STORAGE/$CODE4" ] && [ ! -e "$RSP_HOME/.stub_block" ]; } \
  && ok "a run that holds the malware rule (H) back blocks none of its identities" \
  || no "rule H blocked an identity while held back (rc=$rc)"
# Without --block-peers an applying run prunes the operation's repos and blocks nobody. Each
# pruned repo is put back, and dropped from keep.txt, for the next run.
MALWARE_PRUNE=1 RULES=H "${NOTTY[@]}" "$SCRIPT" --apply --yes </dev/null >/dev/null 2>&1
{ [ ! -e "$STORAGE/$CODE4" ] && ! grep -qxF "$OPS" "$RSP_HOME/.stub_block"; } \
  && ok "without --block-peers no identity the malware rule (H) names is blocked" \
  || no "rule H blocked an identity without --block-peers, or pruned nothing"
mapfile -t held < <(ls "$AUDIT_DIR/quarantine")
"$SCRIPT" quarantine restore "${held[@]}" >/dev/null 2>&1
rm -f "$AUDIT_DIR/keep.txt"
touch -d "10 days ago" "$STORAGE"/z*
# A block on the identity that fails still prunes its repos, and makes the run exit 1.
out=$(RSP_BLOCK_NODE_FAIL=1 MALWARE_PRUNE=1 RULES=H "${NOTTY[@]}" "$SCRIPT" --apply \
        --block-peers --yes </dev/null 2>&1); rc=$?
{ [ "$rc" = 1 ] \
  && grep -q "WARN could not block $OPS, and no later run will try again.* rad block $OPS" \
       <<<"$out" \
  && [ -d "$AUDIT_DIR/quarantine/$CODE4" ] \
  && ! grep -q '^blocked-malware' "$AUDIT_DIR"/prune-*.log; } \
  && ok "a malware block that fails makes the run exit 1" \
  || no "a failed malware block went unreported in the exit code (rc=$rc)"
mapfile -t held < <(ls "$AUDIT_DIR/quarantine")
"$SCRIPT" quarantine restore "${held[@]}" >/dev/null 2>&1
rm -f "$AUDIT_DIR/keep.txt" "$AUDIT_DIR"/prune-*.log "$AUDIT_DIR/history.log"
rm -f "$RSP_HOME/.stub_block"; sed -i "/ $OPS\$/d" "$RSP_HOME/.stub_policy"
touch -d "10 days ago" "$STORAGE"/z*
# A node blocked already, here by hand, stays the operator's block: no blocked-malware row.
"$RAD" block "$OPS" >/dev/null
out=$(MALWARE_PRUNE=1 RULES=H "${NOTTY[@]}" "$SCRIPT" --apply --block-peers --yes \
        </dev/null 2>&1); rc=$?
{ [ "$rc" = 0 ] && [ -d "$AUDIT_DIR/quarantine/$CODE4" ] \
  && grep -q "blocked 0 of 1 identity(s) .*; 1 of them already blocked" <<<"$out" \
  && ! grep -q '^blocked-malware' "$AUDIT_DIR"/prune-*.log; } \
  && ok "a block already standing on the identity is not recorded as the malware rule's" \
  || no "rule H recorded a block it did not make (rc=$rc)"
mapfile -t held < <(ls "$AUDIT_DIR/quarantine")
"$SCRIPT" quarantine restore "${held[@]}" >/dev/null 2>&1
rm -f "$AUDIT_DIR/keep.txt" "$AUDIT_DIR"/prune-*.log "$AUDIT_DIR/history.log"
rm -f "$RSP_HOME/.stub_block"; sed -i "/ $OPS\$/d" "$RSP_HOME/.stub_policy"
touch -d "10 days ago" "$STORAGE"/z*
out=$(MALWARE_PRUNE=1 "${NOTTY[@]}" "$SCRIPT" --apply --block-peers --yes </dev/null 2>&1); rc=$?
{ [ "$rc" = 0 ] && grep -qxF "$OPS" "$RSP_HOME/.stub_block" \
  && grep -q "^blocked-malware"$'\t'"$OPS"$'\t'"repos_hit=2" "$AUDIT_DIR"/prune-*.log \
  && [ -d "$AUDIT_DIR/quarantine/$CODE4" ] && [ ! -e "$STORAGE/$CODE4" ] \
  && [ -d "$STORAGE/$FARM2" ] && [ ! -e "$AUDIT_DIR/quarantine/$FARM2" ] \
  && grep -q $'^zcode7\t.*\tmalware-op\t' "$AUDIT_DIR"/prune-*.log; } \
  && ok "--apply --block-peers --yes quarantines the operation's repos and blocks its identity" \
  || no "MALWARE_PRUNE=1 did not prune and block what rule H named (rc=$rc)"
{ grep -qx "# malware-op: zcode7 $OPS" "$AUDIT_DIR"/prune-*.log \
  && grep -qx "zcode7"$'\t'"$OPS" "$AUDIT_DIR/last-run/H-malware-op-repos.tsv"; } \
  && ok "the audit log names what each malware-op verdict rests on" \
  || no "a malware verdict left no record of what it rests on"
# Putting one of its repos back clears the identity of rule H but leaves it blocked, so the
# restore, and every run after it, gives the command that lifts the block.
out=$("$SCRIPT" quarantine restore "$CODE4" 2>&1)
touch -d "10 days ago" "$STORAGE/$CODE4"
{ grep -q "the malware rule (H) named its delegate $OPS, and no longer does" <<<"$out" \
  && grep -q "rad unfollow $OPS" <<<"$out" && ! grep -q "$VIC" <<<"$out"; } \
  && ok "restoring a malware-op repo names the identity it clears, and how to lift its block" \
  || no "quarantine restore left the identity's block unmentioned"
out=$(MALWARE_PRUNE=1 "$SCRIPT" 2>&1)
n=$(grep -c "WARN an earlier run blocked $OPS as malware.*rad unfollow $OPS" <<<"$out")
[ "$n" = 1 ] \
  && ok "a run warns about an identity an earlier run blocked as malware and that is cleared" \
  || no "a run said nothing about the block on an identity rule H now clears"
# Once the block is lifted the warning stops, unless the node's blocks cannot be listed.
"$RAD" unfollow "$OPS"
out=$(MALWARE_PRUNE=1 "$SCRIPT" 2>&1)
failed=$(RSP_FOLLOW_FAIL=1 MALWARE_PRUNE=1 "$SCRIPT" 2>&1)
{ ! grep -q "rad unfollow $OPS" <<<"$out" \
  && grep -q "WARN '.*follow' failed" <<<"$failed" \
  && grep -q "rad unfollow $OPS" <<<"$failed"; } \
  && ok "the warning stops once the block is lifted, and says why when blocks cannot be listed" \
  || no "a lifted block was still reported, or an unreadable block list was silent"
# --- a deny-list block that fails --- The identity stays unblocked, which wants a person, so
# the run exits 1. Rule H alone plans nothing here, so the block is all the run does.
build_fixture; assert_isolated
printf 'did:key:%s\n' "$STRANGER_NID" > "$AUDIT_DIR/deny.txt"
out=$(RSP_BLOCK_NODE_FAIL=1 RULES=H "${NOTTY[@]}" "$SCRIPT" --apply --yes </dev/null 2>&1)
rc=$?
{ [ "$rc" = 1 ] && grep -q "WARN could not block denied identity $STRANGER_NID" <<<"$out"; } \
  && ok "a deny-list block that fails makes the run exit 1" \
  || no "a failed deny-list block went unreported in the exit code (rc=$rc)"

# --- the deny list: a person's verdict, acted on wherever it turns up ---
# zcode4 is listed by id, zfarm1 through its delegate. The stranger who pushed into zmediapeer,
# and whom its document thanks by did:key, is listed and must not prune it: only the document's
# delegates count. zpin6 and its delegate are listed; the pin wins, and the delegate is not
# blocked, which would stop the pinned repo's updates. An unfetched repo id is blocked ahead of
# it. This node's own identity is listed too, and must be ignored. zcode4 was just written,
# as a repo still arriving is, and is pruned anyway. The file ends without a newline and has
# a CRLF, as hand-edited ones may. A history where no rule plans far above its usual shows
# the deny list is not held back.
build_fixture; assert_isolated
for i in 1 2 3 4; do past_run "$i" $USUAL_BUT_C stale:20; done
touch "$STORAGE/zcode4"
printf '%s\n' "rad:zcode4            # by repo id" "did:key:$(dlg zfarm1)"$'\r' \
       "$STRANGER_NID" "rad:zpin6" "did:key:$(dlg zpin6)" "not-an-id" "did:key:$RSP_NID" \
       > "$AUDIT_DIR/deny.txt"
printf 'zUnfetchedRepo9' >> "$AUDIT_DIR/deny.txt"
# Three documents heartwood accepts but does not write. zfarm1's opens with a "delegates"
# nested in its payload, naming a decoy, so its delegate must come from the top level. zcode6's
# nests the listed delegate and names somebody else on top, so it is not denied. zcode7's
# spells the listed delegate's "z" as an escape, which serde decodes.
iddoc(){   # $1 = rid, $2 = the document
  local d="$STORAGE/$1" blob c
  blob=$(printf '%s' "$2" | GIT_DIR="$d" git hash-object -w --stdin)
  c=$(GIT_DIR="$d" GIT_COMMITTER_DATE='2000-01-01T00:00:00Z' \
        git -c user.name=a -c user.email=a@b commit-tree -p refs/rad/id -m id \
        "$(printf '100644 blob %s\tradicle.json\n' "$blob" | GIT_DIR="$d" git mktree \
           | xargs printf '040000 tree %s\tembeds\n' | GIT_DIR="$d" git mktree)")
  GIT_DIR="$d" git update-ref refs/rad/id "$c"; touch -d "10 days ago" "$d"
}
nested(){ printf '{"payload":{"xyz.radicle.project":{"delegates":["did:key:%s"]}},' "$1"; }
top(){ printf '"delegates":["did:key:%s"],"threshold":1}' "$1"; }
iddoc zfarm1 "$(nested "$(dlg zdecoy)")$(top "$(dlg zfarm1)")"
iddoc zcode6 "$(nested "$(dlg zfarm1)")$(top "$(dlg zdecoy)")"
escaped="did:key:\\u007a$(dlg zfarm1 | cut -c2-)"
iddoc zcode7 "{\"delegates\":[\"$escaped\"],\"payload\":{},\"threshold\":1}"
dry=$(RATCHET_FLOOR=0 "$SCRIPT" 2>&1)
{ [ ! -e "$RSP_HOME/.stub_block" ] && grep -q 'The deny list blocks 3 ids' <<<"$dry" \
  && grep -qx '#          rad:zUnfetchedRepo9' <<<"$dry" \
  && grep -qx "zfarm1"$'\t'"delegate $(dlg zfarm1)" "$AUDIT_DIR/last-run/deny-repos.tsv"; } \
  && ok "a dry run lists what the deny list would block and why, and blocks nothing" \
  || no "a dry run blocked something, or hid what --apply would block"
{ grep -qx "zcode7"$'\t'"delegate $(dlg zfarm1)" "$AUDIT_DIR/last-run/deny-repos.tsv" \
  && ! grep -q '^zcode6' "$AUDIT_DIR/last-run/deny-repos.tsv"; } \
  && ok "a repo's delegates are read from its document's top level, however it is written" \
  || no "a listed delegate was missed in an escaped did:key, or found in a nested list"
out=$(RATCHET_FLOOR=0 "${NOTTY[@]}" "$SCRIPT" --apply </dev/null 2>&1); rc=$?
{ [ "$rc" = 0 ] && [ ! -e "$STORAGE/zcode4" ] && [ ! -e "$STORAGE/zfarm1" ] \
  && grep -qE $'^zcode4\t.*\tdenied\t' "$AUDIT_DIR"/prune-2*Z.log \
  && grep -qE $'^zfarm1\t.*\tdenied\t' "$AUDIT_DIR"/prune-2*Z.log \
  && grep -qx "# denied: zfarm1 delegate $(dlg zfarm1)" "$AUDIT_DIR"/prune-2*Z.log; } \
  && ok "a denied repo, or one a denied identity is a delegate of, is pruned as denied" \
  || no "the deny list did not prune what it names (rc=$rc)"
! grep -qE $'^zmediapeer\t.*\tdenied\t' "$AUDIT_DIR"/prune-2*Z.log \
  && ok "a listed stranger condemns no repo it is only named in or pushed into" \
  || no "a listed stranger condemned a repo they are not a delegate of"
{ [ -e "$STORAGE/zpin6" ] && grep -q 'kept anyway' <<<"$out" && grep -q 'zpin6' <<<"$out" \
  && ! grep -qx "$(dlg zpin6)" "$RSP_HOME/.stub_block"; } \
  && ok "a pin outranks the deny list, its listed delegate is not blocked, and the run says so" \
  || no "the deny list overrode a pin, blocked its delegate, or kept it without a word"
{ grep -qx 'rad:zUnfetchedRepo9' "$RSP_HOME/.stub_block" \
  && grep -qx "$STRANGER_NID" "$RSP_HOME/.stub_block" \
  && grep -q $'^blocked-denied\trad:zUnfetchedRepo9$' "$AUDIT_DIR"/prune-2*Z.log; } \
  && ok "a listed id with no repo here is blocked ahead of it, and the block is logged" \
  || no "the deny list left an unfetched repo or an identity unblocked"
grep -q "not-an-id is neither a repo id nor an identity" <<<"$out" \
  && ok "a deny line that names nothing is called out" \
  || no "a malformed deny line was dropped without a word"
{ grep -q "own identity; ignored" <<<"$out" && ! grep -qx "$RSP_NID" "$RSP_HOME/.stub_block"; } \
  && ok "the deny list never blocks this node's own identity" \
  || no "the deny list blocked this node itself, or said nothing"

# The runaway caps measure what the rules picked. A deny list over the cap is still a person's,
# and counting it would stop every unattended run until somebody forced one.
build_fixture; assert_isolated
printf 'rad:zcode4\nrad:zcode6\nrad:zcode7\n' > "$AUDIT_DIR/deny.txt"
out=$(RULES='' MAX_PRUNE_COUNT=1 MAX_PRUNE_GB=0 "${NOTTY[@]}" "$SCRIPT" --apply </dev/null 2>&1); rc=$?
{ [ "$rc" = 0 ] && [ ! -e "$STORAGE/zcode4" ] && [ ! -e "$STORAGE/zcode7" ]; } \
  && ok "repos on the deny list do not count against the runaway caps" \
  || no "a deny list longer than the cap stopped the run (rc=$rc)"

# --- copies of denied files: the files deny-files.tsv lists, found again in another repo ---
# "same" pads with zeros, so every repo given leak.mp4 at 6 MiB holds one blob no other fixture
# holds. zcode4 has it at its tip, zcode6 only in history, zcode7 beside four times its bytes
# of other files, zpin6 is pinned, and zvictimten has it only where a stranger pushed it. zrot1
# holds a second listed clip, under COPY_MIN_BYTES. zrot2's listed file is not media, and a
# stranger pushed zrot1's clip into it, too small to look at.
build_fixture; assert_isolated
e_tree zcode4 90 master "leak.mp4:6291456:same" "README.md:100"
e_tree zcode6 90 master "leak.mp4:6291456:same"
e_tree zcode6 90 master "README.md:100"
e_tree zcode7 90 master "leak.mp4:6291456:same" "own.mp4:25165824:mp4"
e_tree zpin6 90 master "leak.mp4:6291456:same" "README.md:100"
e_tree zvictimten 90 "refs/namespaces/$STRANGER_NID/refs/heads/x" "leak.mp4:6291456:same"
e_tree zrot1 90 master "small.mp4:3145728:same"
e_tree zrot2 90 master "notes.md:6291456"
e_tree zrot2 90 "refs/namespaces/$STRANGER_NID/refs/heads/x" "small.mp4:3145728:same"
# zrot3: a stranger's patch carries the clip, and the delegate replies to it. Heartwood makes
# the patch commit a parent of the delegate's own COB op, so the clip is in the history of a
# ref under the delegate's namespace, and only there.
d="$STORAGE/zrot3"
e_tree zrot3 90 "refs/namespaces/$STRANGER_NID/refs/heads/patch" "leak.mp4:6291456:same"
patch=$(GIT_DIR="$d" git rev-parse "refs/namespaces/$STRANGER_NID/refs/heads/patch")
reply=$(git -c user.name=a -c user.email=a@b --git-dir="$d" commit-tree -p "$patch" -m reply \
          "$(git --git-dir="$d" rev-parse "master^{tree}")")
GIT_DIR="$d" git update-ref "refs/namespaces/$(dlg zrot3)/refs/cobs/xyz.radicle.patch/aaa" \
  "$reply"
GIT_DIR="$d" git update-ref -d "refs/namespaces/$STRANGER_NID/refs/heads/patch"
touch -d "10 days ago" "$d"
leak=$(GIT_DIR="$STORAGE/zcode4" git rev-parse master:leak.mp4)
small=$(GIT_DIR="$STORAGE/zrot1" git rev-parse master:small.mp4)
notes=$(GIT_DIR="$STORAGE/zrot2" git rev-parse master:notes.md)
printf '# oid\tbytes\tsource\tdate\n%s\t6291456\trad:zgonesrc\t2026-10-02\n' "$leak" \
  > "$AUDIT_DIR/deny-files.tsv"
printf '%s - hand-list 2026-10-02\n%s - hand-list 2026-10-02\n' "$small" "$notes" \
  >> "$AUDIT_DIR/deny-files.tsv"
plan=$(run)
{ grep -qE "^zcode4 .* denied-copy " <<<"$plan" \
  && grep -qE $'^zcode4\t6291456\t629[0-9]{4}\t99\t1\trad:zgonesrc\t0$' \
       "$AUDIT_DIR/last-run/deny-copies.tsv" \
  && grep -qx "zcode4"$'\t'"$leak"$'\t6291456' "$AUDIT_DIR/last-run/deny-copy-files.tsv"; } \
  && ok "a repo holding a listed file is pruned as a copy, and its source is named" \
  || no "a repo holding a listed file was not pruned as a copy, or its source went unnamed"
grep -qE "^zcode6 .* denied-copy " <<<"$plan" \
  && ok "a listed file committed and then deleted still makes a copy" \
  || no "a listed file only in history was missed"
{ ! grep -qE "^(zcode7|zrot1) .* denied-copy " <<<"$plan" \
  && grep -qE '^#   zcode7 ' <<<"$plan" \
  && ! grep -qE '^#   zrot1 ' <<<"$plan"; } \
  && ok "a copy needs both the bytes and the share, and one under only the share is named" \
  || no "a repo under one of the two bars was pruned as a copy, or went unnamed"
{ ! grep -qE "^(zvictimten|zrot3) .* denied-copy " <<<"$plan" \
  && grep -qE '^#   zvictimten +1 file\(s\)$' <<<"$plan" \
  && grep -qE '^#   zrot3 +1 file\(s\)$' <<<"$plan" \
  && ! grep -qE '^#   zrot2 +[0-9]+ file\(s\)$' <<<"$plan"; } \
  && ok "a listed file a stranger pushed condemns nobody, even under a delegate's reply" \
  || no "a stranger's push made a copy, or the repo went unnamed"
{ ! grep -qE "^zpin6 " <<<"$plan" && grep -qE '^#   zpin6  copy of denied files$' <<<"$plan"; } \
  && ok "a pinned copy is kept, and the run names it" \
  || no "a pinned copy was pruned, or kept without a word"
{ ! grep -qE "^zrot2 .* denied-copy " <<<"$plan" \
  && grep -qF "#   $notes  not a known media format (in zrot2)" <<<"$plan"; } \
  && ok "a listed file that is not media counts for nothing, and its row is named" \
  || no "a listed text file made a copy, or went unnamed"
# A file listed from a repo is that repo's own: the source back in storage, its block lifted,
# is no copy of itself, while another repo holding the file still is.
cp "$AUDIT_DIR/deny-files.tsv" "$ROOT/deny-files.saved"
printf '%s\t6291456\trad:zcode4\t2026-10-02\n' "$leak" > "$AUDIT_DIR/deny-files.tsv"
plan=$(run)
{ ! grep -qE "^zcode4 .* denied-copy " <<<"$plan" && grep -qE "^zcode6 .* denied-copy " <<<"$plan"; } \
  && ok "a repo is no copy of the files listed from it" \
  || no "a repo was pruned as a copy of its own listed files, or the other copy was missed"
mv "$ROOT/deny-files.saved" "$AUDIT_DIR/deny-files.tsv"
# The caps and the ratchet count copies: they are the tool's inference, and a wrong row has no
# limit otherwise.
out=$(RULES='' MAX_PRUNE_COUNT=1 "${NOTTY[@]}" "$SCRIPT" --apply \
        </dev/null 2>&1); rc=$?
{ [ "$rc" = 3 ] && [ -e "$STORAGE/zcode4" ]; } \
  && ok "copies of denied files count against the runaway caps" \
  || no "copies of denied files got past the runaway caps (rc=$rc)"
for i in 1 2 3 4; do past_run "$i" $USUAL_BUT_C stale:20; done
plan=$(RATCHET_FLOOR=0 run)
grep -q '^#          rule denied-copy: 2 repos' <<<"$plan" \
  && ok "copies far above their usual are held back like a rule" \
  || no "the ratchet did not count copies of denied files"
# zpoison5 holds the clip too, and this seed saw it before the repo the clip is listed from,
# so the clip may be zpoison5's own, and the repos holding it are no copies of that source.
e_tree zpoison5 90 master "leak.mp4:6291456:same" "README.md:100"
# Sets the day the ledger says this seed first saw zgonesrc and zpoison5, in days ago.
seen_days_ago(){
  local now; now=$(date -u +%s)
  sed -i '/^zgonesrc\t/d; /^zpoison5\t/d' "$AUDIT_DIR/first-seen.tsv"
  printf 'zgonesrc\t%s\nzpoison5\t%s\n' "$((now - $1 * 86400))" "$((now - $2 * 86400))" \
    >> "$AUDIT_DIR/first-seen.tsv"
}
seen_days_ago 5 20
plan=$(run)
{ ! grep -qE '^z[^ ]* .* denied-copy ' <<<"$plan" \
  && grep -qxF "#   $leak  first in zpoison5, listed from zgonesrc" <<<"$plan"; } \
  && ok "a listed file a repo held before its source counts against no repo, and is named" \
  || no "a file held before its source still made copies, or went unnamed"
# A second source seen before zpoison5 shows the clip was here first in that one.
printf '%s\t6291456\trad:zoldsrc\t2026-10-02\n' "$leak" >> "$AUDIT_DIR/deny-files.tsv"
printf 'zoldsrc\t%s\n' "$(date -u -d "30 days ago" +%s)" >> "$AUDIT_DIR/first-seen.tsv"
plan=$(run)
sed -i '$d' "$AUDIT_DIR/deny-files.tsv"
{ grep -qE '^zcode4 .* denied-copy ' <<<"$plan" && ! grep -q 'first in zpoison5' <<<"$plan"; } \
  && ok "a repo seen after any of a file's sources does not set the file aside" \
  || no "a repo older than only some of a file's sources set the file aside"
# Seen the same day proves nothing, like every repo already here when the ledger started.
seen_days_ago 5 5
plan=$(run)
{ grep -qE '^zcode4 .* denied-copy ' <<<"$plan" && ! grep -q 'first in zpoison5' <<<"$plan"; } \
  && ok "a repo seen the same day as the source does not set its file aside" \
  || no "a tie in the ledger set a listed file aside"
# A repo whose delegate deny.txt names is no original, however early this seed saw it.
seen_days_ago 5 20
printf 'did:key:%s\n' "$(dlg zpoison5)" > "$AUDIT_DIR/deny.txt"
plan=$(run)
rm -f "$AUDIT_DIR/deny.txt"
{ grep -qE '^zcode4 .* denied-copy ' <<<"$plan" && ! grep -q 'first in zpoison5' <<<"$plan"; } \
  && ok "a repo whose delegate is denied does not set a listed file aside" \
  || no "a denied identity's older repo set a listed file aside"
# The deny list spares a kept repo, so that repo can still be the original.
printf 'did:key:%s\n' "$(dlg zpoison5)" > "$AUDIT_DIR/deny.txt"
echo zpoison5 > "$AUDIT_DIR/keep.txt"
plan=$(run)
rm -f "$AUDIT_DIR/deny.txt" "$AUDIT_DIR/keep.txt"
{ ! grep -qE '^z[^ ]* .* denied-copy ' <<<"$plan" && grep -q 'first in zpoison5' <<<"$plan"; } \
  && ok "a kept repo whose delegate is denied still sets its file aside" \
  || no "a kept repo lost its file to the copies of it once its delegate was denied"

# A storage entry named like no repo id is left alone by --apply, before rad is asked to unseed
# or block it, however it got into the plan.
build_fixture; assert_isolated
e_tree zcode4 90 master "leak.mp4:6291456:same" "README.md:100"
cp -a "$STORAGE/zcode4" "$STORAGE/zcode_4"
leak=$(GIT_DIR="$STORAGE/zcode4" git rev-parse master:leak.mp4)
printf '%s\t6291456\trad:zgonesrc\t2026-10-02\n' "$leak" > "$AUDIT_DIR/deny-files.tsv"
out=$(RULES='' "${NOTTY[@]}" "$SCRIPT" --apply </dev/null 2>&1)
{ [ -e "$STORAGE/zcode_4" ] && [ ! -e "$STORAGE/zcode4" ] \
    && ! grep -q 'zcode_4' "$RSP_HOME/.stub_block" "$RSP_HOME/.stub_unseed" \
    && grep -qF "SKIP not a repo id, left alone: $STORAGE/zcode_4" <<<"$out"; } \
  && ok "an entry that is no repo id is left alone, neither blocked nor removed" \
  || no "--apply blocked or removed a storage entry that is no repo id"

# A row naming a restored repo stops condemning, and a row missing its size column must not
# read its date as the source. The cache is warm, so the list changing must send each repo to
# be checked again. zcode7 has lost the object of its other file, and zcode6 the commit of its
# other branch, so a listing of their branches stops part-way and would leave only the leak.
build_fixture; assert_isolated
e_tree zcode4 90 master "leak.mp4:6291456:same" "README.md:100"
e_tree zcode7 90 master "leak.mp4:6291456:same" "own.mp4:25165824:mp4"
own=$(GIT_DIR="$STORAGE/zcode7" git rev-parse master:own.mp4)
rm -f "$STORAGE/zcode7/objects/${own:0:2}/${own:2}"
e_tree zcode6 90 master "leak.mp4:6291456:same"
e_tree zcode6 90 refs/heads/y "own.mp4:25165824:mp4"
gone=$(GIT_DIR="$STORAGE/zcode6" git rev-parse refs/heads/y)
rm -f "$STORAGE/zcode6/objects/${gone:0:2}/${gone:2}"
leak=$(GIT_DIR="$STORAGE/zcode4" git rev-parse master:leak.mp4)
printf '%s - hand-list\n' "$(printf 1%.0s {1..40})" > "$AUDIT_DIR/deny-files.tsv"
plan=$(run)
printf '%s\t6291456\trad:zgonesrc\t2026-10-02\n' "$leak" > "$AUDIT_DIR/deny-files.tsv"
plan=$(run)
grep -qE "^zcode4 .* denied-copy " <<<"$plan" \
  && ok "a row added to the list reaches repos the cache already answered for" \
  || no "the cache hid a copy from a row added since"
{ ! grep -qE "^(zcode6|zcode7) .* denied-copy " <<<"$plan" && grep -qx '#   zcode6' <<<"$plan" \
  && grep -qx '#   zcode7' <<<"$plan"; } \
  && ok "a repo whose branches cannot be read to the end is named, not judged a copy" \
  || no "a repo with a missing object was judged on part of its bytes, or went unnamed"
echo zgonesrc > "$AUDIT_DIR/keep.txt"
printf '%s\trad:zgonesrc\t2026-10-02\n' "$leak" >> "$AUDIT_DIR/deny-files.tsv"
plan=$(run)
{ ! grep -qE "^zcode4 .* denied-copy " <<<"$plan" \
  && grep -q '1 row ignored as their source is kept' <<<"$plan" \
  && grep -qF 'is not "<object id> <bytes or -> <source> [date]"' <<<"$plan"; } \
  && ok "the rows of a restored repo are ignored, and a row missing a field is named" \
  || no "a restored repo's rows still condemned a copy, or a short row slipped through"
# The rows "quarantine files" prints are the ones the check counts: its delegates' media, and
# neither their text nor a stranger's push.
e_tree zrot2 90 master "leak.mp4:6291456:same" "README.md:100"
e_tree zrot2 90 "refs/namespaces/$STRANGER_NID/refs/heads/x" "theirs.mp4:6291456:mp4"
mkdir -p "$AUDIT_DIR/quarantine" && mv "$STORAGE/zrot2" "$AUDIT_DIR/quarantine/"
out=$("$SCRIPT" quarantine files zrot2 2>/dev/null); rc=$?
{ [ "$rc" = 0 ] && grep -qE $'^'"$leak"$'\t6291456\trad:zrot2\t[0-9-]+$' <<<"$out" \
  && [ "$(wc -l <<<"$out")" = 1 ]; } \
  && ok "quarantine files prints a row for its delegates' media and nothing else" \
  || no "quarantine files missed the delegates' media, or listed more (rc=$rc)"

# --- the ratchet: each rule against what that rule usually prunes --- A weekly plan that
# doubles every month never hits a fixed cap, so the baseline is the past audit logs. Per rule,
# so one rule's wave holds back only that rule.
build_fixture; assert_isolated
for i in 1 2 3 4; do past_run "$i" $USUAL_BUT_C; done
dry=$(RATCHET_FLOOR=0 "$SCRIPT" 2>&1)
grep -q 'HELD BACK as these rules' <<<"$dry" && grep -q '#          the stale rule (C): ' <<<"$dry" \
  && ! grep -q '#          the junk-name rule (A): ' <<<"$dry" \
  && ok "a dry run says which rule an unattended apply would hold back" \
  || no "the dry run did not name the rule the ratchet would hold"
out=$(RATCHET_FLOOR=0 "${NOTTY[@]}" "$SCRIPT" --apply </dev/null 2>&1); rc=$?
{ [ "$rc" = 4 ] && grep -q '^# HELD BACK the stale rule (C): ' <<<"$out" \
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
{ [ "$rc" = 0 ] && [ ! -e "$STORAGE/ztwoyr3" ] && ! grep -q '^# HELD BACK ' <<<"$out"; } \
  && ok "--force still gets past the history ratchet" \
  || no "--force could not override the ratchet (rc=$rc)"

# The floor is what lets an ordinary week through when a rule's usual is 0.
build_fixture; assert_isolated
for i in 1 2 3 4; do past_run "$i" $USUAL_BUT_C; done
out=$("${NOTTY[@]}" "$SCRIPT" --apply </dev/null 2>&1); rc=$?
{ [ "$rc" = 0 ] && [ ! -e "$STORAGE/ztwoyr3" ]; } \
  && ok "a rule under RATCHET_FLOOR is never held, however small its usual" \
  || no "the ratchet held back a handful of repos from a rule that usually prunes none (rc=$rc)"

# Two past runs are too little history to be a baseline.
build_fixture; assert_isolated
for i in 1 2; do past_run "$i" junk-name:1; done
out=$(RATCHET_FLOOR=0 "${NOTTY[@]}" "$SCRIPT" --apply </dev/null 2>&1); rc=$?
{ [ "$rc" = 0 ] && [ ! -e "$STORAGE/zjunk1" ] && [ ! -e "$STORAGE/ztwoyr3" ]; } \
  && ok "two past runs are not enough history to ratchet against" \
  || no "the ratchet fired on a baseline too thin to mean anything (rc=$rc)"

# A run that held a rule back, or ran with it off, could prune nothing for that rule, so it
# is no sample of the rule's usual.
# Counted as zeros, the three of each below would drag C's median of 4 down to 2.
build_fixture; assert_isolated
for i in 1 2 3; do past_run "$i" $REST stale:4; done
for i in 4 5 6; do past_run "$i" $REST held:C; done
for i in 7 8 9; do past_run "$i" $REST rules:ABDEFG; done
out=$(RATCHET_RUNS=9 RATCHET_FACTOR=1 RATCHET_FLOOR=0 "${NOTTY[@]}" "$SCRIPT" --apply \
        </dev/null 2>&1); rc=$?
{ [ "$rc" = 0 ] && [ ! -e "$STORAGE/ztwoyr3" ]; } \
  && ok "a run that held a rule, or ran without it, is no sample of what that rule prunes" \
  || no "held or switched-off runs dragged a rule's usual down to a hold (rc=$rc)"

# A rule's usual comes from the last runs it could prune in, however far back. Read from the
# last three runs alone, C would have no sample and be held at the floor.
build_fixture; assert_isolated
for i in 1 2 3; do past_run "$i" $REST stale:4; done
for i in 4 5 6; do past_run "$i" $REST rules:ABDEFG; done
out=$(RATCHET_RUNS=3 RATCHET_FACTOR=1 RATCHET_FLOOR=0 "${NOTTY[@]}" "$SCRIPT" --apply \
        </dev/null 2>&1); rc=$?
{ [ "$rc" = 0 ] && [ ! -e "$STORAGE/ztwoyr3" ]; } \
  && ok "a rule's usual reaches back past the runs it waited in" \
  || no "a rule that waited for its last runs was judged against the floor (rc=$rc)"

# A repo pruned again after an undo let it back is not a new verdict, on the past side as on
# this run's. Runs 2 and 3 prune run 1's three repos again, so C's usual is 0, not 3.
build_fixture; assert_isolated
for i in 1 2 3; do past_run "$i" $REST stale:3; done
sed -i 's/^zpast[23]/zpast1/' "$AUDIT_DIR"/prune-2026010[23]T000000Z.log
out=$(RATCHET_FLOOR=1 "${NOTTY[@]}" "$SCRIPT" --apply </dev/null 2>&1); rc=$?
{ [ "$rc" = 4 ] && grep -q $'^C\t4\t0\t1$' "$AUDIT_DIR/last-run/held.tsv"; } \
  && ok "a repo pruned again in a past run does not raise its rule's usual" \
  || no "repeat prunes in past runs set the usual a wave is measured against (rc=$rc)"

# Two samples are no median: after six held weeks and one forced run, C's window holds that
# forced wave and one ordinary week, and three times their mean would wave the next wave
# through.
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

# The caps are measured on what the ratchet leaves: the 40-repo plan is over a cap of 37, the
# 36 left once rule C's 4 are held are not, so the rest still goes ahead.
build_fixture; assert_isolated
for i in 1 2 3 4; do past_run "$i" $USUAL_BUT_C; done
out=$(MAX_PRUNE_COUNT=37 RATCHET_FLOOR=0 "${NOTTY[@]}" "$SCRIPT" --apply </dev/null 2>&1); rc=$?
{ [ "$rc" = 4 ] && [ -e "$STORAGE/ztwoyr3" ] && [ ! -e "$STORAGE/zjunk1" ]; } \
  && ok "a held wave does not trip the caps for the rest of the plan" \
  || no "the caps counted repos the ratchet had already held back (rc=$rc)"

# Rotated logs thin the ratchet's baseline, and under three readable logs it holds nothing, so
# the run says so.
build_fixture; assert_isolated
for i in 1 2 3 4; do past_run "$i" $USUAL_BUT_C; done
rm "$AUDIT_DIR"/prune-20260103T000000Z.log "$AUDIT_DIR"/prune-20260104T000000Z.log
out=$(RATCHET_FLOOR=0 "$SCRIPT" 2>&1)
grep -q 'cannot read 2 of the 4 most recent audit logs' <<<"$out" \
  && ok "the ratchet says when the audit logs it measures against are gone" \
  || no "missing audit logs thinned the ratchet's baseline without a word"
# A value bash cannot read as a number abandons the guard it sits in, awk reads a word as 0,
# and 010 is octal 8. The quarantine verb shows the check runs before them too.
bad=""
for setting in RATCHET_FLOOR=twenty MAX_PRUNE_GB=80G MAX_SCAN_FAIL_PCT=2.5 NEAR_PCT=08 \
               STALE_YEARS_DAYS=2y QUARANTINE_DAYS=010 JUNK_STALE_DAYS=9999999999999 \
               SPAM_REQUIRE_ID=yes MALWARE_PRUNE=yes RULES=abc MEDIA_EXTS="mp4|'x" UNDO_MAX_GB=9999999999; do
  out=$(env "$setting" "$SCRIPT" quarantine purge 2>&1); rc=$?
  { [ "$rc" = 2 ] && grep -q "^# ${setting%%=*} " <<<"$out"; } || bad="$bad $setting:$rc"
done
[ -z "$bad" ] \
  && ok "a setting with a value it cannot mean stops the run, quarantine verbs included" \
  || no "these settings were read anyway:$bad"

# --- a run that stops leaves the quarantine as it found it --- The stop makes a human look,
# and the last runs' verdicts they look at live only in the quarantine.
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
  && grep -q 'every verdict in the plan was held back' <<<"$out" \
  && grep -q 'purged 1 repo' <<<"$out"; } \
  && ok "a run whose whole plan is held back prunes nothing, and still purges what expired" \
  || no "a fully held run pruned something, or kept the quarantine's expired disk (rc=$rc)"

# The prompt through a pty (needs util-linux `script`). n aborts, y applies.
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

  # The prompt must say what the run does. Under quarantine the disk does not come back today,
  # so a prompt promising to reclaim it asks for a wrong yes.
  { grep -q 'quarantine' "$ROOT/n.out" && ! grep -q 'reclaiming' "$ROOT/n.out"; } \
    && ok "the confirmation prompt says quarantine, not reclaim, while quarantine is on" \
    || no "the apply prompt promised disk the quarantine is still holding"

  # At the critical threshold the run empties the whole quarantine. If that happened before
  # the prompt, answering no would destroy every recovery copy in a run that prunes nothing.
  CRIT="env DISK_AWARE=1 PRESSURE_CRIT_PCT=100 PRESSURE_CRIT_GB=999999 ABS_SIZE_FLOOR_MB=1"
  build_fixture; assert_isolated
  Q="$RSP_HOME/prune-audit/quarantine"; mkdir -p "$Q/zkeepme"
  printf 'n\n' | script -qec "$CRIT '$SCRIPT' --apply" /dev/null >"$ROOT/ncrit.out" 2>&1
  # "pressure 100%" in the banner proves the run was at the critical threshold.
  { grep -q aborted "$ROOT/ncrit.out" && grep -q ' pressure 100% ' "$ROOT/ncrit.out" \
    && [ -d "$Q/zkeepme" ]; } \
    && ok "answering no leaves the quarantine standing, critical free-space threshold or not" \
    || no "an aborted run had already emptied the whole quarantine before asking"

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

# The script runs from / so an unreadable launch dir cannot fail every find, and that must not
# change what a RELATIVE RAD_HOME/STORAGE/RAD meant to the caller. The keep list under a
# relative AUDIT_DIR is read too: zjunk1 is on it, and zbig2 shows the plan is real.
build_fixture; assert_isolated
mkdir -p "$RSP_HOME/prune-audit"; printf 'zjunk1\n' > "$RSP_HOME/prune-audit/keep.txt"
out=$(cd "$ROOT" && env RAD_HOME="./rad-home" STORAGE="./rad-home/storage" \
        CONFIG="./rad-home/config.json" AUDIT_DIR="./rad-home/prune-audit" \
        RAD="./bin/rad" "$SCRIPT" 2>&1); rc=$?
{ [ "$rc" = 0 ] && grep -qE '^zbig2 ' <<<"$out" && ! grep -qE '^zjunk1 ' <<<"$out" \
    && grep -q '# PLAN ' <<<"$out"; } \
  && ok "relative RAD_HOME/STORAGE/RAD/AUDIT_DIR survive the cwd anchor" \
  || no "relative paths survive cd / (rc=$rc)"

# Undo: which blocks a run lifts. A lift lets a repo back onto this seed, so a block that is a
# person's verdict, or that no audit log explains, stays. zundohand was blocked by hand;
# deny.txt names zundodeny, and the delegate recorded beside zundonid; zundospam's verdict did
# not change; zundonew was pruned by a version that had the change; zundogone's block is gone;
# zundoprior was blocked before rad-prune pruned it; zjunk1 is logged and blocked, yet in
# storage. zundotiny and zundobig were pruned for media by an older version, zundobig above the
# size that may come back, and zundofarm by the link-farm rule (E), which is gone. zundoquiet
# and zundoheavy were pruned by the stale rule (C), and zundohuge by the size rule (B), before
# those rules waited for disk pressure. The pardoned repo is lifted whatever its size and the
# budget; LIFTONE, listed in UNDO_LIFT, within the budget.
build_fixture; assert_isolated
DENYNID=z6MkgkW6TV5nSgbAraLxWj45jrnw7yRhK3bEgtaEpCVPKYkR
PARDONED=z3przuV9nGYpx5hmgPG65miGhS68Q
LIFTONE=z26kA476mDX7H1GWiUfCqTWPKLa6i
mkdir -p "$AUDIT_DIR"
printf 'zundodeny\ndid:key:%s\n' "$DENYNID" > "$AUDIT_DIR/deny.txt"
undo_log 20000101T000000Z '2026-01-01T00:00:00Z  pressure=0%' <<EOF
$(undo_row zundotiny 1048576 media-dump)
$(undo_row zundobig 104857600 media-dump)
$(undo_row zundofarm 1048576 link-farm)
$(undo_row zundoquiet 1048576 stale)
$(undo_row zundohuge 1048576 size-outlier)
$(undo_row zundoheavy 2000000000 stale)
$(undo_row "$LIFTONE" 1048576 junk-name)
$(undo_row zundodeny 1048576 media-dump)
$(undo_row zundonid 1048576 media-dump)
# delegates: rad:zundonid $DENYNID:-
$(undo_row zundospam 1048576 spam-batch)
$(undo_row zundogone 1048576 media-dump)
$(undo_row zundoprior 1048576 media-dump)
# was-blocked: rad:zundoprior
$(undo_row zjunk1 1048576 media-dump)
EOF
undo_log 20000301T000000Z '2026-03-01T00:00:00Z  version=0.8.0  pressure=0%' <<EOF
$(undo_row zundonew 1048576 media-dump)
$(undo_row "$PARDONED" 104857600 media-dump)
EOF
undo_block zundotiny zundobig zundofarm zundoquiet zundohuge zundoheavy "$LIFTONE" zundodeny zundonid zundospam zundonew \
           zundohand zundoprior "$PARDONED" zjunk1
DISK_AWARE=0 ABS_SIZE_FLOOR_MB=1 run >/dev/null
for pair in "zundohand:a block no audit log explains" "zundodeny:a repo deny.txt names" \
            "zundonid:a repo whose recorded delegate deny.txt names" \
            "zundospam:a verdict this version did not change" \
            "zundonew:a verdict this version reached" "zundogone:a repo no longer blocked" \
            "zundoprior:a block that stood before the prune" \
            "zjunk1:a repo still in storage"; do
  [ -z "$(undo_state "${pair%%:*}")" ] \
    && ok "the undo leaves alone ${pair#*:}" \
    || no "the undo would lift ${pair#*:} (${pair%%:*})"
done
{ [ "$(undo_state zundotiny)" = unblock ] && [ "$(undo_state zundobig)" = stays-blocked ] \
  && [ "$(undo_state zundofarm)" = unblock ] \
  && [ "$(undo_state "$PARDONED")" = unblock ] && [ ! -s "$RSP_HOME/.stub_unseed" ]; } \
  && ok "a dry run says which blocks would be lifted, and lifts none" \
  || no "a dry run misjudged the media or link-farm verdicts or the pardon, or lifted a block"
# The stale rule (C) prunes at any free space under DISK_AWARE=0, and under pressure, so its
# old block is lifted only on a disk with room, where the rule waits.
roomy=$(undo_state zundoquiet)
DISK_AWARE=1 PRESSURE_RELAX_PCT=0 PRESSURE_RELAX_GB=0 PRESSURE_CRIT_PCT=0 PRESSURE_CRIT_GB=0 \
  ABS_SIZE_FLOOR_MB=1 run >/dev/null
calm="$(undo_state zundoquiet) $(undo_state zundohuge) $(undo_state zundoheavy)"
DISK_AWARE=1 PRESSURE_RELAX_PCT=100 PRESSURE_RELAX_GB=0 PRESSURE_CRIT_PCT=0 PRESSURE_CRIT_GB=0 \
  ABS_SIZE_FLOOR_MB=1 run >/dev/null
tight=$(undo_state zundoquiet)
{ [ -z "$roomy" ] && [ "$calm" = "unblock unblock unblock" ] && [ -z "$tight" ]; } \
  && ok "an old size (B) or stale (C) block is lifted only while the disk has room" \
  || no "an old B or C block was lifted while the rules prune (DISK_AWARE=0: '$roomy'," \
        "pressure: '$tight') or kept on a disk with room ('$calm')"
# Lifted repos must not use that room up, or the rules prune them again under pressure. The
# relaxed threshold is set 1 to 2 GB under free space, which the 2 GB repo would cross.
# Rounded down: df rounds its own block counts up, which would leave under 1 GB of room.
avail_gb=$(df -P -B1 "$STORAGE" | awk 'NR == 2 { print int($4 / 1e9) }')
if [ "$avail_gb" -ge 3 ]; then
  DISK_AWARE=1 PRESSURE_RELAX_PCT=0 PRESSURE_RELAX_GB=$(( avail_gb - 1 )) PRESSURE_CRIT_PCT=0 \
    PRESSURE_CRIT_GB=0 ABS_SIZE_FLOOR_MB=1 run >/dev/null
  { [ "$(undo_state zundoheavy)" = unblock-later ] && [ "$(undo_state zundoquiet)" = unblock ]; } \
    && ok "a B or C lift that would bring the disk under pressure waits for a later run" \
    || no "a B or C lift used up the room that keeps those rules waiting"
else
  skip "the B or C lift headroom (under 3 GB free here)"
fi
DISK_AWARE=0 ABS_SIZE_FLOOR_MB=1 UNDO_MAX_COUNT=0 run >/dev/null
{ [ "$(undo_state zundotiny)" = unblock-later ] && [ "$(undo_state "$PARDONED")" = unblock ] \
  && [ "$(undo_state "$LIFTONE")" = unblock-later ]; } \
  && ok "UNDO_MAX_COUNT holds back a deleted repo and an UNDO_LIFT one, and not a pardoned one" \
  || no "UNDO_MAX_COUNT did not hold back a deleted or UNDO_LIFT repo, or held back the pardon"
DISK_AWARE=0 ABS_SIZE_FLOOR_MB=1 UNDO=0 run >/dev/null
[ -z "$(undo_state zundotiny)" ] \
  && ok "UNDO=0 plans no lift" || no "UNDO=0 still planned a lift"
if [ "$(id -u)" != 0 ]; then
  chmod 000 "$AUDIT_DIR/deny.txt"
  out=$(env DISK_AWARE=0 ABS_SIZE_FLOOR_MB=1 "$SCRIPT" 2>&1); rc=$?
  chmod 644 "$AUDIT_DIR/deny.txt"
  { [ "$rc" = 0 ] && grep -q "cannot read $AUDIT_DIR/deny.txt" <<<"$out" \
    && [ -z "$(undo_state zundotiny)" ]; } \
    && ok "an unreadable deny.txt plans no lift" \
    || no "an unreadable deny.txt still planned a lift, so the repos it names could come back"
else
  skip "an unreadable deny.txt (root reads any file)"
fi
# An empty plan with blocks to lift still asks a person at a terminal, and a no lifts nothing.
if command -v script >/dev/null 2>&1; then
  mkdir -p "$AUDIT_DIR/quarantine/zundoexpired"
  touch -d '30 days ago' "$AUDIT_DIR/quarantine/zundoexpired"
  out=$(printf 'n\n' | script -qec "env RULES=H DISK_AWARE=0 '$SCRIPT' --apply" /dev/null 2>&1)
  { grep -q 'aborted; no block was lifted' <<<"$out" && [ ! -s "$RSP_HOME/.stub_unseed" ] \
    && [ -d "$AUDIT_DIR/quarantine/zundoexpired" ]; } \
    && ok "an empty plan asks before lifting a block, and a no lifts and purges nothing" \
    || no "an empty plan lifted a block without asking, or a no still lifted or purged"
  rm -rf "$AUDIT_DIR/quarantine/zundoexpired"
else
  skip "the empty-plan prompt (no util-linux 'script' for a pty)"
fi

# Applying lifts exactly those blocks, without seeding, and only once per repo: a block an
# operator puts back by hand after the lift stays.
DISK_AWARE=0 ABS_SIZE_FLOOR_MB=1 "${NOTTY[@]}" "$SCRIPT" --apply </dev/null >/dev/null 2>&1
lifted=$(grep -E 'zundo|z3przu' "$RSP_HOME/.stub_unseed" | sort | tr '\n' ' ')
{ [ "$lifted" = "rad:$PARDONED rad:zundofarm rad:zundotiny " ] \
  && ! grep -qE 'zundo|z3przu' "$RSP_HOME/.stub_seed" 2>/dev/null \
  && grep -q '^# unblocked: rad:zundotiny ' "$AUDIT_DIR"/prune-20[1-9]*.log; } \
  && ok "--apply lifts the blocks the dry run named, seeds none, and logs each lift" \
  || no "--apply lifted the wrong blocks, seeded one, or left no log line: $lifted"
{ grep -q '^# was-blocked: rad:zjunk1$' "$AUDIT_DIR"/prune-20[1-9]*.log \
  && ! grep -q '^# was-blocked: rad:zbig2$' "$AUDIT_DIR"/prune-20[1-9]*.log; } \
  && ok "a prune records a block that stood before it, and only that one" \
  || no "a prune did not record the block that stood before it, or recorded one that did not"
undo_block zundotiny
: > "$RSP_HOME/.stub_unseed"
DISK_AWARE=0 ABS_SIZE_FLOOR_MB=1 "${NOTTY[@]}" "$SCRIPT" --apply </dev/null >/dev/null 2>&1
! grep -q 'zundotiny' "$RSP_HOME/.stub_unseed" \
  && ok "a repo whose block was lifted once is not lifted again" \
  || no "a block lifted once was lifted a second time"

# A log from before delegates were recorded leaves the quarantined copy to name them, and a
# delegate deny.txt names keeps the block.
build_fixture; assert_isolated
mkdir -p "$AUDIT_DIR/quarantine"
mv "$STORAGE/zbwid9" "$AUDIT_DIR/quarantine/"
printf 'did:key:%s\n' "$(dlg zbwid9)" > "$AUDIT_DIR/deny.txt"
undo_log 20000101T000000Z '2026-01-01T00:00:00Z  pressure=0%' <<EOF
$(undo_row zbwid9 2000 media-dump)
$(undo_row zundotiny 2000 media-dump)
EOF
undo_block zbwid9 zundotiny
DISK_AWARE=0 ABS_SIZE_FLOOR_MB=1 run >/dev/null
{ [ -z "$(undo_state zbwid9)" ] && [ "$(undo_state zundotiny)" = unblock ]; } \
  && ok "the undo leaves alone a quarantined repo whose delegate deny.txt names" \
  || no "the undo would lift a quarantined repo whose delegate deny.txt names"

# A listing that fails lifts nothing, and a lift that fails is not logged, so a later run
# tries again.
build_fixture; assert_isolated
undo_log 20000101T000000Z '2026-01-01T00:00:00Z  pressure=0%' <<EOF
$(undo_row zundotiny 1048576 media-dump)
EOF
undo_block zundotiny
out=$(DISK_AWARE=0 ABS_SIZE_FLOOR_MB=1 RSP_SEED_LIST_FAIL=1 "${NOTTY[@]}" "$SCRIPT" --apply \
        </dev/null 2>&1)
{ ! grep -q 'zundotiny' "$RSP_HOME/.stub_unseed" 2>/dev/null \
  && grep -q 'database is locked' <<<"$out"; } \
  && ok "a failed 'rad seed' listing lifts nothing and says why" \
  || no "a failed 'rad seed' listing still lifted a block, or said nothing"
# rc.12 lists a blocked repo with its scope, so this run reads that form of the listing.
out=$(DISK_AWARE=0 ABS_SIZE_FLOOR_MB=1 RSP_UNSEED_FAIL=1 RSP_SEED_SCOPED=1 "${NOTTY[@]}" \
        "$SCRIPT" --apply </dev/null 2>&1)
{ grep -q 'unblocked 0 repos, 1 failed' <<<"$out" \
  && ! grep -q '^# unblocked: rad:zundotiny' "$AUDIT_DIR"/prune-20[1-9]*.log; } \
  && ok "a lift that fails is reported and not logged as a lift" \
  || no "a failed lift was logged as done, or not reported"
# A repo left blocked by mistake wants a person, so the run exits 1 though it pruned nothing.
out1=$(RULES=H RSP_UNSEED_FAIL=1 RSP_SEED_SCOPED=1 "${NOTTY[@]}" "$SCRIPT" --apply \
         </dev/null 2>&1); rc=$?
{ [ "$rc" = 1 ] && grep -q 'unblocked 0 repos, 1 failed' <<<"$out1"; } \
  && ok "a run whose only lift fails exits 1" \
  || no "a run whose only lift fails exited $rc"

# Undo from the quarantine puts the repo back in storage for the next run to judge. zjunk1 is
# still junk-named; zbwid9 is spared by the current rules. A run a runaway cap stops lifts
# nothing, so both stay quarantined, blocked, with their window. Neither goes on the keep list,
# since a later verdict may be right.
build_fixture; assert_isolated
Q="$AUDIT_DIR/quarantine"; mkdir -p "$Q"
mv "$STORAGE/zjunk1" "$STORAGE/zbwid9" "$Q/"
touch -d '3 days ago' "$Q/zjunk1" "$Q/zbwid9"
before=$(stat -c %Y "$Q/zjunk1")
undo_log 20000101T000000Z '2026-01-01T00:00:00Z  pressure=0%' <<EOF
$(undo_row zjunk1 2000 media-dump)
$(undo_row zbwid9 2000 media-dump)
EOF
undo_block zjunk1 zbwid9
DISK_AWARE=0 ABS_SIZE_FLOOR_MB=1 MAX_PRUNE_COUNT=1 "${NOTTY[@]}" "$SCRIPT" --apply </dev/null \
  >/dev/null 2>&1; rc=$?
{ [ "$rc" = 3 ] && [ -d "$Q/zjunk1" ] && [ -d "$Q/zbwid9" ] && [ ! -e "$STORAGE/zjunk1" ] \
  && [ "$(stat -c %Y "$Q/zjunk1")" = "$before" ] \
  && ! grep -qE 'zjunk1|zbwid9' "$RSP_HOME/.stub_unseed" 2>/dev/null; } \
  && ok "a run the runaway caps stop lifts no block and moves nothing out of the quarantine" \
  || no "a stopped run lifted a block or moved a repo out of the quarantine (rc=$rc)"
DISK_AWARE=0 ABS_SIZE_FLOOR_MB=1 "${NOTTY[@]}" "$SCRIPT" --apply </dev/null >/dev/null 2>&1
{ [ -d "$STORAGE/zjunk1" ] && [ -d "$STORAGE/zbwid9" ] && [ ! -e "$Q/zjunk1" ] \
  && grep -q '^# unblocked: rad:zjunk1 .* local_copy=quarantined' "$AUDIT_DIR"/prune-20[1-9]*.log; } \
  && ok "--apply moves a repo due back out of the quarantine and lifts its block" \
  || no "a repo due back stayed in the quarantine, or its lift was not logged"
DISK_AWARE=0 ABS_SIZE_FLOOR_MB=1 "${NOTTY[@]}" "$SCRIPT" --apply </dev/null >/dev/null 2>&1
{ [ -d "$Q/zjunk1" ] && [ ! -e "$STORAGE/zjunk1" ] && [ -d "$STORAGE/zbwid9" ] \
  && grep -qE $'^zjunk1\t.*\tjunk-name\t' "$AUDIT_DIR"/prune-20[1-9]*.log \
  && ! grep -qE '^(zjunk1|zbwid9)$' "$AUDIT_DIR/keep.txt" 2>/dev/null; } \
  && ok "the next run judges a repo back from the quarantine, and keeps none" \
  || no "a repo back from the quarantine went unjudged, or landed on the keep list"

# Revival: a repo pruned as left alone comes back when one of its delegates pushes. The node
# signs nothing for anyone else, so only a node announcing its own refs counts. These leave the
# block: a stranger relaying the delegate's refs, refs the delegate already had at the prune,
# an announcement from before the prune, a non-delegate pushing its own refs (zrvstranger), and
# a verdict a push says nothing about. A block from a version that recorded no delegates lifts
# on any node's own announcement after it, and not on a relay of another's refs (zrvhearsay).
build_fixture; assert_isolated
if command -v sqlite3 >/dev/null 2>&1; then
  K1=$(printf '1%.0s' {1..64}); N1=z6Mkfbt52NAcPcYKV36L6eWTnyfxyGrGrxvJBxF5pjjCctGQ
  K2=$(printf '2%.0s' {1..64}); N2=z6MkgkW6TV5nSgbAraLxWj45jrnw7yRhK3bEgtaEpCVPKYkR
  OLD=$(printf 'a%.0s' {1..40}); NEW=$(printf 'c%.0s' {1..40}); RID=$(printf '0%.0s' {1..40})
  undo_log 20000201T000000Z '2026-01-01T00:00:00Z  version=0.8.0  pressure=0%' <<EOF
$(undo_row zrvnew 2000 stale)
# delegates: rad:zrvnew $N1:$OLD
$(undo_row zrvproxy 2000 stale)
# delegates: rad:zrvproxy $N1:$OLD
$(undo_row zrvsame 2000 stale)
# delegates: rad:zrvsame $N1:$OLD
$(undo_row zrvprior 2000 stale)
# delegates: rad:zrvprior $N1:$OLD
$(undo_row zrvspam 2000 spam-batch)
# delegates: rad:zrvspam $N1:$OLD
$(undo_row zrvstranger 2000 stale)
# delegates: rad:zrvstranger $N1:$OLD
EOF
  undo_log 20000101T000000Z '2025-12-01T00:00:00Z  pressure=0%' <<EOF
$(undo_row zrvaged 2000 junk-name)
$(undo_row zrvhearsay 2000 junk-name)
EOF
  undo_block zrvnew zrvproxy zrvsame zrvprior zrvspam zrvaged zrvhearsay zrvstranger
  after=1769904000000; earlier=1765756800000          # 2026-02-01 and 2025-12-15
  # One refs announcement: $1 the announcing node, $2 the repo, $3 the key of its one remote,
  # $4 that remote's signed refs, $5 when, in ms.
  ann(){
    printf "insert into announcements values ('%s', 'rad:%s', 'refs', %s, %s);\n" \
           "$1" "$2" "X'0014${RID}0001${3}0014${4}0000000000000000'" "$5"
  }
  mkdir -p "$RSP_HOME/node"
  { echo "create table announcements" \
         "(node text, repo text, type text, message blob, timestamp integer);"
    ann "$N1" zrvnew "$K1" "$NEW" "$after"
    ann "$N2" zrvproxy "$K1" "$NEW" "$after"
    ann "$N1" zrvsame "$K1" "$OLD" "$after"
    ann "$N1" zrvprior "$K1" "$NEW" "$earlier"
    ann "$N1" zrvspam "$K1" "$NEW" "$after"
    ann "$N2" zrvaged "$K2" "$NEW" "$earlier"
    ann "$N2" zrvhearsay "$K1" "$NEW" "$earlier"
    ann "$N2" zrvstranger "$K2" "$NEW" "$after"; } | sqlite3 "$RSP_HOME/node/node.db"
  DISK_AWARE=0 ABS_SIZE_FLOOR_MB=1 run >/dev/null
  revived=$(awk -F'\t' '$3 == "active-since-prune" { print $1 }' "$AUDIT_DIR/last-run/unprune-plan.tsv" \
              | sort | tr '\n' ' ')
  [ "$revived" = "zrvaged zrvnew " ] \
    && ok "only a delegate's own new refs after the prune revive a repo pruned as left alone" \
    || no "revival trusted the wrong announcements: $revived"
  printf 'did:key:%s\n' "$N2" > "$AUDIT_DIR/deny.txt"
  DISK_AWARE=0 ABS_SIZE_FLOOR_MB=1 run >/dev/null
  { [ -z "$(undo_state zrvaged)" ] && [ "$(undo_state zrvnew)" = unblock ]; } \
    && ok "an identity deny.txt names revives nothing by announcing its own refs" \
    || no "a denied identity's own announcement revived a repo"
else
  skip "revival (sqlite3 is not installed)"
fi

# A repo a person writes into keep.txt after rad-prune quarantined it comes back, its block
# lifted and its seeding restored, as quarantine restore would bring it, whatever its verdict.
build_fixture; assert_isolated
Q="$AUDIT_DIR/quarantine"; mkdir -p "$Q"
mv "$STORAGE/zjunk1" "$Q/"; touch -d '30 days ago' "$Q/zjunk1"
undo_log 20000101T000000Z '2026-01-01T00:00:00Z  pressure=0%' <<EOF
$(undo_row zjunk1 2000 junk-name)
EOF
undo_block zjunk1
# zbar8 has no block this tool made, so it waits there for a person.
mv "$STORAGE/zbar8" "$Q/"
printf 'zjunk1  # a person keeps it\nzbar8\n' > "$AUDIT_DIR/keep.txt"
out=$(RULES=H DISK_AWARE=0 "${NOTTY[@]}" "$SCRIPT" --apply --yes </dev/null 2>&1); rc=$?
{ [ "$rc" = 0 ] && [ -d "$STORAGE/zjunk1" ] && [ ! -e "$Q/zjunk1" ] \
    && [ "$(grep 'rad:zjunk1$' "$RSP_HOME/.stub_policy" | tail -2 | tr '\n' ' ')" \
         = "unseed rad:zjunk1 seed rad:zjunk1 " ] \
    && grep -q '^# unblocked: rad:zjunk1 why=kept ' "$AUDIT_DIR"/prune-20[1-9]*.log; } \
  && ok "a quarantined repo put in keep.txt is moved back, unblocked and seeded" \
  || no "a quarantined repo in keep.txt stayed blocked in the quarantine (rc=$rc)"
{ [ -d "$Q/zbar8" ] && grep -qx '#   zbar8' <<<"$out" && ! grep -qx '#   zjunk1' <<<"$out"; } \
  && ok "a kept repo the run cannot bring back from the quarantine is named" \
  || no "a kept repo stuck in the quarantine went unnamed, or one brought back was named"

# A repo that leaves storage between its block and its move has nothing to take the place of
# its older quarantined copy, so that copy stays.
build_fixture; assert_isolated
Q="$AUDIT_DIR/quarantine"; mkdir -p "$Q/zjunk1"
echo older > "$Q/zjunk1/marker"
RSP_BLOCK_VANISH=1 RULES=A DISK_AWARE=0 "${NOTTY[@]}" "$SCRIPT" --apply --yes </dev/null \
  >/dev/null 2>&1
[ "$(cat "$Q/zjunk1/marker" 2>/dev/null)" = older ] \
  && ok "the older quarantined copy of a repo gone from storage before its move stays" \
  || no "the only copy left of a repo was removed from the quarantine"

# The ratchet sets aside a repo its rule prunes again after the undo let it back, the size (B)
# and stale (C) rules counting as one. A repo a person brought back by hand, or one lifted
# from another rule's verdict, is a new verdict.
build_fixture; assert_isolated
for i in 1 2 3; do past_run "$i" $REST; done
run >/dev/null
stale=$(awk -F'\t' '!/^#/ && $5 == "stale" { print $1 }' "$AUDIT_DIR/last-run/plan.tsv")
for r in $stale; do undo_row "$r" 2000 stale; done \
  | undo_log 20260104T000000Z '2026-01-04T00:00:00Z  pressure=0%'
RATCHET_FLOOR=1 run >/dev/null
byhand=$(grep -c $'^C\t' "$AUDIT_DIR/last-run/held.tsv")
for r in $stale; do printf '# unblocked: rad:%s why=verdict-withdrawn reason=junk-name\n' "$r"
done | undo_log 20260105T000000Z '2026-01-05T00:00:00Z  pressure=0%'
RATCHET_FLOOR=1 run >/dev/null
otherrule=$(grep -c $'^C\t' "$AUDIT_DIR/last-run/held.tsv")
for r in $stale; do
  printf '# unblocked: rad:%s why=verdict-withdrawn reason=size-outlier\n' "$r"
done | undo_log 20260106T000000Z '2026-01-06T00:00:00Z  pressure=0%'
RATCHET_FLOOR=1 run >/dev/null
lifted=$(grep -c $'^C\t' "$AUDIT_DIR/last-run/held.tsv")
{ [ -n "$stale" ] && [ "$byhand" = 1 ] && [ "$otherrule" = 1 ] && [ "$lifted" = 0 ]; } \
  && ok "the ratchet counts a repo restored by hand or lifted from another rule, not a repeat" \
  || no "the ratchet's exemption for repeats is wrong (by hand: $byhand, other: $otherrule, lifted: $lifted)"

# UNDO_LIFT names repos wrongly pruned as junk-name, so it lifts nothing else: LIFTONE's newest
# verdict here is stale, which waits for the disk to have room like any other. A pardon spares
# its repo the media rule (F) alone, and the stale rule (C) still prunes it.
build_fixture; assert_isolated
LIFTONE=z26kA476mDX7H1GWiUfCqTWPKLa6i
PARDONED=z3przuV9nGYpx5hmgPG65miGhS68Q
undo_log 20000101T000000Z '2026-01-01T00:00:00Z  pressure=80%' <<EOF
$(undo_row "$LIFTONE" 1500000000 stale)
EOF
undo_block "$LIFTONE"
DISK_AWARE=1 PRESSURE_RELAX_PCT=100 PRESSURE_RELAX_GB=0 PRESSURE_CRIT_PCT=0 PRESSURE_CRIT_GB=0 \
  ABS_SIZE_FLOOR_MB=1 run >/dev/null
[ -z "$(undo_state "$LIFTONE")" ] \
  && ok "an UNDO_LIFT entry does not lift a block made under another verdict" \
  || no "UNDO_LIFT lifted a stale block under pressure ($(undo_state "$LIFTONE"))"
cp -a "$STORAGE/zmediaone" "$STORAGE/$PARDONED"
printf '%s\tshots\t2\tpublic\t0\t60\t100\tscreenshots\n' "$PARDONED" >> "$RSP_MANIFEST"
asmedia=$(run)
rm -rf "${STORAGE:?}/$PARDONED"; cp -a "$STORAGE/ztwoyr3" "$STORAGE/$PARDONED"
sed -i "/^$PARDONED\t/d" "$RSP_MANIFEST"
printf '%s\tshots\t4\tpublic\t0\t800\t2000\tscreenshots\n' "$PARDONED" >> "$RSP_MANIFEST"
asstale=$(run)
{ has "$asmedia" zmediaone && ! has "$asmedia" "$PARDONED" \
    && grep -qE "^$PARDONED .* stale " <<<"$asstale"; } \
  && ok "a pardon spares its repo the media rule (F) and no other" \
  || no "a pardoned repo was pruned as media, or spared the stale rule (C)"

# Every repo coming back takes room, so the size (B) and stale (C) lifts are weighed after all
# the others, and against repos earlier runs lifted that the node has not fetched yet. The
# relaxed threshold sits 2 to 3 GB under free space.
build_fixture; assert_isolated
avail_gb=$(df -P -B1000000000 "$STORAGE" | awk 'NR == 2 { print $4 }')
if [ "$avail_gb" -ge 4 ]; then
  undo_log 20000101T000000Z '2026-01-01T00:00:00Z  pressure=0%' <<EOF
$(undo_row zroomfarm1 500000000 link-farm)
$(undo_row zroomfarm2 500000000 link-farm)
$(undo_row zroomfarm3 500000000 link-farm)
$(undo_row zroomfarm4 500000000 link-farm)
$(undo_row zroomquiet 1500000000 stale)
EOF
  undo_block zroomfarm1 zroomfarm2 zroomfarm3 zroomfarm4 zroomquiet
  # Free space is read again for each run, since other work on this disk moves it. df rounds
  # it up to the next GB.
  room(){
    local gb; gb=$(df -P -B1000000000 "$STORAGE" | awk 'NR == 2 { print $4 }')
    DISK_AWARE=1 PRESSURE_RELAX_PCT=0 PRESSURE_RELAX_GB=$(( gb - 3 )) \
      PRESSURE_CRIT_PCT=0 PRESSURE_CRIT_GB=0 RULES=H "$@"
  }
  room run >/dev/null
  { [ "$(undo_state zroomfarm4)" = unblock ] && [ "$(undo_state zroomquiet)" = unblock-later ]; } \
    && ok "a B or C lift is weighed against the room every other lift takes" \
    || no "a B or C lift used room other lifts take ($(undo_state zroomquiet))"
  # Replaces the log above, so only these two are lifted.
  undo_log 20000101T000000Z '2026-01-01T00:00:00Z  pressure=0%' <<EOF
$(undo_row zroomquietA 1500000000 stale)
$(undo_row zroomquietB 1900000000 stale)
EOF
  undo_block zroomquietA zroomquietB
  # Only a node that seeds what it is offered fetches a lifted repo by itself.
  cp "$CONFIG" "$ROOT/config.saved"
  jq '.node.seedingPolicy.default = "allow"' "$ROOT/config.saved" > "$CONFIG"
  room "${NOTTY[@]}" "$SCRIPT" --apply --yes </dev/null >/dev/null 2>&1
  room run >/dev/null
  allow=$(undo_state zroomquietB)
  cp "$ROOT/config.saved" "$CONFIG"
  room run >/dev/null
  block=$(undo_state zroomquietB)
  { grep -q '^# unblocked: rad:zroomquietA ' "$AUDIT_DIR"/prune-20[1-9]*.log \
      && [ "$allow" = unblock-later ] && [ "$block" = unblock ]; } \
    && ok "a B or C lift is weighed against earlier lifts the node will fetch, and no other" \
    || no "earlier lifts were weighed wrongly (allow: $allow, block: $block)"
else
  skip "the B or C lift headroom (under 4 GB free here)"
fi

# --- colour --- on a terminal the output is coloured by one filter, and the text under the
# colour is the text a pipe gets. FORCE_COLOR stands in for the terminal.
build_fixture; assert_isolated
# No cache, so every run reads every repo afresh. A run reports changes since the last one, so
# the coloured run is compared with the plain run after it, which also follows a run.
plain=$(CACHE=0 DISK_AWARE=0 run)
coloured=$(FORCE_COLOR=1 CACHE=0 DISK_AWARE=0 run)
plain_again=$(CACHE=0 DISK_AWARE=0 run)
[ -z "${RSP_DUMP_COLOUR:-}" ] || { printf "%s\n" "$coloured" > "$RSP_DUMP_COLOUR"; printf "%s\n" "$plain" > "$RSP_DUMP_COLOUR.plain"; }
esc=$'\033'
# The title's clock and the phases' timings differ between two runs.
untimed() { grep -v -e '^# rad-prune ' -e '^# \[' ; }
stripped=$(sed "s/$esc\[[0-9;]*m//g" <<<"$coloured")
{ ! grep -q "$esc" <<<"$plain" \
  && grep -q "^${esc}\[2m#${esc}\[0m ${esc}\[1mrad-prune [^ ]*${esc}\[0m  ${esc}\[1m${esc}\[32mDRY RUN" \
       <<<"$coloured" \
  && grep -qE "^${esc}\[2mzjunk1${esc}\[0m .*${esc}\[31mjunk-name${esc}\[0m" <<<"$coloured" \
  && [ "$(untimed <<<"$stripped")" = "$(untimed <<<"$plain_again")" ]; } \
  && ok "FORCE_COLOR colours the run, over the same text a pipe gets" \
  || no "the coloured run differs from the plain one, or carries no colour"
nocolour=$(NO_COLOR=1 FORCE_COLOR=1 DISK_AWARE=0 run)
! grep -q "$esc" <<<"$nocolour" \
  && ok "NO_COLOR wins over FORCE_COLOR" \
  || no "NO_COLOR left colour in the output"

# --- lint --- shellcheck warnings over the script and the suite's shell. An rm -rf that can
# expand to "/", or a variable set and never read, is a bug this tool can least afford. The
# worker code in quoted heredocs is beyond shellcheck. --norc and no SHELLCHECK_OPTS, so
# nothing on this machine can turn a check off. The fixture build only opens the section.
build_fixture
if command -v shellcheck >/dev/null; then
  if lint=$(env -u SHELLCHECK_OPTS shellcheck --norc -S warning \
             "$SCRIPT" "$HERE/run.sh" "$HERE"/*-shim "$HERE/rad-stub" 2>&1)
  then ok "shellcheck finds no warning"
  else no "shellcheck $(shellcheck --version | awk '/^version:/ { print $2 }') warns:"; echo "$lint"
  fi
else
  skip "shellcheck (not installed)"
fi

# ---- end of sections -------------------------------------------------------
summary
