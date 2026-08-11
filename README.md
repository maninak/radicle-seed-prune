# radicle-seed-prune

[![Sponsor maninak on Liberapay](https://img.shields.io/badge/Liberapay-Donate-F6C915?logo=liberapay&logoColor=black)](https://liberapay.com/maninak/donate)

[![version](https://img.shields.io/github/v/release/maninak/radicle-seed-prune?sort=semver&label=version&color=44CC11)](https://github.com/maninak/radicle-seed-prune/releases/latest)
[![License: PolyForm Noncommercial 1.0.0](https://img.shields.io/badge/License-PolyForm%20Noncommercial%201.0.0-orange.svg)](./LICENSE)
[![Shell](https://img.shields.io/badge/shell-bash-121011.svg?logo=gnu-bash&logoColor=white)](./radicle-seed-prune)
[![rad: - zxvTkxzouwrYFwycnsctrMT3iM2E](https://img.shields.io/static/v1?label=rad%3A&message=zxvTkxzouwrYFwycnsctrMT3iM2E&color=6666FF&cacheSeconds=64800)](https://app.radicle.at/nodes/seed.radicle.at/rad:zxvTkxzouwrYFwycnsctrMT3iM2E)

Reclaim disk on a Radicle seed by safely pruning lower-value repos.

A [Radicle](https://radicle.dev) seed that seeds everything mirrors the whole public network and grows without bounds. This tool finds the repos least worth holding onto (stale giants, long-abandoned repos, obviously disposable ones, and mass-generated spam families) and prunes them: **dry-run first**, seed-count gated so it never deletes the last known copy, and self-tightening as free disk runs low.

## Install

```sh
curl -O https://raw.githubusercontent.com/maninak/radicle-seed-prune/master/radicle-seed-prune
chmod +x radicle-seed-prune
```

Or copy-paste the script manually from [`radicle-seed-prune`](./radicle-seed-prune).

Requirements: `bash`, `git`, `jq`, and `rad` on `PATH`.

## Usage

```sh
./radicle-seed-prune                  # preview (dry-run): print the plan, change nothing
./radicle-seed-prune --apply          # apply, asks [y/N] first when run in a terminal
./radicle-seed-prune --apply --yes    # apply without the prompt (scripts, or when you're sure)
./radicle-seed-prune --apply --force  # apply even if the plan trips the runaway caps
./radicle-seed-prune --apply --restart-node  # ...and restart the node afterwards (clears the stale inventory-announce log warning)
./radicle-seed-prune --version
```

Always read the preview first. The plan is sorted largest-first and totals the disk it will free.

Run it as the user that owns the Radicle home, or point `RAD_HOME` at one. That is the same variable heartwood itself reads, so a run reads like any other `rad` invocation, and `RAD` picks the binary:

```sh
RAD_HOME=/var/lib/radicle ./radicle-seed-prune                          # a seed home that isn't yours
RAD=/nix/store/.../bin/rad RAD_HOME=/var/lib/radicle ./radicle-seed-prune # ...and a specific rad
```

There are deliberately no tuning flags: every knob is an environment variable, listed under [Configuration](#configuration).

**There is no `--dry-run` flag, because running with no flags *is* the dry run.** `--apply` scans once, prints that same plan, and then:

- in a terminal, asks `[y/N]` before deleting anything: answer yes to apply the plan you just saw;
- non-interactively (cron, a pipe), it just applies, since there is nobody to answer.

The single scan is the point: a dry-run to preview and then a separate `--apply` would scan the whole seed twice. Pass `--yes` (`-y`) to skip the prompt in a terminal. Confirming interactively also bypasses the runaway caps (you have seen the numbers); cron and `--yes` still respect them, so add `--force` to exceed them unattended.

### Example output (anonymized)

```text
# radicle-seed-prune  2026-06-28T18:31:50Z   mode=DRY-RUN
# disk: 126.6GB free (46.9%)  pressure=0%  [relax>=54GB crit<=2GB]
# rules: A junk(>30d, seeds>=1)  B size(>500MB & >=P95, >90d, seeds>=3)  C stale(>730d, seeds>=3)  D spam(family>=5 & desc>=80%, >7d, seeds>=1)
# excluded: 9 pinned, 2 private, 0 own
# spam families: 10 template(s) matching 974 repos, before the age/seed gates:
#     110  palindrome-*-*
#     103  sum-*-*
#     101  factorial-*-*
#      99  evens-*-*
#      97  unique-*-*
#   ...and 5 more
# repos=9171  sizes P50=0M P90=14M P95=45M P99=267M  rel-cut(P95)=45M  abs-cut=500M

RID                                     SIZE  SEEDS   AGE(d) REASON        NAME
rad:zEXAMPLExxxxxxxxxxxxxxxxxxxx1       1.2GB      6      615 size-outlier  nixpkgs-mirror
rad:zEXAMPLExxxxxxxxxxxxxxxxxxxx2     909.6MB      9      830 size-outlier  texlive-source
rad:zEXAMPLExxxxxxxxxxxxxxxxxxxx3     395.9MB      6      819 stale         some-old-project
rad:zEXAMPLExxxxxxxxxxxxxxxxxxxx4     127.6MB     12      229 junk-name     darkfi-redicle-test
rad:zEXAMPLExxxxxxxxxxxxxxxxxxxx5      29.9MB     14      446 junk-name     test
rad:zEXAMPLExxxxxxxxxxxxxxxxxxxx6     100.4KB     11       13 spam-family   evens-2-33ed7115

# PLAN: prune 2315 repos, reclaim 18.13 GiB
#   junk-name       677 repos      0.99 GiB
#   size-outlier     15 repos     11.35 GiB
#   spam-family     974 repos      0.09 GiB
#   stale           649 repos      5.69 GiB
# DRY-RUN: nothing changed. Re-run with --apply to execute.
```

Reading the header top to bottom: free disk and the pressure it produces, the four rules with the thresholds **actually in effect at that pressure**, what was excluded, the spam families found, and the size distribution rule B's percentile is drawn from. Then the plan itself, largest-first, and a total per reason.

In those per-reason totals, `spam-family` reads as a lot of work for nothing: 974 repos for 0.09 GiB. It is not. Rule D is about inventory hygiene more than disk. A thousand template repos are a few dozen MB, but they are a thousand entries your node announces, fetches and re-announces forever, and each one is a row in every listing you read.

### Exit codes

| Code | Meaning                                                                                                                               |
| ---- | ------------------------------------------------------------------------------------------------------------------------------------- |
| `0`  | Success, including a dry-run and an `--apply` you declined at the prompt                                                              |
| `1`  | Storage directory missing or unreadable, or an unexpected failure (the run prints the line and the command)                           |
| `2`  | Bad argument                                                                                                                          |
| `3`  | The plan tripped a runaway cap. Read it, then re-run with `--force`                                                                   |
| `5`  | Refused to guess: node unreachable, NID unknown, routing table empty, exclusions unreadable, or too much of storage could not be read |

Exit 5 always means the tool could not see enough to be trusted, never that there was nothing to do. Nothing was touched.

## How a prune works

For each selected repo, in this exact order:

```sh
rad unseed <rid>        # drop whatever single seeding policy the repo has
rad block  <rid>        # set an explicit block, so default-allow won't re-fetch it
rm -rf  <storage>/<rid> # the only step that actually frees disk
```

Order matters: `rad unseed` removes whichever policy row a repo has, so it must run **before** `rad block`, never after, or it would wipe the block you just set and the repo would re-seed.

**Recoverability.** Deletion is local. A pruned repo is re-fetchable from the network later as long as other nodes still hold it. That is why every rule has a minimum other-seed-count gate: the tool never deletes the last known copy. Undoing a prune is clearing the block and seeding again, and the [audit log](#audit-trail-what-got-pruned-over-time) holds every RID that was removed:

```sh
rad unseed rad:<rid> && rad seed rad:<rid>    # one repo

# ...or every repo a given run removed, read back out of that run's audit log
awk -F'\t' '!/^#/ {print "rad:"$1}' ~/.radicle/prune-audit/prune-20260628T183150Z.log |
  while read -r rid; do rad unseed "$rid" && rad seed "$rid"; done
```

## The pruning algorithm

A repo is pruned if it is **not excluded** and matches **at least one rule**.

### Exclusions (never touched)

| Exclusion       | Source                                                |
| --------------- | ----------------------------------------------------- |
| Pinned repos    | `config.web.pinned.repositories`                      |
| Private repos   | `rad ls --private`                                    |
| Your own repos  | `rad ls` (repos you initialized or forked / delegate) |
| Freshly written | storage dir modified within `FRESH_GUARD_DAYS`        |
| Unknown age     | no readable refs (left alone out of caution)          |

### Rules

Every rule has the same shape: **something about the repo**, *and* it has sat untouched long enough, *and* enough other nodes still hold it. All three, always.

| Rule               | The repo looks like                                                                 | No activity for           | Other seeds            |
| ------------------ | ----------------------------------------------------------------------------------- | ------------------------- | ---------------------- |
| **A, junk-name**   | a disposable name (`test`, `tmp`, a bare random hex id)                             | `JUNK_STALE_DAYS`, 30d    | ≥ `JUNK_MIN_SEEDS`, 1  |
| **B, size**        | a giant: over `ABS_SIZE_FLOOR_MB` (500M) *and* in the top `REL_PCTL`% by size (P95) | `OUTLIER_STALE_DAYS`, 90d | ≥ `MIN_OTHER_SEEDS`, 3 |
| **C, stale**       | nothing in particular; the catch-all for whatever A/B/D missed                      | `STALE_YEARS_DAYS`, 730d  | ≥ `MIN_OTHER_SEEDS`, 3 |
| **D, spam-family** | one of a mass-generated template family ([below](#rule-d-spam-families))            | `SPAM_STALE_DAYS`, 7d     | ≥ `SPAM_MIN_SEEDS`, 1  |

Defaults are shown; each one is an environment variable, and each tightens under [disk pressure](#disk-pressure-adaptivity).

**"Activity" means any signed change, however small.** Every Radicle interaction (a commit, a new issue or patch, a comment, a reaction, an edit, a label) is stored as a git commit appended under some peer's `refs/cobs/*`, and it also advances that peer's `refs/rad/sigrefs`. The tool reads the newest `creatordate` across **all** refs (every peer's namespace included), so the freshest of any of these wins. It measures when the change was *authored*, not when we replicated it, so a just-fetched old comment correctly still reads as old, not as fresh activity.

Disposable names match `test`, `tmp`, `temp`, `scratch`, `playground`, `sandbox`, `demo`, `dummy`, `wip`, `trash`, `junk`, `old`, `throwaway`, `helloworld` (as whole words, delimited by `-`, `_`, `.` or the ends of the name), plus `foo` / `bar` / `baz` only when they are the **entire** name (so `BAR_widget` is safe). A space is deliberately *not* a delimiter: names with spaces read as prose, where "old" or "demo" are ordinary English words rather than the slug marker being hunted, so `test-old` matches and `The old man` does not. A name that is *nothing but* a random hex id of `JUNK_ID_MIN_LEN`+ characters counts too (`08a25d0f666d`), but not `12345678` and not `facade`, since both letters and digits are required.

### Rule D: spam families

Bulk-generated repos give nothing away one at a time. A repo called `evens-2-33ed7115` described as *"Keep only even values from an array. Variant 2."* could be anybody's scratch work. A hundred of them is a generator. So rule D is decided by the **corpus**, never by a single repo.

Every name and description in storage is *skeletonised*: digit runs become `#`, random-id tokens (6+ hex characters carrying both a letter and a digit) become `%`. `evens-2-33ed7115` becomes `evens-#-%`. Repos are then grouped by that skeleton with `#` and `%` collapsed into one wildcard, so `evens-*-*`, and a group is a spam family only when **all** of these hold:

1. at least `SPAM_MIN_FAMILY` repos share the skeleton;
2. at least one of them carries a **random-id** slot rather than a plain enumeration; `SPAM_REQUIRE_ID=0` drops this requirement;
3. at least `SPAM_DESC_AGREE_PCT`% of them share **one** non-empty description skeleton.

Only the members carrying that agreed description are pruned, so a genuine repo that happens to share the name shape is left where it is. Collapsing `#` and `%` for grouping matters because a random hex token comes out all-digits about 2% of the time (`sum-1-96180521`), which would otherwise split a family and strand those siblings.

**Two independent signals are required, and that is what keeps false positives near zero.** On a real 11,684-repo seed the rule flags 974 repos in 10 families and nothing else. It is the description agreement doing that work, not the family size: on the same corpus, dropping `SPAM_MIN_FAMILY` all the way to 3 flags the identical 974 repos and no extra family. Specifically:

- a 240-repo `Adafruit_CircuitPython_*.git` mirror import shares a name skeleton, but every repo carries its own real description, so it is never flagged;
- a 427-repo `cloud-itonami-isic-####` per-standard-code set likewise;
- 48 unrelated repos share the description *"Migrated from Forgejo"* while their names have nothing in common, so that never fires either.

The random-id requirement is the third guard. Version and enumeration slots (`linux-6.1.y`, `serde-1.0.195`, `release-202401`) mean something to a human; an 8-hex-char token in a repo name is a machine artifact. Demanding both a letter and a digit in that token is what keeps a date or sequence suffix on the enumeration side of the line. Turning the requirement off is looser and can reach a version-mirror farm whose descriptions are also templated.

Two deliberate limits, so you know what the rule does not do:

- **Timing is not a signal.** Measured on a real seed, the legitimate 240-repo mirror import spans `0.00` days of activity while the spam family spans `14.8`. "Created in a burst" would flag the mirror and miss the spam, so it is not used.
- **Descriptions differing only by a number count as agreeing**, because *"Variant 2"* vs *"Variant 3"* is exactly the signature being hunted. A set whose descriptions differ only by a version number therefore rests entirely on the random-id requirement above.

Repos with no description at all are never flagged: with no description there is only one signal left, and one is not enough.

### Disk-pressure adaptivity

The thresholds above are the **relaxed** values, used when there is plenty of free space. As free disk on the storage filesystem falls, the tool **self-tightens**: pressure `p` rises from `0` to `1` linearly between a relax watermark (`max(PRESSURE_RELAX_PCT%, PRESSURE_RELAX_GB)` free) and a critical watermark (`min(PRESSURE_CRIT_PCT%, PRESSURE_CRIT_GB)` free, default `min(10%, 2GB)`), and every knob is interpolated from its relaxed value toward an aggressive one:

| knob                 | relaxed (`p=0`) | aggressive (`p=1`) |
| -------------------- | --------------- | ------------------ |
| `STALE_YEARS_DAYS`   | 730             | 60                 |
| `OUTLIER_STALE_DAYS` | 90              | 14                 |
| `JUNK_STALE_DAYS`    | 30              | 7                  |
| `SPAM_STALE_DAYS`    | 7               | 1                  |
| `ABS_SIZE_FLOOR_MB`  | 500             | 50                 |
| `REL_PCTL`           | 95              | 50                 |
| `MIN_OTHER_SEEDS`    | 3               | 1                  |

The header prints the live pressure and the effective thresholds every run. On one node, pruning scaled from ~1.3k repos / 18 GiB at `p=0` to ~7.1k repos / 92 GiB at `p=1`. **Hard floors never scale:** `MIN_OTHER_SEEDS` bottoms out at 1 (never delete the last network copy), and the pinned/private/own exclusions always hold. Set `DISK_AWARE=0` to disable scaling entirely.

## Configuration

Every knob is an environment variable, so a run is configured the same way `rad` itself is. Defaults shown.

**Where it runs**

| Variable   | Default                       | Meaning                                                                        |
| ---------- | ----------------------------- | ------------------------------------------------------------------------------ |
| `RAD`      | `rad`                         | The rad binary to call                                                         |
| `RAD_HOME` | `rad path`, else `~/.radicle` | Radicle home to operate on; `STORAGE`, `CONFIG` and `AUDIT_DIR` derive from it |
| `SERVICE`  | `radicle-node`                | systemd unit used by `--restart-node`                                          |
| `JOBS`     | `cores-1`                     | Parallel workers for the activity scan                                         |

**What each rule needs to fire**

| Rule | Variable              | Default | Meaning                                                                 |
| ---- | --------------------- | ------- | ----------------------------------------------------------------------- |
| A    | `JUNK_STALE_DAYS`     | `30`    | Staleness required                                                      |
| A    | `JUNK_MIN_SEEDS`      | `1`     | Other seeds required; never delete the last copy                        |
| A    | `JUNK_ID_MIN_LEN`     | `8`     | Length at which an all-hex name counts as a random id (`0` disables it) |
| B    | `ABS_SIZE_FLOOR_MB`   | `500`   | Absolute size floor                                                     |
| B    | `REL_PCTL`            | `95`    | Size percentile, across all repos on the seed                           |
| B    | `OUTLIER_STALE_DAYS`  | `90`    | Staleness required                                                      |
| C    | `STALE_YEARS_DAYS`    | `730`   | Staleness required (~2 years)                                           |
| B, C | `MIN_OTHER_SEEDS`     | `3`     | Other seeds required, shared by both rules                              |
| D    | `SPAM_MIN_FAMILY`     | `5`     | Repos sharing a name skeleton before it counts as a family              |
| D    | `SPAM_DESC_AGREE_PCT` | `80`    | Share of that family that must agree on one description skeleton        |
| D    | `SPAM_REQUIRE_ID`     | `1`     | Demand a random-id slot in the name skeleton (`0` is looser)            |
| D    | `SPAM_STALE_DAYS`     | `7`     | Staleness, here a grace period rather than evidence                     |
| D    | `SPAM_MIN_SEEDS`      | `1`     | Other seeds required; never delete the last copy                        |

**Brakes**

| Variable            | Default | Meaning                                                    |
| ------------------- | ------- | ---------------------------------------------------------- |
| `FRESH_GUARD_DAYS`  | `2`     | Skip repos written this recently (an in-flight fetch)      |
| `MAX_PRUNE_COUNT`   | `1000`  | Runaway guard: abort over this many repos                  |
| `MAX_PRUNE_GB`      | `80`    | Runaway guard: abort over this much disk                   |
| `MAX_SCAN_FAIL_PCT` | `10`    | Abort if more than this share of storage could not be read |

**Disk pressure** ([what it does](#disk-pressure-adaptivity))

| Variable                                   | Default     | Meaning                                          |
| ------------------------------------------ | ----------- | ------------------------------------------------ |
| `DISK_AWARE`                               | `1`         | Scale thresholds with free disk (`0` to disable) |
| `PRESSURE_RELAX_PCT` / `PRESSURE_RELAX_GB` | `20` / `20` | Above this much free: no pressure                |
| `PRESSURE_CRIT_PCT` / `PRESSURE_CRIT_GB`   | `10` / `2`  | At/below `min()` of these: full pressure         |
| `*_AGG`, e.g. `STALE_YEARS_DAYS_AGG`       | see above   | Full-pressure endpoint for each knob that scales |

```sh
# example: only chase the giants, leave everything else
ABS_SIZE_FLOOR_MB=1000 STALE_YEARS_DAYS=99999 ./radicle-seed-prune
```

## Run it on a schedule

After a reviewed first run, a weekly cron keeps the seed trimmed. Deltas are small, so no restart is needed, and dropping `--force` keeps the runaway cap active as a safety net.

Substitute the user your node runs as and that user's home; the example uses `radicle` with `/home/radicle`, but nothing in the tool assumes either. Cron runs with a minimal environment, so `HOME` and `PATH` have to be spelled out:

```cron
# /etc/cron.d/radicle-seed-prune  Sundays 04:17
SHELL=/bin/sh
17 4 * * 0 radicle HOME=/home/radicle PATH=/usr/local/bin:/usr/bin:/bin /usr/local/bin/radicle-seed-prune --apply >> /home/radicle/.radicle/prune-audit/cron.log 2>&1
```

Point `RAD_HOME` at the node's home instead if it does not live at `$HOME/.radicle`.

## Audit trail: what got pruned over time

Every `--apply` run writes to `$RAD_HOME/prune-audit/` (default `~/.radicle/prune-audit/`):

- **`prune-<UTC-timestamp>.log`**: one file per run, the full list of repos removed that run, tab-separated as `rid`, size, other-seed count, last-activity, reason, and name. Self-describing header on top.
- **`history.log`**: append-only, one line per run: timestamp, repos deleted, GiB reclaimed, disk pressure. The quickest "what has this been doing" view.
- **`cron.log`**: when run from the cron above, the full console output of every run appended.

```sh
tail ~/.radicle/prune-audit/history.log              # totals per run, newest last
cat  ~/.radicle/prune-audit/prune-2026*.log          # exact repos removed, with reasons
awk -F'\t' '/reclaimed/{n++; g+=$3} END{print n" runs, "g" GiB total"}' ~/.radicle/prune-audit/history.log
```

## Safety model, in one place

- **Dry-run by default.** Nothing is deleted without `--apply`.
- **Seed-count gates** keep the last network copy of any repo.
- **Runaway caps** (`MAX_PRUNE_COUNT`, `MAX_PRUNE_GB`) abort an unexpectedly large plan unless `--force`.
- **Freshness guard** skips repos with an in-flight fetch.
- **Apply preflight** aborts if the node is down or exclusions can't be read, so a transient failure never deletes your own or pinned repos.
- **Exclusions** protect pinned, private, and your own repos.
- **Audit log** records every deletion for review or scripted recovery.

The node keeps running during a prune. After a large first run, one `sudo systemctl restart radicle-node` clears the stale "inventory announce limit" warning from the node log (`--restart-node` does this for you when run with sufficient rights). On some heartwood versions `rad node inventory` may still list the removed RIDs afterwards; that is cosmetic, the repos are gone from disk and blocked from re-seeding.

## Development

Run the test suite (needs only `bash`, `git`, and coreutils):

```sh
bash tests/run.sh
```

It builds a fully isolated, hermetic fixture (a throwaway Radicle home, a `rad` stub on `PATH`, and real bare git repos with controlled activity dates and sizes) so it never reads or writes the real node. See [`CHANGELOG.md`](./CHANGELOG.md) for release history.

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
