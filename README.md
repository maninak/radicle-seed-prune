# radicle-seed-prune

[![Sponsor maninak on Liberapay](https://img.shields.io/badge/Liberapay-Donate-F6C915?logo=liberapay&logoColor=black)](https://liberapay.com/maninak/donate)

[![License: PolyForm Noncommercial 1.0.0](https://img.shields.io/badge/License-PolyForm%20Noncommercial%201.0.0-orange.svg)](./LICENSE)
[![Shell](https://img.shields.io/badge/shell-bash-121011.svg?logo=gnu-bash&logoColor=white)](./radicle-seed-prune)
[![rad: - zxvTkxzouwrYFwycnsctrMT3iM2E](https://img.shields.io/static/v1?label=rad%3A&message=zxvTkxzouwrYFwycnsctrMT3iM2E&color=6666FF&cacheSeconds=64800)](https://app.radicle.at/nodes/seed.radicle.at/rad:zxvTkxzouwrYFwycnsctrMT3iM2E)

Reclaim disk on a Radicle seed by safely pruning lower-value repos.

A [Radicle](https://radicle.dev) seed that seeds everything mirrors the whole public network and
grows without bounds. This tool finds the repos least worth holding onto — stale giants,
long-abandoned repos, and obviously disposable ones — and prunes them: **dry-run first**, seed-count
gated so it never deletes the last known copy, and self-tightening as free disk runs low.

## Install

```sh
curl -O https://raw.githubusercontent.com/maninak/radicle-seed-prune/master/radicle-seed-prune
chmod +x radicle-seed-prune
```

Or copy-paste the script manually from [`radicle-seed-prune`](./radicle-seed-prune).

Requirements: `bash`, `git`, `jq`, and `rad` on `PATH`. Run it as the user that owns the Radicle
home (your seed account).

## Usage

```sh
./radicle-seed-prune                  # dry-run: print the plan, change nothing
./radicle-seed-prune --apply          # execute
./radicle-seed-prune --apply --force  # execute even if the plan trips the runaway caps
./radicle-seed-prune --apply --restart  # ...then restart the node to flush its inventory
```

Always read the dry-run first. The plan is sorted largest-first and totals the disk it will free.

### Example output (anonymized)

```text
# radicle-seed-prune  2026-06-28T18:31:50Z   mode=DRY-RUN
# disk: 126.6GB free (46.9%)  pressure=0%  [relax>=54GB crit<=2GB]
# rules: A junk(>30d, seeds>=1)  B size(>500MB & >=P95, >90d, seeds>=3)  C stale(>730d, seeds>=3)
# excluded: 9 pinned, 2 private, 0 own
# repos=9171  sizes P50=0M P90=14M P95=45M P99=267M  rel-cut(P95)=45M  abs-cut=500M

RID                                     SIZE  SEEDS   AGE(d) REASON        NAME
rad:zEXAMPLExxxxxxxxxxxxxxxxxxxx1       1.2GB      6      615 size-outlier  nixpkgs-mirror
rad:zEXAMPLExxxxxxxxxxxxxxxxxxxx2     909.6MB      9      830 size-outlier  texlive-source
rad:zEXAMPLExxxxxxxxxxxxxxxxxxxx3     395.9MB      6      819 stale         some-old-project
rad:zEXAMPLExxxxxxxxxxxxxxxxxxxx4     127.6MB     12      229 junk-name     darkfi-redicle-test
rad:zEXAMPLExxxxxxxxxxxxxxxxxxxx5      29.9MB     14      446 junk-name     test

# PLAN: prune 1341 repos, reclaim 18.04 GiB
#   junk-name       677 repos      0.99 GiB
#   size-outlier     15 repos     11.35 GiB
#   stale           649 repos      5.69 GiB
# DRY-RUN: nothing changed. Re-run with --apply to execute.
```

## How a prune works

For each selected repo, in this exact order:

```sh
rad unseed <rid>        # drop whatever single seeding policy the repo has
rad block  <rid>        # set an explicit block, so default-allow won't re-fetch it
rm -rf  <storage>/<rid> # the only step that actually frees disk
```

Order matters: `rad unseed` removes whichever policy row a repo has, so it must run **before**
`rad block`, never after, or it would wipe the block you just set and the repo would re-seed.

**Recoverability.** Deletion is local. A pruned repo is re-fetchable from the network later
(`rad unseed` to clear the block, then `rad seed`) as long as other nodes still hold it. That is
why every size/age rule has a minimum other-seed-count gate: the tool never deletes the last known
copy. Every prune is written to an audit log under `$RAD_HOME/prune-audit/`.

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

| Rule              | Fires when                                                                                                                                       |
| ----------------- | ----------------------------------------------------------------------------------------------------------------------------------------------- |
| **A — junk-name** | name looks disposable **and** no new commit/COB for > `JUNK_STALE_DAYS` **and** other-seeds ≥ `JUNK_MIN_SEEDS`                                    |
| **B — size**      | size > `ABS_SIZE_FLOOR_MB` **and** size ≥ the `REL_PCTL`-th percentile of all repo sizes **and** stale > `OUTLIER_STALE_DAYS` **and** seeds ≥ `MIN_OTHER_SEEDS` |
| **C — stale**     | anything A/B missed: stale > `STALE_YEARS_DAYS` **and** seeds ≥ `MIN_OTHER_SEEDS`                                                                 |

**"Activity" means any signed change, however small.** Every Radicle interaction — a commit, a new
issue or patch, a comment, a reaction, an edit, a label — is stored as a git commit appended under
some peer's `refs/cobs/*`, and it also advances that peer's `refs/rad/sigrefs`. The tool reads the
newest `creatordate` across **all** refs (every peer's namespace included), so the freshest of any
of these wins. It measures when the change was *authored*, not when we replicated it, so a
just-fetched old comment correctly still reads as old, not as fresh activity.

Disposable names match `test`, `tmp`, `temp`, `scratch`, `playground`, `sandbox`, `demo`, `dummy`,
`wip`, `trash`, `junk`, `old`, `throwaway`, `helloworld` (as whole, boundary-delimited words), plus
`foo` / `bar` / `baz` only when they are the **entire** name (so `BAR_widget` is safe).

### Disk-pressure adaptivity

The thresholds above are the **relaxed** values, used when there is plenty of free space. As free
disk on the storage filesystem falls, the tool **self-tightens**: pressure `p` rises from `0` to
`1` linearly between a relax watermark (`max(PRESSURE_RELAX_PCT%, PRESSURE_RELAX_GB)` free) and a
critical watermark (`min(PRESSURE_CRIT_PCT%, PRESSURE_CRIT_GB)` free, default `min(10%, 2GB)`), and
every knob is interpolated from its relaxed value toward an aggressive one:

| knob              | relaxed (`p=0`) | aggressive (`p=1`) |
| ----------------- | --------------- | ------------------ |
| `STALE_YEARS_DAYS`  | 730  | 60  |
| `OUTLIER_STALE_DAYS`| 90   | 14  |
| `JUNK_STALE_DAYS`   | 30   | 7   |
| `ABS_SIZE_FLOOR_MB` | 500  | 50  |
| `REL_PCTL`          | 95   | 50  |
| `MIN_OTHER_SEEDS`   | 3    | 1   |

The header prints the live pressure and the effective thresholds every run. On one node, pruning
scaled from ~1.3k repos / 18 GiB at `p=0` to ~7.1k repos / 92 GiB at `p=1`. **Hard floors never
scale:** `MIN_OTHER_SEEDS` bottoms out at 1 (never delete the last network copy), and the
pinned/private/own exclusions always hold. Set `DISK_AWARE=0` to disable scaling entirely.

## Configuration

Every knob is an environment variable. Defaults shown.

| Variable             | Default | Meaning                                            |
| -------------------- | ------- | -------------------------------------------------- |
| `ABS_SIZE_FLOOR_MB`  | `500`   | Rule B absolute size floor                          |
| `REL_PCTL`           | `95`    | Rule B relative size percentile                     |
| `OUTLIER_STALE_DAYS` | `90`    | Rule B staleness                                    |
| `JUNK_STALE_DAYS`    | `30`    | Rule A staleness                                    |
| `STALE_YEARS_DAYS`   | `730`   | Rule C staleness (~2 years)                         |
| `MIN_OTHER_SEEDS`    | `3`     | Rules B & C: required other seeds                   |
| `JUNK_MIN_SEEDS`     | `1`     | Rule A: never delete the last copy                  |
| `FRESH_GUARD_DAYS`   | `2`     | Skip repos written this recently                    |
| `MAX_PRUNE_COUNT`    | `1000`  | Runaway guard: abort over this many repos           |
| `MAX_PRUNE_GB`       | `80`    | Runaway guard: abort over this much disk            |
| `SERVICE`            | `radicle-node` | systemd unit used by `--restart`            |
| `DISK_AWARE`         | `1`     | Scale thresholds with free disk (`0` to disable)    |
| `PRESSURE_RELAX_PCT` / `PRESSURE_RELAX_GB` | `20` / `20` | Above this much free: no pressure   |
| `PRESSURE_CRIT_PCT` / `PRESSURE_CRIT_GB`   | `10` / `2`  | At/below `min()` of these: full pressure |
| `*_AGG` (e.g. `STALE_YEARS_DAYS_AGG`) | see above | Full-pressure endpoint for each knob |

```sh
# example: only chase the giants, leave everything else
ABS_SIZE_FLOOR_MB=1000 STALE_YEARS_DAYS=99999 ./radicle-seed-prune
```

## Run it on a schedule

After a reviewed first run, a weekly cron keeps the seed trimmed. Deltas are small, so no restart
is needed, and dropping `--force` keeps the runaway cap active as a safety net:

```cron
# /etc/cron.d/radicle-seed-prune  — Sundays 04:17, as the seed user
SHELL=/bin/sh
17 4 * * 0 seed HOME=/home/seed PATH=/usr/local/bin:/usr/bin:/bin /usr/local/bin/radicle-seed-prune --apply >> /home/seed/.radicle/prune-audit/cron.log 2>&1
```

## Audit trail: what got pruned over time

Every `--apply` run writes to `$RAD_HOME/prune-audit/` (default `~/.radicle/prune-audit/`):

- **`prune-<UTC-timestamp>.log`** — one file per run, the full list of repos removed that run, each
  with size, other-seed count, last-activity, reason, and name. Self-describing header on top.
- **`history.log`** — append-only, one line per run: timestamp, repos deleted, GiB reclaimed,
  disk pressure. The quickest "what has this been doing" view.
- **`cron.log`** — when run from the cron above, the full console output of every run appended.

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
- **Apply preflight** aborts if the node is down or exclusions can't be read, so a transient failure
  never deletes your own or pinned repos.
- **Exclusions** protect pinned, private, and your own repos.
- **Audit log** records every deletion for review or scripted recovery.

The node keeps running during a prune. After a large first run, one
`sudo systemctl restart radicle-node` flushes the node's in-memory inventory of the removed repos
(`--restart` does this for you when run with sufficient rights).

## Support

If this saved you some disk space, some time, and a few bucks on your VPS bill, please support me:

- 💛 Chip in on [Liberapay](https://liberapay.com/maninak/donate) with a micro-donation, if you can comfortably spare it.
- 🌱 Seed this repo on [Radicle](https://app.radicle.at/nodes/seed.radicle.at/rad:zxvTkxzouwrYFwycnsctrMT3iM2E) and ⭐ star it on [GitHub](https://github.com/maninak/radicle-seed-prune).
- 🗣️ Tell a fellow seed operator, or open an issue with ideas and edge cases you hit.

[![Sponsor maninak on Liberapay](https://img.shields.io/badge/Liberapay-Donate-F6C915?logo=liberapay&logoColor=black)](https://liberapay.com/maninak/donate)

## License

[PolyForm Noncommercial License 1.0.0](./LICENSE). Free to use, modify, and share for any
**noncommercial** purpose; you must preserve the copyright and required-notice lines (attribution).
**Commercial use is not permitted** without a separate license. For commercial licensing, contact
the author.

Built by Kostis ([@maninak](https://github.com/maninak)).
