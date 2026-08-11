# radicle-seed-prune

[![Sponsor maninak on Liberapay](https://img.shields.io/badge/Liberapay-Donate-F6C915?logo=liberapay&logoColor=black)](https://liberapay.com/maninak/donate)

[![version](https://img.shields.io/github/v/release/maninak/radicle-seed-prune?sort=semver&label=version&color=44CC11)](https://github.com/maninak/radicle-seed-prune/releases/latest)
[![License: PolyForm Noncommercial 1.0.0](https://img.shields.io/badge/License-PolyForm%20Noncommercial%201.0.0-orange.svg)](./LICENSE)
[![Shell](https://img.shields.io/badge/shell-bash-121011.svg?logo=gnu-bash&logoColor=white)](./radicle-seed-prune)
[![rad: - zxvTkxzouwrYFwycnsctrMT3iM2E](https://img.shields.io/static/v1?label=rad%3A&message=zxvTkxzouwrYFwycnsctrMT3iM2E&color=6666FF&cacheSeconds=64800)](https://app.radicle.at/nodes/seed.radicle.at/rad:zxvTkxzouwrYFwycnsctrMT3iM2E)

**Reclaim disk on a [Radicle](https://radicle.dev) seed by safely pruning lower-value repos.**

A seed that seeds everything mirrors the whole public network and grows without bounds. This tool picks out the repos least worth holding (stale giants, long-abandoned repos, obviously disposable ones, spam) and prunes them. It is a dry run unless you ask otherwise, it keeps the last copy it knows of unless the evidence is conclusive, and it tightens itself as free disk runs low.

One bash script, no dependencies beyond what a seed already has.

## Install

```sh
curl -O https://raw.githubusercontent.com/maninak/radicle-seed-prune/master/radicle-seed-prune
chmod +x radicle-seed-prune
```

Needs `bash`, `git`, `jq` and `rad` on `PATH`. Run it as the user that owns the Radicle home, or point `RAD_HOME` at one.

## Usage

```sh
./radicle-seed-prune                  # preview: print the plan, change nothing
./radicle-seed-prune --apply          # apply, asks [y/N] first when run in a terminal
./radicle-seed-prune --apply --yes    # apply without the prompt (scripts, cron)
./radicle-seed-prune --apply --force  # apply even if the plan trips the runaway caps
./radicle-seed-prune --apply --restart-node  # ...and restart the node afterwards
./radicle-seed-prune --version
```

**There is no `--dry-run` flag, because running with no flags is the dry run.** `--apply` scans once, prints that same plan, then asks `[y/N]` in a terminal and just applies when there is nobody to ask (cron, a pipe). One scan, not two.

Read the preview first. It is sorted largest-first and totals the disk it will free.

Every knob is an environment variable rather than a flag, so a run is configured the way `rad` itself is:

```sh
RAD_HOME=/var/lib/radicle ./radicle-seed-prune          # a seed home that isn't yours
RAD=/nix/store/.../bin/rad ./radicle-seed-prune         # a specific rad binary
```

### Example output

```text
# radicle-seed-prune 0.4.0  2026-08-11T23:20:54Z   mode=DRY-RUN
# home=/home/seed/.radicle
# disk: 126.9GB free (47.0%)  pressure=0% [relax>=54GB crit<=2GB]
# rules: A junk(>30d, seeds>=1; id-names seeds>=0)  B size(>500MB & >=P95, >90d, seeds>=3)  C stale(>730d, seeds>=3)  D spam(batch>=5 & desc>=80%, >7d, seeds>=0)
# rule E link-farm(>=5 spam domains, each linked from >=0.4% of repos and from the code of <10% of them, >7d, seeds>=0)
# rule F media-dump(>=64KB of media and <2048B of anything else, >7d, seeds>=1)  media-batch(that media held by >=5 repos, <65536B of anything else)
# excluded: 9 pinned, 6 private, 0 own
# spam batches: 10 template(s) matching 444 repos, before the age and seed checks:
#      54  evens-*-*
#   ...and 9 more
# scanning 11151 repos (size + activity), 5 parallel workers...
# measuring repo trees for rule F (5 workers)...
# harvesting referenced hosts from repo contents (5 workers)...
# harvested 272404 repo/host pairs over 9988 repos
# spam domains: 96 domain(s) linked from >=44 repos, <10% from code;
#   491 repo(s) link to >=5 of them, before the age and seed checks:
#     423 repos  somegallery.test
#   ...and 95 more
# rule E: 43 repo(s) spared, the spam links were pushed by peers that are not their delegates
# repos=11151  sizes P50=0M P90=10M P95=33M P99=199M rel-cut(P95)=33M  abs-cut=500M
# skipped: 0 unreadable, 108 written in the last 2d, 1 with no readable refs

RID                                     SIZE  SEEDS   AGE(d) REASON        NAME
zEXAMPLExxxxxxxxxxxxxxxxxxxxx1       409.5MB     14      184 media-batch   init
zEXAMPLExxxxxxxxxxxxxxxxxxxxx2       330.8MB     13      190 media-dump    PlayDrive
zEXAMPLExxxxxxxxxxxxxxxxxxxxx3       127.6MB     12      229 junk-name     someproject-test
zEXAMPLExxxxxxxxxxxxxxxxxxxxx4       512.3KB     11       94 link-farm     photo-album-nine
zEXAMPLExxxxxxxxxxxxxxxxxxxxx5       100.4KB     11       31 spam-batch    flatten-2-33ed7115

# PLAN: prune 519 repos, reclaim 2.51 GiB
#   junk-name         2 repos      0.00 GiB
#   link-farm        34 repos      0.40 GiB
#   media-batch      23 repos      1.29 GiB
#   media-dump       23 repos      0.75 GiB
#   spam-batch      434 repos      0.05 GiB
#   stale             3 repos      0.03 GiB
# DRY-RUN: nothing changed. Re-run with --apply to execute.
```

Top to bottom: free disk and the pressure it produces, the thresholds **actually in effect at that pressure**, what was excluded, what each spam rule found, the size distribution rule B draws its percentile from, and what the run left alone. Then the plan, largest-first, with a total per reason.

`AGE(d)` is the age the matching rule measured: days since last activity for A, B and C, days since creation for D, E and F. Progress lines go to stderr, the plan to stdout, so `> plan.txt` keeps them apart.

`spam-batch` frees little disk and is still worth it: each of those repos is an entry the node announces, fetches and re-announces forever, and a row in every listing you read.

### Exit codes

| Code | Meaning                                                                                                                              |
| ---- | ------------------------------------------------------------------------------------------------------------------------------------ |
| `0`  | Success, including a dry run and an `--apply` you declined at the prompt                                                             |
| `1`  | Storage missing or unreadable, or an unexpected failure (the run prints the line and the command)                                    |
| `2`  | Bad argument                                                                                                                         |
| `3`  | The plan tripped a runaway cap. Read it, then re-run with `--force`                                                                  |
| `5`  | Refused to guess: node unreachable, NID unknown, routing table empty, exclusions unreadable, or too much of storage could not be read |

Exit 5 always means it could not see enough to be trusted, never that there was nothing to do. Nothing was touched.

## What gets pruned

A repo is pruned if it is **not excluded** and matches **at least one rule**.

### Exclusions (never touched)

| Exclusion       | Source                                                |
| --------------- | ----------------------------------------------------- |
| Pinned repos    | `config.web.pinned.repositories`                      |
| Private repos   | `rad ls --private`                                    |
| Your own repos  | `rad ls` (repos you initialized or forked / delegate) |
| Freshly written | storage dir modified within `FRESH_GUARD_DAYS`        |
| Unknown age     | no readable refs                                      |
| Unreadable      | hit an error when reading the repo                    |

### Rules

Every rule has the same shape: **something about the repo**, *and* it is old enough, *and* enough other nodes still hold it. All three, always. Defaults shown; each is an environment variable.

| Rule               | The repo looks like                                                                 | Minimum age               | Other seeds              |
| ------------------ | ----------------------------------------------------------------------------------- | ------------------------- | ------------------------ |
| **A, junk-name**   | a disposable *word* in the name (`test`, `tmp`, `old`, `demo`)                      | `JUNK_STALE_DAYS`, 30d    | ≥ `JUNK_MIN_SEEDS`, 1    |
| **A, junk-id**     | the name is *nothing but* a random hex id (`08a25d0f666d`)                          | `JUNK_STALE_DAYS`, 30d    | ≥ `JUNK_ID_MIN_SEEDS`, 0 |
| **B, size**        | a giant: over `ABS_SIZE_FLOOR_MB` (500M) *and* in the top `REL_PCTL`% by size (P95) | `OUTLIER_STALE_DAYS`, 90d | ≥ `MIN_OTHER_SEEDS`, 3   |
| **C, stale**       | nothing in particular; the catch-all for whatever the other rules missed                    | `STALE_YEARS_DAYS`, 730d  | ≥ `MIN_OTHER_SEEDS`, 3   |
| **D, spam-batch**  | one of a batch stamped out from one template ([more](#rule-d-spam-batches))         | `SPAM_STALE_DAYS`, 7d     | ≥ `SPAM_MIN_SEEDS`, 0    |
| **E, link-farm**   | published to carry links rather than code ([more](#rule-e-link-farms))              | `LINK_STALE_DAYS`, 7d     | ≥ `LINK_MIN_SEEDS`, 0    |
| **F, media-dump**  | video, images or audio with no project around them ([more](#rule-f-media-dumps))    | `MEDIA_STALE_DAYS`, 7d    | ≥ `MEDIA_MIN_SEEDS`, 1   |
| **F, media-batch** | the same media files, published across many repos ([more](#rule-f-media-dumps))     | `MEDIA_STALE_DAYS`, 7d    | ≥ `MEDIA_MIN_SEEDS`, 1   |

#### How age is measured

A, B and C measure **last activity**: they are about abandonment, and a repo somebody touched is not abandoned. Activity is any signed change, however small (a commit, an issue, a comment, a reaction, a label), since each is a git commit under some peer's `refs/cobs/*`. The tool takes the newest `creatordate` across every peer's refs, and reads when the change was *authored*, so a just-fetched old comment still counts as old.

D, E and F measure **creation** instead, because the spam wave this tool was written against appends a comment to its own repos every few days, which would reset a last-activity clock and make the whole wave permanently immune. Creation is the older of the repo's oldest ref date and the day this seed first saw it (`$RAD_HOME/prune-audit/first-seen.tsv`, appended on every run, dry or not). A pusher controls the first date and cannot reach the second.

#### Verdicts that may delete the last copy we know of

Only `junk-id`, `spam-batch` and `link-farm`, which default to a seed floor of `0`. "Other seeds" counts the nodes *our routing table* says announce a repo, which is not proof a copy exists elsewhere, so the floor drops only where the evidence is conclusive: for generated bulk and for a repo whose whole purpose is to advertise a link, "nobody else seeds it" measures worthlessness rather than rarity. A disposable *word* in a name is a guess (`my-old-thesis` is somebody's thesis), and a large or long-abandoned *unique* repo is the very thing a seed exists to preserve. `JUNK_ID_MIN_SEEDS=1 SPAM_MIN_SEEDS=1 LINK_MIN_SEEDS=1` restores never-take-the-last-copy everywhere.

#### Names that count as disposable

`test`, `tmp`, `temp`, `scratch`, `playground`, `sandbox`, `demo`, `dummy`, `wip`, `trash`, `junk`, `old`, `throwaway`, `helloworld`, as whole words delimited by `-`, `_`, `.` or the ends of the name. Plus `foo` / `bar` / `baz`, but only as an entire name, so `BAR_widget` is safe. A space is deliberately not a delimiter, because names with spaces read as prose where "old" and "demo" are ordinary English words: `test-old` matches, `The old man` does not. A name that is *nothing but* a random hex id of `JUNK_ID_MIN_LEN`+ characters counts too (`08a25d0f666d`), but not `12345678` and not `facade`, since both a letter and a digit are required.

### Disk pressure

The thresholds above are the **relaxed** values, used when there is plenty of free space. As free disk falls, the tool **self-tightens**: pressure `p` rises from `0` to `1` linearly between a relax watermark (`max(PRESSURE_RELAX_PCT%, PRESSURE_RELAX_GB)` free) and a critical one (`min(PRESSURE_CRIT_PCT%, PRESSURE_CRIT_GB)` free), and every knob is interpolated from its relaxed value toward an aggressive one:

| knob                 | relaxed (`p=0`) | aggressive (`p=1`) |
| -------------------- | --------------- | ------------------ |
| `STALE_YEARS_DAYS`   | 730             | 60                 |
| `OUTLIER_STALE_DAYS` | 90              | 14                 |
| `JUNK_STALE_DAYS`    | 30              | 7                  |
| `SPAM_STALE_DAYS`    | 7               | 1                  |
| `ABS_SIZE_FLOOR_MB`  | 500             | 50                 |
| `REL_PCTL`           | 95              | 50                 |
| `MIN_OTHER_SEEDS`    | 3               | 1                  |

The header prints the live pressure and the effective thresholds every run. On one node, pruning scaled from ~1.3k repos / 18 GiB at `p=0` to ~7.1k repos / 92 GiB at `p=1`.

**Hard floors never scale.** `MIN_OTHER_SEEDS` bottoms out at 1, so rules B and C never take the last copy we know of, and the pinned/private/own exclusions always hold. Rule E does not scale at all, because its evidence is not about time: a repo either links to spam domains or it does not, and a full disk does not change that. `DISK_AWARE=0` disables scaling entirely.

## Safety and recovery

- **Dry run by default.** Nothing is deleted without `--apply`.
- **Minimum seed counts** keep the last copy we know of, except for the three conclusive verdicts above.
- **Runaway caps** (`MAX_PRUNE_COUNT`, `MAX_PRUNE_GB`) abort an unexpectedly large plan unless `--force`. Confirming interactively bypasses them, since you have seen the numbers; cron and `--yes` still respect them.
- **Freshness guard** skips repos with an in-flight fetch.
- **Apply preflight** aborts if the node is down or exclusions cannot be read, so a transient failure never deletes your own or pinned repos.
- **Blind scans abort.** More than `MAX_SCAN_FAIL_PCT` of storage unreadable is exit 5, not a small plausible plan.
- **Audit log** records every deletion.

For each selected repo, in this exact order:

```sh
rad unseed <rid>        # drop whatever single seeding policy the repo has
rad block  <rid>        # set an explicit block, so default-allow won't re-fetch it
rm -rf  <storage>/<rid> # the only step that actually frees disk
```

`rad unseed` removes whichever policy row a repo has, so it must run **before** `rad block`, never after, or it would wipe the block just set and the repo would re-seed.

### Undoing a prune

**Deletion is local.** A pruned repo is re-fetchable from the network as long as other nodes still hold it, which is what the minimum seed counts are for. Undoing a prune is clearing the block and seeding again:

```sh
rad unseed rad:<rid> && rad seed rad:<rid>    # one repo

# ...or every repo a given run removed, from that run's audit log
awk -F'\t' '!/^#/ {print "rad:"$1}' ~/.radicle/prune-audit/prune-20260628T183150Z.log |
  while read -r rid; do rad unseed "$rid" && rad seed "$rid"; done
```

The node keeps running during a prune. After a large first run, one `sudo systemctl restart radicle-node` clears the stale "inventory announce limit" warning from the node log; `--restart-node` does it for you when run with sufficient rights. On some heartwood versions `rad node inventory` may still list the removed RIDs afterwards. That is cosmetic: the repos are gone from disk and blocked from re-seeding.

## Configuration

Every knob is an environment variable. Defaults shown.

**Where it runs**

| Variable     | Default                       | Meaning                                                                        |
| ------------ | ----------------------------- | ------------------------------------------------------------------------------ |
| `RAD`        | `rad`                         | The rad binary to call                                                         |
| `RAD_HOME`   | `rad path`, else `~/.radicle` | Radicle home to operate on; `STORAGE`, `CONFIG` and `AUDIT_DIR` derive from it |
| `SERVICE`    | `radicle-node`                | systemd unit used by `--restart-node`                                          |
| `JOBS`       | `cores-1`                     | Parallel workers for the scan                                                  |
| `AUDIT_DIR`  | `$RAD_HOME/prune-audit`       | Where the audit logs and the creation-date ledger are written                  |
| `FIRST_SEEN` | `$AUDIT_DIR/first-seen.tsv`   | The creation-date ledger itself                                                |

**What each rule needs to fire**

| Rule | Variable              | Default   | Meaning                                                                 |
| ---- | --------------------- | --------- | ----------------------------------------------------------------------- |
| A    | `JUNK_STALE_DAYS`     | `30`      | Staleness required                                                      |
| A    | `JUNK_MIN_SEEDS`      | `1`       | Other seeds for the *word* branch; keeps the last copy we know of       |
| A    | `JUNK_ID_MIN_SEEDS`   | `0`       | Other seeds for the *random-id* branch; `0` may take the last copy      |
| A    | `JUNK_ID_MIN_LEN`     | `8`       | Length at which an all-hex name counts as a random id (`0` disables it) |
| B    | `ABS_SIZE_FLOOR_MB`   | `500`     | Absolute size floor                                                     |
| B    | `REL_PCTL`            | `95`      | Size percentile, across all repos on the seed                           |
| B    | `OUTLIER_STALE_DAYS`  | `90`      | Staleness required                                                      |
| C    | `STALE_YEARS_DAYS`    | `730`     | Staleness required (~2 years)                                           |
| B, C | `MIN_OTHER_SEEDS`     | `3`       | Other seeds required, shared by both rules                              |
| D    | `SPAM_MIN_BATCH`     | `5`       | Repos sharing a name skeleton before it counts as a batch              |
| D    | `SPAM_DESC_AGREE_PCT` | `80`      | Share of that batch that must agree on one description skeleton        |
| D    | `SPAM_REQUIRE_ID`     | `1`       | Demand a random-id slot in the name skeleton (`0` is looser)            |
| D    | `SPAM_STALE_DAYS`     | `7`       | Age since creation, a grace period rather than evidence                 |
| D    | `SPAM_MIN_SEEDS`      | `0`       | Other seeds required; `0` may take the last copy we know of             |
| E    | `LINK_SCAN`           | `1`       | Read file content at all (`0` turns rule E off entirely)                |
| E    | `LINK_MIN_REPOS_PCT`  | `0.4`     | Share of storage that must link to a host before it can be a spam host  |
| E    | `LINK_MIN_REPOS`      | `8`       | Absolute floor under that share                                         |
| E    | `LINK_CODE_MAX_PCT`   | `10`      | Share of a host's linkers that may link from their own code             |
| E    | `LINK_REPO_BUDGET`    | `8000000` | Bytes read per repo, per pass                                          |
| E    | `LINK_MIN_SCORE`      | `5`       | Spam domains a repo must link to before it is flagged                   |
| E    | `LINK_DELEGATE_CHECK` | `1`       | Count only links from the repo's own delegates (`0` is faster, unsafe)  |
| E    | `LINK_STALE_DAYS`     | `7`       | Age since creation, a grace period rather than evidence                 |
| E    | `LINK_MIN_SEEDS`      | `0`       | Other seeds required; `0` may take the last copy we know of             |
| F    | `MEDIA_SCAN`          | `1`       | List repo trees at all (`0` turns rule F off entirely)                  |
| F    | `MEDIA_MIN_BYTES`     | `65536`   | Media bytes below which a repo is not worth judging                     |
| F    | `MEDIA_TEXT_MAX_BYTES`| `2048`    | Everything that is not media, added up, must stay under this            |
| F    | `MEDIA_STALE_DAYS`    | `7`       | Age since creation, a grace period rather than evidence                 |
| F    | `MEDIA_MIN_SEEDS`     | `1`       | Other seeds required; `1` keeps the last copy we know of                |
| F    | `MEDIA_MIN_BATCH`     | `5`       | Repos holding one media file, byte for byte, to call it a campaign      |
| F    | `MEDIA_TEXT_CEIL_BYTES`| `65536`  | The batch path's wider budget for everything that is not media          |
| F    | `MEDIA_MAX_REFS`      | `10000`   | Refs above which a repo is too costly to read, so it goes unjudged      |
| F    | `MEDIA_EXTS`          | see below | Extensions judged as media                                             |

Two more are for shaping rather than firing: `MEDIA_EXTS` is the list of extensions rule F judges as media, and `LINK_REPO_BUDGET` (8000000) caps how many bytes rule E reads per repo per pass. Everything else the two rules use to classify is a constant in the script, next to the comment saying why it has that value.

**Brakes**

| Variable            | Default | Meaning                                                    |
| ------------------- | ------- | ---------------------------------------------------------- |
| `FRESH_GUARD_DAYS`  | `2`     | Skip repos written this recently (an in-flight fetch)      |
| `MAX_PRUNE_COUNT`   | `1000`  | Runaway guard: abort over this many repos                  |
| `MAX_PRUNE_GB`      | `80`    | Runaway guard: abort over this much disk                   |
| `MAX_SCAN_FAIL_PCT` | `10`    | Abort if more than this share of storage could not be read |

**Disk pressure** ([what it does](#disk-pressure))

| Variable                                   | Default     | Meaning                                          |
| ------------------------------------------ | ----------- | ------------------------------------------------ |
| `DISK_AWARE`                               | `1`         | Scale thresholds with free disk (`0` to disable) |
| `PRESSURE_RELAX_PCT` / `PRESSURE_RELAX_GB` | `20` / `20` | Above this much free: no pressure                |
| `PRESSURE_CRIT_PCT` / `PRESSURE_CRIT_GB`   | `10` / `2`  | At/below `min()` of these: full pressure         |
| `*_AGG`, e.g. `STALE_YEARS_DAYS_AGG`       | see below   | Full-pressure endpoint for each knob that scales |

```sh
# example: only chase the giants, leave everything else
ABS_SIZE_FLOOR_MB=1000 STALE_YEARS_DAYS=99999 ./radicle-seed-prune
```

## Run it on a schedule

After a reviewed first run, a weekly cron keeps the seed trimmed. Deltas are small, so no restart is needed, and leaving out `--force` keeps the runaway cap active as a safety net.

Cron runs with a minimal environment, so `HOME` and `PATH` have to be spelled out. Substitute the user your node runs as:

```cron
# /etc/cron.d/radicle-seed-prune  Sundays 04:17
SHELL=/bin/sh
17 4 * * 0 radicle HOME=/home/radicle PATH=/usr/local/bin:/usr/bin:/bin /usr/local/bin/radicle-seed-prune --apply >> /home/radicle/.radicle/prune-audit/cron.log 2>&1
```

Point `RAD_HOME` at the node's home instead if it does not live at `$HOME/.radicle`.

## Audit trail

Every `--apply` run writes to `$RAD_HOME/prune-audit/` (default `~/.radicle/prune-audit/`):

- **`prune-<UTC-timestamp>.log`**: one file per run, every repo removed, tab-separated as rid, size, other-seed count, last activity, reason, name, and the date the matching rule measured. Self-describing header on top.
- **`history.log`**: append-only, one line per run: timestamp, repos deleted, GiB reclaimed, disk pressure.
- **`cron.log`**: with the cron above, the full console output of every run.
- **`first-seen.tsv`**: the creation-date ledger rules D, E and F read. Written on every run, dry or not.

```sh
tail ~/.radicle/prune-audit/history.log              # totals per run, newest last
cat  ~/.radicle/prune-audit/prune-2026*.log          # exact repos removed, with reasons
awk -F'\t' '/reclaimed/{n++; g+=$3} END{print n" runs, "g" GiB total"}' ~/.radicle/prune-audit/history.log
```

## Rule D: spam batches

A **spam batch** is a batch of repos one script stamped out from a single template: the same name shape with a slot filled in, the same description with a number swapped. They arrive by the hundred and cost the seed an inventory entry each.

One repo called `flatten-2-33ed7115` described as *"Flatten a nested array. Variant 2."* could be anybody's scratch work. A hundred of them is a generator. So rule D is decided by the corpus, never by a single repo.

Every name and description in storage is *skeletonised*: digit runs become `#`, random-id tokens (6+ hex characters carrying both a letter and a digit) become `%`. `flatten-2-33ed7115` becomes `flatten-#-%`. Repos are grouped by that skeleton with `#` and `%` collapsed into one wildcard, so `flatten-*-*`, and a group is a spam batch only when all of:

1. at least `SPAM_MIN_BATCH` repos share the skeleton;
2. at least one of them carries a **random-id** slot rather than a plain enumeration (`SPAM_REQUIRE_ID=0` drops this);
3. at least `SPAM_DESC_AGREE_PCT`% of them share **one** non-empty description skeleton.

Only the members carrying that agreed description are pruned, so a genuine repo that happens to share the name shape is left alone. Collapsing `#` and `%` for grouping matters because a random hex token comes out all-digits about 2% of the time (`chunk-1-96180521`), which would otherwise split a batch and strand those siblings.

**Two independent signals are required: the name shape and the description.** On a real 11,151-repo seed the rule flags 442 repos in 10 batches and nothing else. The description agreement does that work, not the batch size: on the same corpus, dropping `SPAM_MIN_BATCH` to 3 finds the same 10 batches and one repo more. What it leaves alone there:

- a 240-repo hardware-driver mirror import, one repo per board: one name skeleton, but every repo carries its own real description;
- a 427-repo set with one repo per standard code, likewise;
- 48 unrelated repos sharing one migration note as their description while their names have nothing in common.

The random-id requirement is the third guard. A version or enumeration slot (`mainline-6.1.y`, `release-202401`) means something to a human; an 8-hex-char token does not. Demanding both a letter and a digit in that token keeps a date or sequence suffix on the enumeration side of the line. Turning the requirement off is looser and can reach a version-mirror farm whose descriptions are also templated.

Noteworthy:

- **Timing is not a signal.** On a real seed the legitimate 240-repo mirror import spans `0.00` days of activity while the spam batch spans `14.8`. "Created in a burst" would flag the mirror and miss the spam.
- **Descriptions differing only by a number count as agreeing**, since *"Variant 2"* vs *"Variant 3"* is the signature being hunted. A set whose descriptions differ only by a version number therefore rests entirely on the random-id requirement.

Repos with no description at all are never flagged: one signal is not enough.

## Rule E: link farms

A **link farm** is a repo published to carry links rather than code. Whatever files it has are a wrapper around the address it wants traffic sent to, and somebody is paid per visitor who arrives there. The repo is the billboard, not the product.

A generator changes its naming scheme in one line, which is how a link farm escapes rule D. It cannot change the address and still get paid, which is what rule E matches on. That also reaches a spammer who clones real projects and injects links into the copies: real names, real files, real history, and the injected links still land on domains nobody's code uses.

Every hostname mentioned anywhere in every repo is collected, from committed files, issues, patches and comments alike, then folded to its **registrable domain**. A domain is a **spam domain** when both hold:

1. at least `LINK_MIN_REPOS_PCT`% of the repos on the seed link to it, and at least `LINK_MIN_REPOS` of them;
2. fewer than `LINK_CODE_MAX_PCT`% of those repos link to it *from their own code*, meaning from a file reachable from a branch or tag.

A repo is flagged when **its own delegates** link it to at least `LINK_MIN_SCORE` spam domains, it is older than `LINK_STALE_DAYS`, and it has at least `LINK_MIN_SEEDS` other seeds.

Both counts are recomputed from storage on every run, so **there is no blocklist to maintain**. A spammer who registers ten new domains gains nothing the moment enough of their repos link to them.

**Condition 2 is what keeps ordinary dependencies out.** On a real seed 197 repos link to `github.com`, clearing condition 1 easily, and 196 of them have it in a README or in source, so it fails condition 2. A site the spam exists to advertise has no such repos behind it: plenty of repos link to it, none of their code uses it.

**Why a percentage and not "no repo at all".** Publishing one repo whose README links to a domain is free, and under an all-or-nothing test that single repo would immunise it for the whole seed, permanently. The two populations sit nowhere near the threshold. Measured per hostname on a real seed: 68 spam hosts at 0%, every ordinary host above 98% (`github.com` 99.5%, `gnu.org` 100%, `w3.org` 98.6%). The one in between was `upload.wikimedia.org` at 1.6%, where 62 repos link to it, 61 spam hotlinking images and one a genuine project. It stays spam, and that project earns 1 point against a bar of `LINK_MIN_SCORE`.

**Why the code count ignores some repos.** A spammer with a hundred repos could commit their own link into ten of them and push the domain over `LINK_CODE_MAX_PCT` using repos they already have. So the count runs in two passes. Pass 1 marks a repo *suspect* if rule D already calls it generated, or if it reaches `LINK_MIN_SCORE` against the same domain test run at the looser `LINK_CODE_LOOSE_PCT` (50%). Pass 2 is the real test, and a code link from a suspect repo does not count. Condition 1 still counts every repo on purpose: those repos are exactly what makes a spam domain stand out.

**Why only the repo's own delegates count.** Any peer can push an issue or a comment to any public repo, and it lands in that repo's storage here. Counting a stranger's links as the repo's own would let anybody get somebody else's repo deleted by opening five spam issues on it. So every repo that scores is re-read across the refs its delegates control (the canonical branches, plus each delegate's namespace) and keeps its score only if it survives there. A repo whose delegates cannot be read leaves the plan. Conditions 1 and 2 still count every peer's content: a domain a stranger pastes into a thousand repos is a spam domain, whoever pasted it.

**Why registrable domains and not hostnames.** A wildcard DNS record and one subdomain per repo would otherwise hold every name under condition 1 for free. The cost is that a shared platform (a blog host, an image host) is judged as one domain, and condition 2 is what protects the ones real projects actually use.

**What it costs.** Rule E reads file content. On an 11,151-repo seed its harvest takes about 4 minutes of a 9-minute dry run with 5 workers, which is also about what rule F costs. `LINK_SCAN=0` turns it off. Reads are capped per blob (`LINK_BLOB_PREFIX`, 65536 bytes) and per repo (`LINK_REPO_BUDGET`, 8000000 bytes per pass), and the caps truncate rather than skip a blob, so a link near the start of a large file is still seen. Reaching a cap is normal on a large repo and does not exclude it.

**Known limit.** A spammer can still disqualify a domain, but only with repos neither pass marks suspect: individually named, individually described, each linking to that one domain and nothing else, and enough of them to reach `LINK_CODE_MAX_PCT` of its linkers. That is one such repo for every ten that link to the domain, paid again for every new domain, and they have to be hand-made rather than generated. Rule E does not stop that, it only makes it expensive.

Rule E leans on rule D for one thing: rule D's batch list is one of the two ways a repo gets marked suspect. Turning rule D off leaves rule E working with a weaker suspect list.

## Rule F: media dumps

A **media dump** is a repo whose files are video, images or audio with no project around them. Radicle storage exists for collaborating on code, and a repo holding one `.mp4` and nothing else is using the seed as free file hosting. The spam wave does exactly that, and the files are often ones you would not want your seed serving.

A repo is flagged when all of:

1. it carries at least `MEDIA_MIN_BYTES` (64 KiB) of media;
2. everything that is *not* media adds up to less than `MEDIA_TEXT_MAX_BYTES` (2048);
3. it is older than `MEDIA_STALE_DAYS` (7d, since creation, the same clock rules D and E use, and not backdatable);
4. it has at least `MEDIA_MIN_SEEDS` (1) other seeds.

**Condition 2 is what tells a dump from a real repo that holds media.** A game, a design system or a documented photo archive has a README, a licence, a manifest or a build file, and clears the text budget many times over. A repo carrying a video has nothing else at all. The budget is in bytes rather than files so that one 40-byte placeholder cannot buy an exemption.

**What a file is decides, not what it is called.** Extensions (`MEDIA_EXTS`, `MEDIA_TEXT_EXTS`, `MEDIA_TEXT_NAMES`) are only a fast path. A file on neither list is read, just its first 16 bytes, and matched against a table of media signatures, so renaming a video to `.dat` does not hide it. Archives (zip, gzip, rar, 7z) count as media too, because zipping a video is a one-command evasion; the cost is that a repo holding a release tarball and nothing else reads as a dump, which the seed floor bounds. A file matching no signature counts as text and spares the repo. A recognised *text* file over `MEDIA_SNIFF_TEXT_BYTES` (256 KiB) is read too, or a video called `README.md` would both hide itself and blow the budget that spares the repo. Reading is capped at `MEDIA_SNIFF_MAX_FILES` (200) per repo, and only happens while the repo could still be a dump. Files past that cap count as text, so a repo with more unrecognised files than the cap is spared rather than judged on a sample.

**Only the repo's own content counts.** That means the canonical branches and tags, plus the namespaces of the delegates named in `refs/rad/id`, a ref the local node writes only after verifying the identity document's signatures. The delegates' own issues and comments therefore count, because a dump hides as well in an attachment as in a commit, and a COB is read across its whole history: it gains one commit per op and each tree holds only that op's own files, so an attachment from an older comment is still on disk and still counts. Any blob a non-delegate's refs also hold is subtracted, since a peer's merged issue thread can carry the blobs of everyone who wrote in it. Without that subtraction, pushing a video onto a stranger's near-empty repo would put *their* repo in the plan. What sits on a **canonical branch or tag** is never subtracted, though, because only a delegate can move one: replicating a repo mirrors its branches into the replicating peer's own namespace, and subtracting on that would erase a real project's README and lockfile and leave whatever the peers had not fetched yet, which is a repo that looks exactly like a dump. A branch or tag is read at its tip, so media committed and then deleted in a later commit is missed: walking every branch's history would cost far more and would count against a repo that legitimately dropped a big asset years ago. The walk also stops the moment a repo's text passes the wider of the two budgets, since nothing still unread can change the answer: on a mirror of a real project that is the first few files out of a million. A repo whose listing dies part-way is left unjudged too, because the fragment reads as a repo holding less text, and less text is the direction that condemns. A repo with more than `MEDIA_MAX_REFS` (10000) refs is left unjudged on the same warning line: reading every peer's refs is what this rule costs, and one repo on an 11k-repo seed has 152k of them, minutes of walking to learn that a repo half the network replicates is not a dump.

**A token README defeats the budget**, and nothing measurable about *one* repo can tell it from a small real project's README: they are the same bytes. A ratio does not help, because a 40 MB dump and a 40 MB photo archive, each behind a 2 KB README, are both 99.99% media.

That is what the **batch path** is for. Publishing the same files across many repos is evidence no single repo can manufacture, so where it exists the text budget widens and the fig leaf stops working. A repo is flagged `media-batch` when it meets conditions 1, 3 and 4 above, *and*:

- at least `MEDIA_MIN_BYTES` of its media sits in files that `MEDIA_MIN_BATCH` (5) or more repos in storage also hold, byte for byte, and that this repo was not the first to hold. The first holder is left out of its own batch, or reposting somebody's photos into five repos of your own would put *their* repo in the plan. First is by the creation-date ledger, the one date a pusher cannot backdate, so on a seed whose ledger starts today the exemption falls to whichever repo sorts first until the ledger has some history;
- everything that is not media adds up to less than `MEDIA_TEXT_CEIL_BYTES` (64 KiB), the wider budget. A README big enough to clear *that* is a document rather than a fig leaf, and spares the repo either way.

**A dump no other node seeds is listed, not pruned.** Rule F's evidence is about one repo, weaker than a corpus of identical repos or a paid link, so unlike `spam-batch` and `link-farm` it keeps the last copy we know of. Those repos are printed under `# review:` rather than passed over, so the floor cannot quietly become a hiding place for anyone who makes sure nobody else seeds their dump. `MEDIA_MIN_SEEDS=0` drops the floor.

**What it costs.** Rule F lists every file of every repo, so it is one of the two slow phases. On an 11,151-repo seed it takes about 4 minutes of a 9-minute dry run with 5 workers, roughly what rule E costs. Most of that is the short circuit doing its job: without it one mirror of a large project took 26 minutes on its own, because the walk read half a million files to learn what its first source file had already settled. `MEDIA_SCAN=0` turns the rule off.

**Known limit.** A distinct, plausible README over distinct media, per repo, still evades rule F. At that point nothing separates the repo from a small real archive, and the tool spares it. Rule F prices the dump rather than stopping it, and an actor who pays that price across many repos becomes visible to rule D instead.

## Development

```sh
bash tests/run.sh
```

Needs only `bash`, `git` and coreutils. It builds a hermetic fixture (a throwaway Radicle home, a `rad` stub on `PATH`, real bare git repos with controlled dates and sizes) and runs the real script against it, so it never reads or writes the real node. See [`CHANGELOG.md`](./CHANGELOG.md) for release history.

## Support

If this saved you some disk space, some time, and a few bucks on your VPS bill, please support me:

- 💛 Chip in on [Liberapay](https://liberapay.com/maninak/donate) with a micro-donation, if you can comfortably spare it.
- 🌱 Seed this repo on [Radicle](https://app.radicle.at/nodes/seed.radicle.at/rad:zxvTkxzouwrYFwycnsctrMT3iM2E) and ⭐ star it on [GitHub](https://github.com/maninak/radicle-seed-prune).
- 🗣️ Tell a fellow seed operator, or open an issue with ideas and edge cases you hit.

[![Sponsor maninak on Liberapay](https://img.shields.io/badge/Liberapay-Donate-F6C915?logo=liberapay&logoColor=black)](https://liberapay.com/maninak/donate)

## Commercial use

The license is noncommercial, and the intent behind it is narrow: keep the script from being repackaged and sold. It is not meant to get in the way of anyone running a seed.

**Free, no need to ask:**

- Personal use, hobby projects, research, experiments, and testing.
- Charitable organizations, educational institutions, public research organizations, public safety or health organizations, environmental protection organizations, and government institutions, regardless of how they are funded.

So running a public seed as an individual, a collective, or a nonprofit is free, and always will be.

**Needs a separate license:**

- For-profit companies, including running it only on your own infrastructure to cut your own hosting bill. Nothing has to be sold for the use to count as commercial.

If that is you, or you are not sure which side of the line you land on, email [info@radicle.tools](mailto:info@radicle.tools). It is usually a short conversation, and I would much rather say yes than have you guess.

## License

[PolyForm Noncommercial License 1.0.0](./LICENSE). Free to use, modify, and share for any **noncommercial** purpose; you must preserve the copyright and required-notice lines (attribution). **Commercial use is not permitted** without a separate license. For commercial licensing, email [info@radicle.tools](mailto:info@radicle.tools).

Built by Kostis ([@maninak](https://github.com/maninak)).
