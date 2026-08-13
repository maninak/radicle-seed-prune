# radicle-seed-prune

[![Sponsor maninak on Liberapay](https://img.shields.io/badge/Liberapay-Donate-F6C915?logo=liberapay&logoColor=black)](https://liberapay.com/maninak/donate)

[![version](https://img.shields.io/github/v/release/maninak/radicle-seed-prune?sort=semver&label=version&color=44CC11)](https://github.com/maninak/radicle-seed-prune/releases/latest)
[![License: PolyForm Noncommercial 1.0.0](https://img.shields.io/badge/License-PolyForm%20Noncommercial%201.0.0-orange.svg)](./LICENSE)
[![Shell](https://img.shields.io/badge/shell-bash-121011.svg?logo=gnu-bash&logoColor=white)](./radicle-seed-prune)
[![rad: - zxvTkxzouwrYFwycnsctrMT3iM2E](https://img.shields.io/static/v1?label=rad%3A&message=zxvTkxzouwrYFwycnsctrMT3iM2E&color=6666FF&cacheSeconds=64800)](https://app.radicle.at/nodes/seed.radicle.at/rad:zxvTkxzouwrYFwycnsctrMT3iM2E)

**Automatically detect and prune lower-value repos, spam and abuse from a [Radicle](https://radicle.dev) node's storage.**

It does two jobs:

- **Reclaims disk**: prunes stale giants, long-abandoned repos and disposable ones.
- **Moderates content**: prunes mass-generated spam, link farms and media dumps, and names peers who push their own files into repos they do not own.

Tuned against and running in production for seed.radicle.at seeding the whole public Radicle network. Read the plan before you apply anything.

## Install

```sh
curl -O https://raw.githubusercontent.com/maninak/radicle-seed-prune/master/radicle-seed-prune
chmod +x radicle-seed-prune
```

Needs `bash`, `git`, `jq` and `rad` on `PATH`. Run it as the user that owns the Radicle home you want pruned, or set `RAD_HOME` to that home.

## Usage

```sh
./radicle-seed-prune                  # preview: print the plan, change nothing
./radicle-seed-prune --apply          # apply, asks [y/N] first when run in a terminal
./radicle-seed-prune --apply --yes    # answer the confirmation with y (scripts, cron)
./radicle-seed-prune --apply --force  # apply even if the plan trips a runaway cap or the ratchet
./radicle-seed-prune --apply --restart-node  # ...and restart the node afterwards
./radicle-seed-prune --block-peers    # block what rule G found, one [y/N] per peer; prunes nothing
./radicle-seed-prune quarantine ...   # list, restore, delete, purge quarantined repos
./radicle-seed-prune --version
```

There is no `--dry-run` flag: running with no flags is the dry run. `--apply` scans once, prints that same plan, asks `[y/N]` in a terminal, and just applies when there is nobody to ask (cron, a pipe). `--yes` answers every prompt a run asks, including the per-peer block prompt.

`--block-peers` is its own action and does not imply `--apply`; pass both flags if you mean both actions. It asks once per peer before blocking that peer. `--block-peers --yes` answers those prompts with y, which is the form a cron job wants; `--block-peers` alone with nobody to ask (cron, a pipe) blocks nobody and prints the `rad block` commands instead.

The plan is sorted largest repo first and totals the disk the run would free. `--help` lists the options and the quarantine verbs, and prints the paths this run resolved.

Every knob is an environment variable rather than a flag, so a run is configured the way `rad` itself is:

```sh
RAD_HOME=/var/lib/radicle ./radicle-seed-prune          # a seed home that isn't yours
RAD=/nix/store/.../bin/rad ./radicle-seed-prune         # a specific rad binary
```

### Example output

A dry run against a seed of 11,201 repos:

```
# radicle-seed-prune 0.4.0  2026-08-12T04:40:21Z   mode=DRY-RUN
# home=/var/lib/radicle
# disk: 126.7GB free (47.0%)  pressure=0% [relax>=54GB crit<=2GB]
# rules: A junk(>30d, seeds>=1; id-names seeds>=0)  B size(>500MB & >=P95, >90d, seeds>=3)  C stale(>730d, seeds>=3)  D spam(batch>=5 & desc>=80%, >7d, seeds>=0)
# rule E link-farm(>=5 spam domains, each linked from >=0.4% of repos and from the code of <10% of them, >7d, seeds>=0)
# rule F media-dump(>=64KB of media and <2048B of anything else, >7d, seeds>=1)  media-batch(that media held by >=5 repos, <65536B of anything else)
# rule G parasite-peer(one file of theirs in >=10 repos they do not own, >=1MB media, <16384B of anything else) [reports only; --block-peers asks per peer]
# excluded: 9 pinned, 6 private, 0 own, 0 kept
# spam batches: 10 template(s) matching 447 repos, before the age and seed checks:
#      54  template-a-*-*
#      51  template-b-*-*
#      51  template-c-*-*
#      46  template-d-*-*
#      45  template-e-*-*
#   ...and 5 more
# spam domains: 94 domain(s) linked from >=44 repos, <10% from code;
#   492 repo(s) link to >=5 of them, before the age and seed checks:
#     424 repos  spam-host-1.example
#     331 repos  spam-host-2.example
#     307 repos  spam-host-3.example
#     305 repos  spam-host-4.example
#     295 repos  spam-host-5.example
#   ...and 89 more
# rule E: 43 repo(s) spared, the spam links were pushed by peers that are not their delegates
# repos=11201  sizes P50=0M P90=10M P95=33M P99=197M rel-cut(P95)=33M  abs-cut=500M
# skipped: 0 unreadable, 148 written in the last 2d, 1 with no readable refs

RID                                     SIZE  SEEDS   AGE(d) REASON        NEAR        NAME
zEXAMPLEREPOaaaaaaaaaaaaaaa          330.8MB     13      190 media-dump    -           example-repo-1
zEXAMPLEREPObbbbbbbbbbbbbbb          192.7MB      8      190 media-dump    -           example-repo-2
zEXAMPLEREPOccccccccccccccc           50.5MB     14      186 media-dump    -           example-repo-3
zEXAMPLEREPOddddddddddddddd           44.5MB     15      190 media-dump    -           example-repo-4
zEXAMPLEREPOeeeeeeeeeeeeeee           42.1MB     18      242 media-dump    -           example-repo-5
zEXAMPLEREPOfffffffffffffff           30.8MB      5      190 media-dump    -           example-repo-6
zEXAMPLEREPOggggggggggggggg           28.6MB      3      733 stale         seeds       example-repo-7
zEXAMPLEREPOhhhhhhhhhhhhhhh           21.8MB      7      539 media-dump    -           example-repo-8
zEXAMPLEREPOiiiiiiiiiiiiiii           12.3MB      9      183 media-dump    media       example-repo-9
[... 18 more single-repo rows ...]
zEXAMPLEREPOjjjjjjjjjjjjjjj           74.0KB      7       30 junk-name     age         example-demo-repo
zEXAMPLEREPOkkkkkkkkkkkkkkk           73.9KB     12       30 junk-name     age         example-test
(436 repos)                           49.8MB                 spam-batch    12 near     same pattern across many repos; PLAN_FULL=1 lists them
(35 repos)                           413.7MB                 link-farm     2 near      same pattern across many repos; PLAN_FULL=1 lists them
(23 repos)                             1.3GB                 media-batch   0 near      same pattern across many repos; PLAN_FULL=1 lists them

# PLAN: prune 523 repos, 2.52 GiB out of storage but still on disk for 7d, until a later run deletes them
#   junk-name         3 repos      0.00 GiB
#   link-farm        35 repos      0.40 GiB
#   media-batch      23 repos      1.29 GiB
#   media-dump       23 repos      0.75 GiB
#   spam-batch      436 repos      0.05 GiB
#   stale             3 repos      0.03 GiB
#   19 of them cleared a threshold by under 20%: see the NEAR column, which names the threshold that was close. Read those rows first.
# DRY-RUN: nothing changed. Re-run with --apply to execute.
```

Corpus verdicts (`spam-batch`, `link-farm`, `media-batch`) fold to one summary line per group at `PLAN_COLLAPSE_ROWS` (20) rows; single-repo verdicts are always listed in full, and `PLAN_FULL=1` lists everything. The evidence tables above the plan (spam templates, spam domains, scan errors, kept media dumps) show their top few entries and say how many they left out; `PLAN_FULL=1` prints those whole too.

`AGE(d)` is the age the matching rule measured: days since last activity for A, B and C, days since creation for D, E and F.

`NEAR` names any threshold the row cleared by less than `NEAR_PCT` (20%), and is `-` when the row cleared every one of them comfortably. It reports the numbers the matching rule actually tested: `age` for every rule, `seeds` where the rule has a seed floor above zero, plus `size` for rule B, `media` for rule F and `score` for rule E. Those are the rows to read first, and the summary under the plan counts them. `NEAR_PCT=0` marks nothing.

Progress lines go to stderr, the plan to stdout, so `> plan.txt` keeps them apart.

### Exit codes

| Code | Meaning                                                                                                                              |
| ---- | ------------------------------------------------------------------------------------------------------------------------------------ |
| `0`  | Success, including a dry run and an `--apply` you declined at the prompt                                                             |
| `1`  | Storage missing or unreadable, or an unexpected failure (the run prints the line and the command)                                    |
| `2`  | Bad argument                                                                                                                         |
| `3`  | The plan tripped a runaway cap or the history ratchet. Read it, then re-run with `--force`                                           |
| `5`  | Refused to guess: node unreachable, NID unknown, routing table empty, exclusions unreadable, or too much of storage could not be read |

Exit 5 means the tool could not see enough to be trusted; nothing was touched.

## What gets pruned

A repo is pruned if it is **not excluded** and matches **at least one rule**. `RULES` (default `ABCDEFG`) selects which rules run: a letter absent from it means that rule neither scans nor puts anything in the plan, and a repo a disabled rule would have claimed falls through to the next rule.

### Exclusions (never touched)

| Exclusion       | Source                                                |
| --------------- | ----------------------------------------------------- |
| Pinned repos    | `config.web.pinned.repositories`                      |
| Private repos   | `rad ls --private`                                    |
| Your own repos  | `rad ls` (repos you initialized or forked / delegate) |
| Kept repos      | `$AUDIT_DIR/keep.txt`, one repo id per line ([more](#quarantine)) |
| Freshly written | storage dir modified within `FRESH_GUARD_DAYS`        |
| Unknown age     | no readable refs                                      |
| Unreadable      | hit an error when reading the repo                    |

### Rules

Every rule has the same shape: **something about the repo**, *and* it is old enough, *and* enough other nodes still hold it. Defaults shown; each is an environment variable.

| Rule               | The repo looks like                                                                 | Minimum age               | Other seeds              |
| ------------------ | ----------------------------------------------------------------------------------- | ------------------------- | ------------------------ |
| **A, junk-name**   | a disposable *word* in the name (`test`, `tmp`, `old`, `demo`)                      | `JUNK_STALE_DAYS`, 30d    | ≥ `JUNK_MIN_SEEDS`, 1    |
| **A, junk-id**     | the name is *nothing but* a random hex id (`0a1b2c3d4e5f`)                          | `JUNK_STALE_DAYS`, 30d    | ≥ `JUNK_ID_MIN_SEEDS`, 0 |
| **B, size**        | a giant: over `ABS_SIZE_FLOOR_MB` (500M) *and* in the top `REL_PCTL`% by size (P95) | `OUTLIER_STALE_DAYS`, 90d | ≥ `MIN_OTHER_SEEDS`, 3   |
| **C, stale**       | nothing in particular; the catch-all for whatever the other rules missed            | `STALE_YEARS_DAYS`, 730d  | ≥ `MIN_OTHER_SEEDS`, 3   |
| **D, spam-batch**  | one of a batch stamped out from one template ([more](#rule-d-spam-batches))         | `SPAM_STALE_DAYS`, 7d     | ≥ `SPAM_MIN_SEEDS`, 0    |
| **E, link-farm**   | published to carry links rather than code ([more](#rule-e-link-farms))              | `LINK_STALE_DAYS`, 7d     | ≥ `LINK_MIN_SEEDS`, 0    |
| **F, media-dump**  | video, images or audio with no project around them ([more](#rule-f-media-dumps))    | `MEDIA_STALE_DAYS`, 7d    | ≥ `MEDIA_MIN_SEEDS`, 1   |
| **F, media-batch** | the same media files, published across many repos ([more](#rule-f-media-dumps))     | `MEDIA_STALE_DAYS`, 7d    | ≥ `MEDIA_MIN_SEEDS`, 1   |

Rule G is missing from the table because it judges a **peer**, not a repo, and prunes nothing: it names peers who use repos they do not own as file hosting of their own, and prints the `rad block` line for each such peer ([more](#rule-g-parasite-peers)).

#### How age is measured

A, B and C measure **last activity**. Activity is any signed change, however small: a commit, an issue, a comment, a reaction, a label. The tool takes the newest `creatordate` across every peer's refs.

D, E and F measure **creation** instead, because spam that comments on its own repos would reset a last-activity clock. Creation is the older of the repo's oldest ref date and the day this seed first saw it (`$RAD_HOME/prune-audit/first-seen.tsv`, appended on every run, dry or not). A pusher controls the first date and cannot reach the second.

#### Verdicts that may delete the last copy we know of

Only `junk-id`, `spam-batch` and `link-farm`, which default to a seed floor of `0`. "Other seeds" counts the nodes our routing table says announce a repo, not proof a copy exists elsewhere; these three verdicts are why pruning [quarantines instead of deleting](#quarantine). `JUNK_ID_MIN_SEEDS=1 SPAM_MIN_SEEDS=1 LINK_MIN_SEEDS=1` restores a floor of 1 everywhere.

#### Names that count as disposable

`test`, `tmp`, `temp`, `scratch`, `playground`, `sandbox`, `demo`, `dummy`, `wip`, `trash`, `junk`, `old`, `throwaway`, `helloworld`, as whole words delimited by `-`, `_`, `.` or the ends of the name; plus `foo` / `bar` / `baz`, but only as an entire name. A space is not a delimiter: `test-old` matches, `The old man` does not. A name that is *nothing but* a random hex id of `JUNK_ID_MIN_LEN`+ characters counts too (`0a1b2c3d4e5f`); both a letter and a digit are required, so `12345678` and `facade` do not.

### Disk pressure

The thresholds above are the **relaxed** values. As free disk falls, pressure `p` rises from `0` to `1` linearly between a relax watermark (`max(PRESSURE_RELAX_PCT%, PRESSURE_RELAX_GB)` free) and a critical one (`min(PRESSURE_CRIT_PCT%, PRESSURE_CRIT_GB)` free), and every knob is interpolated from its relaxed value toward an aggressive one:

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

**Hard floors never scale.** `MIN_OTHER_SEEDS` bottoms out at 1, every exclusion holds at any pressure, and none of rule E's thresholds move with pressure at all. `DISK_AWARE=0` turns the scaling off entirely, so every knob keeps its relaxed value.

## Safety and recovery

- **Dry run by default.** Nothing is pruned without `--apply`, and no peer is blocked without `--block-peers`.
- **Quarantine instead of deletion.** A pruned repo stays on disk for `QUARANTINE_DAYS` (7) and is restorable with one command ([details](#quarantine)).
- **Minimum seed counts** keep the last copy we know of, except under `junk-id`, `spam-batch` and `link-farm` ([why](#verdicts-that-may-delete-the-last-copy-we-know-of)).
- **Runaway caps** (`MAX_PRUNE_COUNT`, `MAX_PRUNE_GB`) abort a plan bigger than either cap. Two things get past them: `--force`, or a person answering `y` at the prompt, which is a human signing off on the numbers just printed. `--yes` is not one of them, so an unattended run still stops.
- **History ratchet.** An unattended run aborts when the plan is more than `RATCHET_FACTOR` (3) times the median of the last `RATCHET_RUNS` (8) applied runs; `--force` or an interactive confirmation gets past it.
- **Freshness guard** skips any repo whose storage directory was written within `FRESH_GUARD_DAYS` (2), which is what a fetch still arriving looks like.
- **Apply preflight** aborts if the node is down or exclusions cannot be read.
- **Blind scans abort.** More than `MAX_SCAN_FAIL_PCT` of the repos in storage unreadable is exit 5, not a small plausible plan.
- **Blocking a peer takes two opt-ins:** `--block-peers`, and then a `y` to the prompt it raises for that peer. Without `--block-peers` the run only prints the `rad block` line for each peer rule G named. An unattended run has nobody to give the second opt-in, so it blocks nobody unless `--yes` gives it ([more](#rule-g-parasite-peers)).
- **Audit log** records every prune and every block, with the evidence behind it.

For each selected repo, in this order:

```sh
rad unseed <rid>                              # drop whatever single seeding policy the repo has
rad block  <rid>                              # set an explicit block, so default-allow won't re-fetch it
mv <storage>/<rid> <audit>/quarantine/<rid>   # out of storage, still on disk
```

`rad unseed` must run **before** `rad block`, because unseeding clears whatever policy row the repo has, block included, and a repo with no policy row re-seeds under the default-allow scope.

### Quarantine

A pruned repo moves to `$AUDIT_DIR/quarantine/<rid>` rather than being deleted. It is deleted for real `QUARANTINE_DAYS` (7) days after it arrived there, by whichever `--apply` run comes next, including a run whose own plan is empty. At the critical disk watermark an `--apply` run empties the whole quarantine whether or not each entry has served its window, and it does that only after you have confirmed the prune, so answering `n` at the prompt leaves the quarantine standing. `QUARANTINE=0` deletes outright and keeps nothing.

Every repo was unseeded and blocked before it was moved there, so nothing on the node points at the quarantine: deleting the directory by hand (`rm -rf`) is safe at any time and only costs the ability to restore.

```sh
radicle-seed-prune quarantine list             # what is held, and for how long
radicle-seed-prune quarantine restore <rid>    # put it back in storage and re-seed it
radicle-seed-prune quarantine delete <rid>     # or --all: delete now, for good
radicle-seed-prune quarantine purge            # delete whatever is past its window
```

`restore` moves the repo back into storage, clears the block, re-seeds it, and adds it to the keep list, `$AUDIT_DIR/keep.txt`, so the next run leaves it alone. The keep list is one repo id per line, editable by hand; repos listed there are excluded from every rule.

### Undoing a prune

Within the quarantine window:

```sh
radicle-seed-prune quarantine restore <rid>
```

After the window the local copy is gone; the repo is re-fetchable from the network as long as other nodes still hold it (what the minimum seed counts are for). Two commands, in this order:

```sh
rad unseed rad:<rid>
rad seed  rad:<rid>
```

`rad seed` on its own is not enough: it only rewrites an existing policy row's scope, so a blocked repo stays blocked and the fetch is refused, even though the CLI prints a success line. `rad unseed` deletes that row whatever policy it holds, which is what drops the block. Newer heartwood also has `rad unblock`; `rad unseed` is used here because it works on every version and the `rad seed` that follows puts the seeding row back either way.

```sh
# every repo a given run removed, from that run's audit log
awk -F'\t' '!/^#/ && $1 != "blocked-peer" {print "rad:"$1}' \
  ~/.radicle/prune-audit/prune-20260628T183150Z.log |
  while read -r rid; do rad unseed "$rid" && rad seed "$rid"; done
```

The node keeps running during a prune. After a large first run, `sudo systemctl restart radicle-node` clears the stale "inventory announce limit" warning; `--restart-node` runs that restart for you, if the run has the rights to restart the service. On some heartwood versions `rad node inventory` still lists removed RIDs afterwards; that listing is cosmetic and the repos are gone.

## Speed

Rules E, F and G read the contents of every repo, which is most of a run. Almost nothing changes from one weekly run to the next, so what those three rules read is kept in `$AUDIT_DIR/cache`. A repo is reused from the cache when both its refs and its size on disk are identical to what the run that wrote that entry saw; if either has moved, the repo is read again.

On a seed of 11,221 repos and 270 GB on six cores, a first run takes about 10 minutes and the next one about 3, reusing 11,218 repos and producing the same plan.

The whole cache is dropped whenever the script file changes, or any of the settings below changes value, so a threshold you have just tuned never leaves last week's verdicts standing. `CACHE=0` reads every repo on every run; deleting the cache directory forces one full re-read, after which caching resumes.

## Configuration

Every knob is an environment variable. Defaults shown.

**Which rules run**

| Variable | Default   | Meaning                                                                                       |
| -------- | --------- | --------------------------------------------------------------------------------------------- |
| `RULES`  | `ABCDEFG` | The rules that run; a letter absent from it means that rule neither scans nor plans anything |

`RULES=`, set but empty, means no rules at all, not the default set.

**Where it runs**

| Variable     | Default                       | Meaning                                                                        |
| ------------ | ----------------------------- | ------------------------------------------------------------------------------ |
| `RAD`        | `rad`                         | The rad binary to call                                                         |
| `RAD_HOME`   | `rad path`, else `~/.radicle` | Radicle home to operate on; `STORAGE`, `CONFIG` and `AUDIT_DIR` derive from it |
| `SERVICE`    | `radicle-node`                | systemd unit used by `--restart-node`                                          |
| `JOBS`       | `cores-1`                     | Parallel workers for the scan                                                  |
| `AUDIT_DIR`  | `$RAD_HOME/prune-audit`       | Where the audit logs, the creation-date ledger and the quarantine are written  |
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
| D    | `SPAM_STALE_DAYS`     | `7`       | Age since creation                                                      |
| D    | `SPAM_MIN_SEEDS`      | `0`       | Other seeds required; `0` may take the last copy we know of             |
| E    | `LINK_MIN_REPOS_PCT`  | `0.4`     | Share of storage that must link to a host before it can be a spam host  |
| E    | `LINK_MIN_REPOS`      | `8`       | Absolute floor under that share                                         |
| E    | `LINK_CODE_MAX_PCT`   | `10`      | Share of a host's linkers that may link from their own code             |
| E    | `LINK_REPO_BUDGET`    | `8000000` | Bytes read per repo, per pass                                          |
| E    | `LINK_MIN_SCORE`      | `5`       | Spam domains a repo must link to before it is flagged                   |
| E    | `LINK_DELEGATE_CHECK` | `1`       | Count only links from the repo's own delegates (`0` is faster, unsafe)  |
| E    | `LINK_STALE_DAYS`     | `7`       | Age since creation                                                      |
| E    | `LINK_MIN_SEEDS`      | `0`       | Other seeds required; `0` may take the last copy we know of             |
| F    | `MEDIA_MIN_BYTES`     | `65536`   | Media bytes below which a repo is not worth judging                     |
| F    | `MEDIA_TEXT_MAX_BYTES`| `2048`    | Everything that is not media, added up, must stay under this            |
| F    | `MEDIA_STALE_DAYS`    | `7`       | Age since creation                                                      |
| F    | `MEDIA_MIN_SEEDS`     | `1`       | Other seeds required; `1` keeps the last copy we know of                |
| F    | `MEDIA_MIN_BATCH`     | `5`       | Repos holding one media file, byte for byte, to call it a campaign      |
| F    | `MEDIA_TEXT_CEIL_BYTES`| `65536`  | The batch path's wider budget for everything that is not media          |
| F    | `MEDIA_MAX_REFS`      | `10000`   | Refs above which a repo is too costly to read, so it goes unjudged      |
| F    | `MEDIA_EXTS`          | images, video, audio, archives | `\|`-separated extensions judged as media       |
| G    | `PARASITE_MIN_REPOS`  | `10`      | Non-delegated repos one file of a peer's must reach, byte for byte      |
| G    | `PARASITE_MIN_BYTES`  | `1048576` | Media bytes required across those repos (1 MiB)                         |
| G    | `PARASITE_TEXT_MAX_BYTES` | `16384` | Text budget anywhere in storage; a peer who writes is a contributor   |

`MEDIA_EXTS` and `LINK_REPO_BUDGET` shape rather than fire. Everything else the content rules use to classify is a constant in the script, next to the comment saying why it has that value.

**Brakes**

| Variable            | Default | Meaning                                                             |
| ------------------- | ------- | ------------------------------------------------------------------- |
| `FRESH_GUARD_DAYS`  | `2`     | Skip repos written this recently (an in-flight fetch)               |
| `MAX_PRUNE_COUNT`   | `1000`  | Runaway guard: abort over this many repos                           |
| `MAX_PRUNE_GB`      | `80`    | Runaway guard: abort over this much disk                            |
| `RATCHET_FACTOR`    | `3`     | Abort an unattended plan over this multiple of the recent median    |
| `RATCHET_RUNS`      | `8`     | Applied runs the median is taken over; fewer than 3 is no baseline  |
| `MAX_SCAN_FAIL_PCT` | `10`    | Abort if more than this share of storage could not be read          |

**Quarantine and plan output**

| Variable             | Default | Meaning                                                                    |
| -------------------- | ------- | -------------------------------------------------------------------------- |
| `QUARANTINE`         | `1`     | Quarantine pruned repos instead of deleting (`0` deletes, with no way back) |
| `QUARANTINE_DAYS`    | `7`     | Days a quarantined repo stays recoverable before a later run purges it     |
| `KEEP_FILE`          | `$AUDIT_DIR/keep.txt` | Repos excluded from every rule, one id per line; `quarantine restore` appends to it |
| `CACHE`              | `1`     | Reuse what rules E, F and G read out of repos that have not changed (`0` reads everything, every run) |
| `CACHE_DIR`          | `$AUDIT_DIR/cache` | Where that reading is kept                                      |
| `PLAN_COLLAPSE_ROWS` | `20`    | Group size at which a corpus verdict folds to one summary line             |
| `PLAN_FULL`          | `0`     | `1` lists every plan row and every evidence table entry, untruncated       |
| `NEAR_PCT`           | `20`    | A row's `NEAR` column names any threshold it cleared by less than this share of the threshold; `0` marks nothing |

**Disk pressure** ([what it does](#disk-pressure))

| Variable                                   | Default     | Meaning                                          |
| ------------------------------------------ | ----------- | ------------------------------------------------ |
| `DISK_AWARE`                               | `1`         | Scale thresholds with free disk (`0` to disable) |
| `PRESSURE_RELAX_PCT` / `PRESSURE_RELAX_GB` | `20` / `20` | Above this much free: no pressure                |
| `PRESSURE_CRIT_PCT` / `PRESSURE_CRIT_GB`   | `10` / `2`  | At/below `min()` of these: full pressure         |
| `*_AGG`, e.g. `STALE_YEARS_DAYS_AGG`       | per knob    | Full-pressure endpoint for each knob that scales (defaults in the script, next to the knob) |

```sh
# example: only chase the giants, leave everything else
ABS_SIZE_FLOOR_MB=1000 STALE_YEARS_DAYS=99999 ./radicle-seed-prune
```

## Run it on a schedule

After a reviewed first run, a weekly cron keeps the seed trimmed; leaving out `--force` keeps the runaway caps and the ratchet active.

Cron runs with a minimal environment, so `HOME` and `PATH` have to be spelled out. Substitute the user your node runs as:

```cron
# /etc/cron.d/radicle-seed-prune  Sundays 04:17
SHELL=/bin/sh
17 4 * * 0 radicle HOME=/home/radicle PATH=/usr/local/bin:/usr/bin:/bin /usr/local/bin/radicle-seed-prune --apply >> /home/radicle/.radicle/prune-audit/cron.log 2>&1
```

Point `RAD_HOME` at the node's home instead if it does not live at `$HOME/.radicle`.

To have the same job act on rule G as well, add `--block-peers --yes`. That blocks every peer the rule names, with nobody reviewing it, so only do it once you have watched a few runs name nobody.

## Audit trail

Anything this tool does is written to `$RAD_HOME/prune-audit/` (default `~/.radicle/prune-audit/`). A dry run writes only the creation-date ledger and the scan cache:

- **`prune-<UTC-timestamp>.log`**: one file per acting run: every repo removed, tab-separated (rid, size, other-seed count, last activity, reason, name, the date the matching rule measured, any threshold that repo only just cleared), plus peer blocks made under `--block-peers` with the evidence behind each.
- **`quarantine/<rid>`**: every pruned repo, held for `QUARANTINE_DAYS` ([more](#quarantine)).
- **`keep.txt`**: repos excluded from every rule, one id per line, editable by hand; `quarantine restore` appends to it.
- **`cache/`**: what rules E, F and G last read out of each repo. Safe to delete at any time; the next run reads everything again.
- **`history.log`**: append-only, one line per applied run: timestamp, repos pruned, GiB moved out of storage, whether the quarantine was on, disk pressure. The history ratchet reads this file.
- **`cron.log`**: with the cron recipe above, the full console output of every run.
- **`first-seen.tsv`**: the creation-date ledger rules D, E and F read. Written on every run, dry or not.

```sh
tail ~/.radicle/prune-audit/history.log              # totals per run, newest last
cat  ~/.radicle/prune-audit/prune-2026*.log          # exact repos removed, with reasons
```

## Rule D: spam batches

A **spam batch** is a batch of repos one script stamped out from a single template: the same name shape with a slot filled in, the same description with a number swapped. Rule D is decided by the corpus, never by a single repo.

Every name and description in storage is *skeletonised*: digit runs become `#`, random-id tokens (6+ hex characters carrying both a letter and a digit) become `%`, so `example-2-3a9f81c2` becomes `example-#-%`. Repos are grouped by that skeleton with `#` and `%` collapsed into one wildcard (`example-*-*`), and a group is a spam batch only when all of:

1. the skeleton has at least one wildcard in it, so repos that simply share a fixed name are not a template;
2. at least `SPAM_MIN_BATCH` repos share the skeleton;
3. at least one of them carries a **random-id** slot rather than a plain enumeration (`SPAM_REQUIRE_ID=0` drops this);
4. at least `SPAM_DESC_AGREE_PCT`% of them share **one** non-empty description skeleton.

Only the members carrying the agreed description are pruned; repos with no description at all are never flagged. Descriptions differing only by a number count as agreeing.

On a real seed mirroring the whole public network the rule flags 442 repos in 10 batches and nothing else, leaving large mirror imports alone.

## Rule E: link farms

A **link farm** is a repo published to carry links rather than code. Rule E matches on the addresses a repo points its readers at, so it also reaches a spammer who injects links into a clone of a real project.

Every hostname mentioned anywhere in every repo (committed files, issues, patches, comments) is folded to its **registrable domain**. A domain is a **spam domain** when both hold:

1. at least `LINK_MIN_REPOS_PCT`% of the repos on the seed link to it, and at least `LINK_MIN_REPOS` of them;
2. fewer than `LINK_CODE_MAX_PCT`% of those repos link to it *from their own code*, meaning from a file reachable from a branch or tag.

A repo is flagged when **its own delegates** link it to at least `LINK_MIN_SCORE` spam domains, the repo is older than `LINK_STALE_DAYS`, and at least `LINK_MIN_SEEDS` other seeds hold it. Only links pushed by the repo's delegates count, so a stranger opening spam issues on somebody's repo cannot get that repo deleted, and a repo whose delegate list cannot be read is dropped from the plan rather than judged.

Both counts are recomputed from storage on every run, so there is no blocklist to maintain.

A code link is ignored in condition 2 when the repo it comes from is itself suspect, so that a farm cannot vouch for the domain it sells. A repo counts as suspect when rule D calls it generated, or when it would already qualify as a link farm under a looser version of condition 2 (`LINK_CODE_LOOSE_PCT`, 50%, in place of `LINK_CODE_MAX_PCT`). Turning rule D off leaves rule E with a shorter suspect list.

Rule E reads file content, capped per blob (`LINK_BLOB_PREFIX`, 65536 bytes) and per repo (`LINK_REPO_BUDGET`); a blob past the cap is read up to the cap rather than skipped. On the seed above it takes about 4 minutes of a 9-minute uncached dry run with 5 workers.

## Rule F: media dumps

A **media dump** is a repo whose files are video, images or audio with no project around them, using the seed as free file hosting.

A repo is flagged when all of:

1. it carries at least `MEDIA_MIN_BYTES` (64 KiB) of media;
2. everything that is *not* media adds up to less than `MEDIA_TEXT_MAX_BYTES` (2048);
3. it is older than `MEDIA_STALE_DAYS` (7d, since creation);
4. it has at least `MEDIA_MIN_SEEDS` (1) other seeds.

What a file *is* decides, not what it is called. Extensions (`MEDIA_EXTS`, `MEDIA_TEXT_EXTS`, `MEDIA_TEXT_NAMES`) are only a fast path: an unrecognised file has its first 16 bytes matched against media signatures, so renaming a video to `.dat` does not hide it. Archives (zip, gzip, rar, 7z) count as media; a file matching no signature counts as text and spares the repo. Reading is capped at `MEDIA_SNIFF_MAX_FILES` (200) per repo, and files past the cap count as text.

Only the repo's own content counts: the canonical branches and tags, plus the namespaces of the delegates named in `refs/rad/id`, including the delegates' issues and comments across a COB's whole history. Every other peer's namespace is ignored, so a stranger pushing a video onto somebody's repo cannot put that repo in the plan.

A branch or tag is read at its tip, so media committed and then deleted in a later commit is missed. A repo whose listing dies part-way, or with more than `MEDIA_MAX_REFS` (10000) refs, is left unjudged.

A token README is enough to put a repo over the text budget above. The **batch path** reaches such a repo anyway: it is flagged `media-batch` when it meets conditions 1, 3 and 4 above, *and*:

- at least `MEDIA_MIN_BYTES` of its media sits in files that `MEDIA_MIN_BATCH` (5) or more repos in storage also hold, byte for byte, and that this repo was not the first to hold (first by the creation-date ledger);
- everything that is not media adds up to less than `MEDIA_TEXT_CEIL_BYTES` (64 KiB), the wider budget.

A dump that no other node announces is listed under `# review:` for a human to look at, rather than pruned. `MEDIA_MIN_SEEDS=0` sets that floor to zero, which lets rule F take the last copy this seed knows of.

Rule F lists every file of every repo, which is another 4 minutes of that same 9-minute uncached dry run.

## Rule G: parasite peers

A **parasite peer** uses other people's repos as its file hosting: its files sit in the storage of repos it does not own, where no repo rule can reach them. Rule G judges the **peer**, and prunes nothing.

A peer is named when all of:

1. one single file of the peer's own, matched byte for byte, sits in at least `PARASITE_MIN_REPOS` (10) repos that the peer does not delegate and whose own refs do not hold that file;
2. the peer's media across those repos adds up to at least `PARASITE_MIN_BYTES` (1 MiB);
3. everything the peer has pushed anywhere in storage that is *not* media adds up to less than `PARASITE_TEXT_MAX_BYTES` (16 KiB), because a peer who writes anything is a contributor.

A delegate of any repo in storage is never accused, and neither is this node itself.

Blocking is never a side effect of a prune: the plan prints the exact `rad block <nid>` line for each peer rule G names, `--block-peers` raises a prompt per peer, and `--block-peers --yes` answers those prompts in an unattended run ([usage](#usage)). Each block is written to the audit log with the evidence behind it. Dropping a blocked peer's refs frees no disk until `git gc` runs, and this tool never runs `git gc`, so the run counts none of those bytes as reclaimed.

On the seed the defaults were tuned against, the rule names nobody in the whole public network.

A `RULES` without `G` turns it off.

## Development

```sh
bash tests/run.sh
```

Needs only `bash`, `git` and coreutils. It builds a hermetic fixture and runs the real script against it, so it never reads or writes the real node. See [`CHANGELOG.md`](./CHANGELOG.md) for release history.

## Support

If this kept your seed clean and saved you a few bucks on your VPS bill:

- 💛 Chip in on [Liberapay](https://liberapay.com/maninak/donate) with a micro-donation, if you can comfortably spare it.
- 🌱 Seed this repo on [Radicle](https://app.radicle.at/nodes/seed.radicle.at/rad:zxvTkxzouwrYFwycnsctrMT3iM2E) and ⭐ star it on [GitHub](https://github.com/maninak/radicle-seed-prune).
- 🗣️ Tell a fellow seed operator, or open an issue with ideas and edge cases you hit.

## License

[PolyForm Noncommercial License 1.0.0](./LICENSE). Free to use, modify, and share for any **noncommercial** purpose; you must preserve the copyright and required-notice lines (attribution). **Commercial use needs a separate license.** The intent is to keep the script from being repackaged and sold, not to get in the way of anyone running a seed.

**Free, no need to ask:**

- Personal use, hobby projects, research, experiments, and testing.
- Charitable organizations, educational institutions, public research organizations, public safety or health organizations, environmental protection organizations, and government institutions, regardless of how they are funded.

Running a public seed as an individual, a collective, or a nonprofit is free, and always will be.

**Needs a separate license:**

- For-profit companies, including purely internal use on your own infrastructure. Smaller storage bills and the review hours the script saves you are both commercial value; nothing has to be sold for the use to count.

If that is you, or you are not sure which side of the line you land on, email [info@radicle.tools](mailto:info@radicle.tools).

---

[![A radicle.tools artifact — homegrown apps and tools for Radicle](https://radicle.tools/badge/artifact.svg)](https://radicle.tools)
