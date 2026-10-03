# radicle-seed-prune

[![Sponsor maninak on Liberapay](https://img.shields.io/badge/Liberapay-Donate-F6C915?logo=liberapay&logoColor=black)](https://liberapay.com/maninak/donate)

[![version](https://img.shields.io/github/v/release/maninak/radicle-seed-prune?sort=semver&label=version&color=44CC11)](https://github.com/maninak/radicle-seed-prune/releases/latest)
[![license: Apache 2.0](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](./LICENSE)
[![shell](https://img.shields.io/badge/shell-bash-121011.svg?logo=gnu-bash&logoColor=white)](./rad-prune)
[![rad: - zxvTkxzouwrYFwycnsctrMT3iM2E](https://img.shields.io/static/v1?label=rad%3A&message=zxvTkxzouwrYFwycnsctrMT3iM2E&color=6666FF&cacheSeconds=64800)](https://app.radicle.at/nodes/seed.radicle.at/rad:zxvTkxzouwrYFwycnsctrMT3iM2E)
[![zulip: #radicle-seed-prune](https://img.shields.io/badge/Zulip-%23radicle--seed--prune-6492FE?logo=zulip&logoColor=white)](https://radicle.zulipchat.com/#narrow/channel/624837-radicle-seed-prune)
[![radicle.tools artifact](https://img.shields.io/badge/radicle.tools-artifact-ff1aff?labelColor=15161c)](https://radicle.tools)

**Automatically detect and prune lower-value repos, spam and abuse from a [Radicle](https://radicle.dev) node's storage.**

It does two jobs:

- **Reclaims disk**: prunes stale giants, long-abandoned repos and disposable ones.
- **Moderates content**: prunes mass-generated spam, link farms and media dumps, and names peers who push their own files into repos they do not own.

Tuned against and running in production for seed.radicle.at seeding the whole public Radicle network. Read the plan before you apply anything.

## Install

```sh
src=$(mktemp -d)
rad clone rad:zxvTkxzouwrYFwycnsctrMT3iM2E "$src"
sudo install -m 755 "$src/rad-prune" /usr/local/bin/rad-prune
```

Cloning ensures you're installing the unaltered script as signed by the repo's owner. Re-run those lines later to install a newer version.

Alternatively, fetch it over HTTPS and trust GitHub for the transfer:

```sh
curl -O https://raw.githubusercontent.com/maninak/radicle-seed-prune/master/rad-prune
chmod +x rad-prune
sudo mv rad-prune /usr/local/bin/
```

Needs `bash`, `git`, `jq`, `rad` and OpenSSL 3 on `PATH`. Run it as the user that owns the Radicle home you want pruned, or set `RAD_HOME` to that home.

Anywhere on `PATH` under the name `rad-prune`, `rad` runs it as one of its own subcommands, which is what the examples below use. `rad-prune ...` does the same thing, and so does `./rad-prune ...` from wherever you put it.

## Usage

```sh
rad prune                    # preview: print the plan, change nothing
rad prune --apply            # apply, asks [y/N] first when run in a terminal
rad prune --apply --yes      # answer the confirmation with y (scripts, cron)
rad prune --apply --force    # apply even if the plan trips a runaway cap or a rule jumps
rad prune --apply --restart-node  # ...and restart the node afterwards
rad prune --block-peers      # block what rule G found, one [y/N] per peer; prunes nothing
rad prune quarantine ...     # list, restore, delete, purge quarantined repos
rad prune --version
```

There is no `--dry-run` flag: running with no flags is the dry run. `--apply` scans once, prints that same plan, asks `[y/N]` in a terminal, and just applies when there is nobody to ask (cron, a pipe). `--yes` answers every prompt a run asks, including the per-peer block prompt.

`--block-peers` is its own action and does not imply `--apply`; pass both flags if you mean both actions. It asks once per peer before blocking that peer. `--block-peers --yes` answers those prompts with y, which is the form a cron job wants; `--block-peers` alone with nobody to ask (cron, a pipe) blocks nobody and prints the `rad block` commands instead.

The plan is sorted largest repo first and totals the disk the run would free. `--help` lists the options and the quarantine verbs, and prints the paths this run resolved.

Every knob is an environment variable rather than a flag, so a run is configured the way `rad` itself is:

```sh
RAD_HOME=/var/lib/radicle rad prune          # a seed home that isn't yours
RAD=/nix/store/.../bin/rad rad-prune         # a specific rad binary
sudo -u <node-user> env RAD_HOME=/var/lib/radicle rad-prune   # as the user the node runs as
```

Run it as the user that owns storage, or it stops rather than scanning nothing. It needs `rad`, `git`, `jq`, `openssl`, `awk`, `sed`, `grep`, `find` and coreutils on the `PATH` you hand it, and a run missing one of them names it and stops. That is worth checking whenever the `PATH` is not your own login one: a systemd unit, a Nix wrapper, and `sudo`, which replaces `PATH` with its own `secure_path` wherever sudoers sets one. If a run names a command you know is installed, hand it the `PATH` you meant: `sudo -u <node-user> env PATH="$PATH" RAD_HOME=/var/lib/radicle rad-prune`.

### Example output

A dry run against a seed of 12,292 repos:

```
# radicle-seed-prune 0.7.0  2026-09-10T04:16:49Z   mode=DRY-RUN
# home=/var/lib/radicle  audit=/var/lib/radicle/prune-audit
# disk: 125.5GB free (46.5%)  pressure=0% [relax>=54GB crit<=2GB]
# rules: A junk(>30d, seeds>=1, spare-import>14d; id-names seeds>=0)  B size(>500MB & >=P95, >90d, seeds>=3)  C stale(>730d, seeds>=3)  D spam(batch>=5 & desc>=80%, >7d, seeds>=0)
# rule E link-farm(>=5 spam domains, each linked from >=0.4% of repos and from the code of <10% of them, >7d, seeds>=0)
# rule F media-dump(>=64KB of media and <2048B of anything else, >7d, seeds>=0)  media-batch(that media held by >=5 repos, <65536B of anything else)
# rule G parasite-peer(one file of theirs in >=10 repos they do not own, >=1MB media, <16384B of anything else) [reports only; --block-peers asks per peer]
# excluded: 9 pinned, 6 private, 0 own, 0 kept
# spam batches: 10 template(s) matching 999 repos, before the age and seed checks:
#     111  template-a-*-*
#     105  template-b-*-*
#     104  template-c-*-*
#     103  template-d-*-*
#     102  template-e-*-*
#   ...and 5 more (PLAN_FULL=1 lists them)
# harvested 308659 repo/host pairs over 10963 repos
# spam domains: 159 domain(s) linked from >=49 repos, <10% from code;
#   893 repo(s) link to >=5 of them, before the age and seed checks:
#     826 repos  spam-host-1.example
#     707 repos  spam-host-2.example
#     640 repos  spam-host-3.example
#     616 repos  spam-host-4.example
#     562 repos  spam-host-5.example
#   ...and 154 more (PLAN_FULL=1 lists them)
# rule E: 1 repo(s) spared, the spam links were pushed by peers that are not their delegates
# repos=12292  sizes P50=0M P90=8M P95=28M P99=186M rel-cut(P95)=28M  abs-cut=500M
# skipped: 0 unreadable, 1218 written in the last 2d, 0 with no readable refs

RID                                     SIZE  SEEDS   AGE(d) REASON        NEAR            NAME
zEXAMPLEREPOaaaaaaaaaaaaaaa          330.8MB     13      191 media-dump    -               example-media-repo-1
zEXAMPLEREPObbbbbbbbbbbbbbb          192.7MB     12      191 media-dump    -               example-media-repo-2
zEXAMPLEREPOccccccccccccccc           50.5MB      7      187 media-dump    -               example-media-repo-3
zEXAMPLEREPOddddddddddddddd           44.5MB     10      191 media-dump    -               example-media-repo-4
zEXAMPLEREPOeeeeeeeeeeeeeee           42.1MB     14      243 media-dump    -               example-media-repo-5
zEXAMPLEREPOfffffffffffffff           30.8MB      7      191 media-dump    -               example-media-repo-6
zEXAMPLEREPOggggggggggggggg           21.8MB     12      540 media-dump    -               example-media-repo-7
zEXAMPLEREPOhhhhhhhhhhhhhhh           12.3MB      9      184 media-dump    -               example-media-repo-8
zEXAMPLEREPOiiiiiiiiiiiiiii           11.2MB      5      730 stale         age             example-abandoned-repo
zEXAMPLEREPOjjjjjjjjjjjjjjj            8.9MB     22      191 media-dump    -               example-media-repo-9
[... 19 more single-repo rows ...]
zEXAMPLEREPOxxxxxxxxxxxxxxx          128.9KB      9       30 junk-name     age             example-demo-repo
zEXAMPLEREPOyyyyyyyyyyyyyyy           75.0KB     10       30 junk-name     age             example-hello-world
zEXAMPLEREPOzzzzzzzzzzzzzzz           74.3KB      8      731 stale         age             example-test-1
zEXAMPLEREPOwwwwwwwwwwwwwww           73.9KB     13       31 junk-name     age             example-test-2
(440 repos)                           50.8MB                 spam-batch    0 near          same pattern across many repos; PLAN_FULL=1 lists them
(35 repos)                           405.4MB                 link-farm     2 near          same pattern across many repos; PLAN_FULL=1 lists them
(23 repos)                             1.3GB                 media-batch   0 near          same pattern across many repos; PLAN_FULL=1 lists them

# PLAN: prune 531 repos, 2.49 GiB out of storage but still on disk for 7d, until a later --apply run deletes them
#   junk-name         6 repos      0.00 GiB
#   link-farm        35 repos      0.40 GiB
#   media-batch      23 repos      1.29 GiB
#   media-dump       23 repos      0.75 GiB
#   spam-batch      440 repos      0.05 GiB
#   stale             4 repos      0.01 GiB
#   12 of them cleared a threshold by under 20%: see the NEAR column, which names the threshold that was close. Read those rows first.
# the untrimmed plan and the evidence behind it: /var/lib/radicle/prune-audit/last-run/
# DRY-RUN: nothing in storage changed. Re-run with --apply to execute.
```

Corpus verdicts (`spam-batch`, `link-farm`, `media-batch`) fold to one summary line per group at `PLAN_COLLAPSE_ROWS` (20) rows; single-repo verdicts are always listed in full, and `PLAN_FULL=1` lists everything. The evidence tables above the plan (spam templates, spam domains, scan errors, and any media dumps a raised `MEDIA_MIN_SEEDS` kept) show their top few entries and say how many they left out; `PLAN_FULL=1` prints those whole too.

`AGE(d)` is the age the matching rule measured: days since last activity for A, B and C, days since creation for D, E and F.

`NEAR` names any threshold the row cleared by less than `NEAR_PCT` (20%), and is `-` when the row cleared every one of them comfortably. It reports the numbers the matching rule actually tested: `age` for every rule, `seeds` where the rule has a seed floor above zero, plus `import` for rule A's word branch, `size` for rule B, `media` for rule F and `score` for rule E. For copies of denied files it reports only `bytes` and `share`. Those are the rows to read first, and the summary under the plan counts them. `NEAR_PCT=0` marks nothing.

Everything a run says about itself, the progress below included, goes to stderr, and the plan to stdout, so `> plan.txt` keeps them apart.

### Progress

Every rule reads every repo in storage, which on a large seed is minutes per phase. In a terminal one line is kept up to date with the phase, the repos read so far and how much longer it has:

```
  [5/6] rule E    [==========          ]  52% 5820/11184 repos 2m14s ~2m03s left
```

It is redrawn in place and wiped when the phase ends, leaving a line per phase saying what that phase cost:

```
# sizes: 11184 repos in 41s
# activity: 11184 repos in 1m12s
# rule F: 11184 repos in 4m38s
# rule G: 11184 repos in 2m11s
# rule E: 11184 repos in 6m02s
# delegates: 893 repos in 1m47s
```

Where the output is not a terminal (cron, a pipe, a log file) the same reading is printed as an ordinary line every `PROGRESS_SECS` (60) instead of being redrawn. `PROGRESS_SECS=0` turns all of it off.

A phase counts the repos it has to read this run, not everything in storage, so a run that reuses the cache measures itself against the handful of repos that changed, and `delegates` (rule E re-reading what it flagged, to check whose links they are) against those flagged repos.

### Exit codes

| Code | Meaning                                                                                                                              |
| ---- | ------------------------------------------------------------------------------------------------------------------------------------ |
| `0`  | Success, including a dry run and an `--apply` you declined at the prompt                                                             |
| `1`  | Storage missing or unreadable, or an unexpected failure (the run prints the line, the command and its status)                        |
| `2`  | Bad argument, `MAX_PRUNE_COUNT` or a `RATCHET_*` setting that is not a whole number, or `DISK_AWARE` other than `0` or `1`          |
| `3`  | The plan tripped a runaway cap; nothing was pruned. Read it, then re-run with `--force`                                              |
| `4`  | A rule planned far more than usual, so its repos were held back; anything else in the plan was pruned. Read it, then `--force`       |
| `5`  | Refused to guess: node unreachable, NID unknown or malformed, `rad ls` failed, routing table empty, exclusions unreadable, or too much of storage could not be read |

Exit 5 means the tool could not see enough to be trusted; nothing was touched.

## What gets pruned

A repo is pruned when one of these holds, unless it is pinned, private, your own or in `keep.txt`:

- it is **not [excluded](#exclusions-never-touched-by-a-rule)** and matches **at least one rule**;
- the [deny list](#deny-list) names it or one of its delegates;
- it holds [copies of denied files](#copies-of-denied-files).

`RULES` (default `ABCDEFG`) selects which rules run: a letter absent from it means that rule neither scans nor puts anything in the plan, and a repo a disabled rule would have claimed falls through to the next rule.

### Exclusions (never touched by a rule)

| Exclusion       | Source                                                |
| --------------- | ----------------------------------------------------- |
| Pinned repos    | `config.web.pinned.repositories`                      |
| Private repos   | `rad ls --private`, or a private identity document    |
| Your own repos  | `rad ls`, or this node's signed refs in the repo      |
| Kept repos      | `$AUDIT_DIR/keep.txt`, one repo id per line ([more](#quarantine)) |
| Freshly written | storage dir modified within `FRESH_GUARD_DAYS`        |
| Unknown age     | no readable refs (also counted against `MAX_SCAN_FAIL_PCT`) |
| Unreadable      | hit an error when reading the repo                    |

### Deny list

Repos and identities you, or someone you trust, have already judged go in `$AUDIT_DIR/deny.txt`, one per line, with or without the `rad:` or `did:key:` prefix. `#` starts a comment. A list another operator shares works as is. To use several, concatenate them into this one file.

```
rad:z<rid>          # a repo: pruned and blocked, even before it arrives
did:key:z6Mk<nid>   # an identity: blocked, and every repo it is a delegate of is pruned
```

`--apply` prunes and blocks as the lines above say, regardless of age, size, seed count or an unfinished fetch. An identity's patches or comments in a repo it is not a delegate of do not count. Pinned, private, your own and `keep.txt` repos are never pruned, and an identity that delegates one of them is not blocked. Denied repos skip the runaway caps and the hold-back, but a run the caps stop acts on none of them.

Removing a line does not undo its blocks. Run `rad unblock rad:z<rid>` or `rad unblock z6Mk<nid>`.

#### Copies of denied files

`$AUDIT_DIR/deny-files.tsv` lists files by git object id. A repo holding copies of them is pruned as `denied-copy`. To add a denied repo's files while it is still in the quarantine:

```sh
rad prune quarantine files z<rid> >> ~/.radicle/prune-audit/deny-files.tsv
```

Each row is `<object id> <bytes or -> <source> [date]`, fields separated by spaces or tabs, and `#` starts a comment. A list another operator shares works as is, but its ids cannot be checked by reading them, so use one only from someone you trust.

A repo is a copy when its delegates' branches and tags, history included, hold at least 5 MiB of listed images, video, audio or archives, making up at least half of the bytes there. Files someone else pushed, or attached to an issue or patch, do not count. A row counts against every repo whose delegates committed that file, so list only files that are the denied repo's own.

Copies are pruned like repos the deny list names by id, and no identity is blocked for one. Unlike repos the deny list names, copies count against the runaway caps and the hold-back. Rows whose source is in `keep.txt` are ignored. `last-run/denied-copies.tsv` says how much of each copy is listed files, and `last-run/denied-copy-files.tsv` lists those files.

### Rules

Every rule has the same shape: **something about the repo**, *and* it is old enough, *and* enough other nodes still hold it. Defaults shown; each is an environment variable.

| Rule               | The repo looks like                                                                                    | Minimum age               | Other seeds              |
| ------------------ | ------------------------------------------------------------------------------------------------------ | ------------------------- | ------------------------ |
| **A, junk-name**   | a disposable *word* in the name (`test`, `tmp`, `old`, `demo`), unless its history starts more than 14 days before `rad init` | `JUNK_STALE_DAYS`, 30d    | ≥ `JUNK_MIN_SEEDS`, 1    |
| **A, junk-id**     | the name is *nothing but* a random hex id (`0a1b2c3d4e5f`)                                             | `JUNK_STALE_DAYS`, 30d    | ≥ `JUNK_ID_MIN_SEEDS`, 0 |
| **B, size**        | a giant: over `ABS_SIZE_FLOOR_MB` (500M) *and* in the top `REL_PCTL`% by size (P95)                    | `OUTLIER_STALE_DAYS`, 90d | ≥ `MIN_OTHER_SEEDS`, 3   |
| **C, stale**       | nothing in particular; the catch-all for whatever the other rules missed                               | `STALE_YEARS_DAYS`, 730d  | ≥ `MIN_OTHER_SEEDS`, 3   |
| **D, spam-batch**  | one of a batch stamped out from one template ([more](#rule-d-spam-batches))                            | `SPAM_STALE_DAYS`, 7d     | ≥ `SPAM_MIN_SEEDS`, 0    |
| **E, link-farm**   | published to carry links rather than code ([more](#rule-e-link-farms))                                 | `LINK_STALE_DAYS`, 7d     | ≥ `LINK_MIN_SEEDS`, 0    |
| **F, media-dump**  | video, images or audio with no project around them ([more](#rule-f-media-dumps))                       | `MEDIA_STALE_DAYS`, 7d    | ≥ `MEDIA_MIN_SEEDS`, 0   |
| **F, media-batch** | the same media files, published across many repos ([more](#rule-f-media-dumps))                        | `MEDIA_STALE_DAYS`, 7d    | ≥ `MEDIA_MIN_SEEDS`, 0   |

Rule G is missing from the table because it judges a **peer**, not a repo, and prunes nothing: it names peers who use repos they do not own as file hosting of their own, and prints the `rad block` line for each such peer ([more](#rule-g-parasite-peers)).

#### How age is measured

A, B and C measure **last activity**. Activity is any signed change, however small: a commit, an issue, a comment, a reaction, a label. The tool uses the newest `creatordate` across every peer's refs.

D, E and F measure **creation** instead, because spam that comments on its own repos would reset a last-activity clock. Creation is the older of the repo's oldest ref date and the day this seed first saw it (`$RAD_HOME/prune-audit/first-seen.tsv`, appended on every run, dry or not). A pusher controls the first date and cannot reach the second.

#### Verdicts that may delete the last copy we know of

`junk-id`, `spam-batch`, `link-farm`, `media-dump` and `media-batch`, which default to a seed floor of `0`. "Other seeds" counts the nodes our routing table says announce a repo, not proof a copy exists elsewhere; these verdicts are why pruning [quarantines instead of deleting](#quarantine). `JUNK_ID_MIN_SEEDS=1 SPAM_MIN_SEEDS=1 LINK_MIN_SEEDS=1 MEDIA_MIN_SEEDS=1` restores a floor of 1 for these. `denied` and `denied-copy` have no seed floor and no setting for one.

#### Names that count as disposable

`test`, `tmp`, `temp`, `scratch`, `playground`, `sandbox`, `demo`, `dummy`, `wip`, `trash`, `junk`, `old`, `throwaway`, `helloworld`, as whole words delimited by `-`, `_`, `.` or the ends of the name; plus `foo` / `bar` / `baz`, but only as an entire name. A space is not a delimiter: `test-old` matches, `The old man` does not. A name that is *nothing but* a random hex id of `JUNK_ID_MIN_LEN`+ characters counts too (`0a1b2c3d4e5f`); both a letter and a digit are required, so `12345678` and `facade` do not.

### Disk pressure

The thresholds above are the **relaxed** values. As free disk falls, pressure `p` rises from `0` to `1` linearly between a relax watermark (`max(PRESSURE_RELAX_PCT%, PRESSURE_RELAX_GB)` free) and a critical one (`min(PRESSURE_CRIT_PCT%, PRESSURE_CRIT_GB)` free), and every knob is interpolated from its relaxed value toward an aggressive one. With the relax watermark at or below the critical one, `p` is `0` above the critical watermark and `1` at or under it:

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

**Hard floors never scale.** `MIN_OTHER_SEEDS` bottoms out at 1, every exclusion holds at any pressure, and none of rule E's thresholds move with pressure at all. `DISK_AWARE=0` turns the scaling off entirely, so every knob keeps its relaxed value, and a disk at the critical watermark does not empty the quarantine.

## Safety and recovery

- **Dry run by default.** Nothing is pruned, and nothing on the deny list is blocked, without `--apply`. A peer that rule G named is blocked only under `--block-peers`.
- **Quarantine instead of deletion.** A pruned repo stays on disk for `QUARANTINE_DAYS` (7) and is restorable with one command ([details](#quarantine)).
- **Minimum seed counts** keep the last copy we know of, except for the [deny list](#deny-list) and [copies of denied files](#copies-of-denied-files), and under `junk-id`, `spam-batch`, `link-farm` and rule F's two media verdicts ([why](#verdicts-that-may-delete-the-last-copy-we-know-of)).
- **Runaway caps** (`MAX_PRUNE_COUNT`, `MAX_PRUNE_GB`) abort a plan whose rules picked more than either cap; repos on the deny list are not counted, [copies of denied files](#copies-of-denied-files) are. Two things get past them: `--force`, or a person answering `y` at the prompt, which is a human signing off on the numbers just printed. `--yes` is not one of them, so an unattended run still stops.
- **A rule that jumps is held back.** An unattended run compares each rule's part of the plan with the median that rule pruned over the last `RATCHET_RUNS` (8) applied runs. A rule that plans more than `RATCHET_FACTOR` (3) times its median, and more than `RATCHET_FLOOR` (20) repos, is held back. Its repos stay in storage, the other rules go ahead, and the run exits 4. A dry run lists what would be held, and every run writes it to `last-run/held.tsv`. `--force` or a `y` at the prompt gets past it. The median comes from the audit logs `history.log` names. A run that held a rule back, or ran without it, does not count for that rule. A rule with fewer than 3 runs that count has `RATCHET_FLOOR` as its limit, and with fewer than 3 readable logs nothing is held. The spam, link-farm and media rules usually prune nothing, so a sudden batch of more than 20 repos from one of them waits for `--force` or a `y`.
- **A stopped run deletes nothing from quarantine.** A run the runaway caps stop, or an `n` at the prompt, leaves expired repos there ([more](#quarantine)).
- **Freshness guard** skips any repo whose storage directory was written within `FRESH_GUARD_DAYS` (2), which is what a fetch still arriving looks like. The [deny list](#deny-list) and [copies of denied files](#copies-of-denied-files) do not wait for it.
- **Preflight** aborts any run if the node is down or `rad ls` fails, and an `--apply` also if exclusions cannot be read.
- **Blind scans abort.** More than `MAX_SCAN_FAIL_PCT` (10%) of the repos in storage missed is exit 5, not a small plausible plan. Three ways to miss one, counted together: it vanished mid-scan, reading it failed, or its refs would not list, which leaves it ageless and outside every rule.
- **Blocking a peer that rule G named needs two opt-ins:** `--block-peers`, and then a `y` to the prompt it raises for that peer. Without `--block-peers` the run only prints the `rad block` line for each peer rule G named. An unattended run has nobody to give the second opt-in, so it blocks nobody unless `--yes` gives it ([more](#rule-g-parasite-peers)).
- **Audit log** records every prune and every block, with the evidence behind it.

For each selected repo, in this order:

```sh
rad unseed <rid>                              # drop whatever single seeding policy the repo has
rad block  <rid>                              # set an explicit block, so default-allow won't re-fetch it
mv <storage>/<rid> <audit>/quarantine/<rid>   # out of storage, still on disk
```

`rad unseed` must run **before** `rad block`, because unseeding clears whatever policy row the repo has, block included, and a repo with no policy row re-seeds under the default-allow scope.

### Quarantine

A pruned repo moves to `$AUDIT_DIR/quarantine/<rid>` instead of being deleted. Once it has been there `QUARANTINE_DAYS` (7) days, the next `--apply` run that gets past the caps and the prompt deletes it for real, even if that run prunes nothing itself or holds every rule back. A run the caps stop, or an `n` at the prompt, deletes nothing from the quarantine. At the critical disk watermark, an `--apply` run that gets past the caps and the prompt empties the whole quarantine, however recent each entry is. `QUARANTINE=0` deletes outright and keeps nothing.

Every repo was unseeded and blocked before it was moved there, so nothing on the node points at the quarantine: deleting the directory by hand (`rm -rf`) is safe at any time and only costs the ability to restore.

```sh
rad prune quarantine list             # what is held, and for how long
rad prune quarantine restore <rid>    # put it back in storage and re-seed it
rad prune quarantine delete <rid>     # or --all: delete now, for good
rad prune quarantine purge            # delete whatever is past its window
rad prune quarantine files <rid>      # its images, video, audio and archives, as deny-files.tsv rows
```

`restore` moves the repo back into storage, clears the block, re-seeds it, and adds it to the keep list, `$AUDIT_DIR/keep.txt`, so the next run leaves it alone. The keep list is one repo id per line, editable by hand; repos listed there are excluded from every rule.

### Undoing a prune

Within the quarantine window:

```sh
rad prune quarantine restore <rid>
```

After the window the local copy is gone; the repo is re-fetchable from the network as long as other nodes still hold it (what the minimum seed counts are for). Two commands, in this order:

```sh
rad unseed rad:<rid>
rad seed  rad:<rid>
```

`rad seed` on its own is not enough: it only rewrites an existing policy row's scope, so a blocked repo stays blocked and the fetch is refused, even though the CLI prints a success line. `rad unseed` deletes that row whatever policy it holds, which is what drops the block. Newer heartwood also has `rad unblock`; `rad unseed` is used here because it works on every version and the `rad seed` that follows puts the seeding row back either way.

```sh
# every repo a given run removed, from that run's audit log
awk -F'\t' '!/^#/ && $1 !~ /^blocked-/ {print "rad:"$1}' \
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
| A    | `JUNK_ID_MIN_SEEDS`   | `0`       | Other seeds for the *random-id* branch; `0` may prune the last copy     |
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
| D    | `SPAM_MIN_SEEDS`      | `0`       | Other seeds required; `0` may prune the last copy we know of            |
| E    | `LINK_MIN_REPOS_PCT`  | `0.4`     | Share of storage that must link to a host before it can be a spam host  |
| E    | `LINK_MIN_REPOS`      | `8`       | Absolute floor under that share                                         |
| E    | `LINK_CODE_MAX_PCT`   | `10`      | Share of a host's linkers that may link from their own code             |
| E    | `LINK_REPO_BUDGET`    | `8000000` | Bytes read per repo, per pass                                          |
| E    | `LINK_MIN_SCORE`      | `5`       | Spam domains a repo must link to before it is flagged                   |
| E    | `LINK_DELEGATE_CHECK` | `1`       | Count only links from the repo's own delegates (`0` is faster, unsafe)  |
| E    | `LINK_STALE_DAYS`     | `7`       | Age since creation                                                      |
| E    | `LINK_MIN_SEEDS`      | `0`       | Other seeds required; `0` may prune the last copy we know of            |
| F    | `MEDIA_MIN_BYTES`     | `65536`   | Media bytes below which a repo is not worth judging                     |
| F    | `MEDIA_TEXT_MAX_BYTES`| `2048`    | Everything that is not media, added up, must stay under this            |
| F    | `MEDIA_STALE_DAYS`    | `7`       | Age since creation                                                      |
| F    | `MEDIA_MIN_SEEDS`     | `0`       | Other seeds required; `0` may prune the last copy we know of            |
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
| `RATCHET_FACTOR`    | `3`     | Hold back a rule that plans over this multiple of its recent median |
| `RATCHET_RUNS`      | `8`     | Applied runs the median is taken over; under 3 holds nothing back   |
| `RATCHET_FLOOR`     | `20`    | A rule planning this many repos or fewer is never held back         |
| `MAX_SCAN_FAIL_PCT` | `10`    | Abort if more than this share of storage was vanished, unreadable or ageless |

**Quarantine and plan output**

| Variable             | Default | Meaning                                                                    |
| -------------------- | ------- | -------------------------------------------------------------------------- |
| `QUARANTINE`         | `1`     | Quarantine pruned repos instead of deleting (`0` deletes, with no way back) |
| `QUARANTINE_DAYS`    | `7`     | Days a quarantined repo stays recoverable before a later run purges it     |
| `KEEP_FILE`          | `$AUDIT_DIR/keep.txt` | Repos excluded from every rule, one id per line; `quarantine restore` appends to it |
| `CACHE`              | `1`     | Reuse what rules E, F and G, and the check for copies, read out of repos that have not changed (`0` reads everything, every run) |
| `CACHE_DIR`          | `$AUDIT_DIR/cache` | Where that reading is kept                                      |
| `PLAN_COLLAPSE_ROWS` | `20`    | Group size at which a corpus verdict folds to one summary line             |
| `PLAN_FULL`          | `0`     | `1` lists every plan row and every evidence table entry, untruncated       |
| `NEAR_PCT`           | `20`    | A row's `NEAR` column names any threshold it cleared by less than this share of the threshold; `0` marks nothing |
| `PROGRESS_SECS`      | `60`    | Seconds between progress lines when the output is not a terminal; `0` turns off all progress reporting ([what it looks like](#progress)) |

**Disk pressure** ([what it does](#disk-pressure))

| Variable                                   | Default     | Meaning                                          |
| ------------------------------------------ | ----------- | ------------------------------------------------ |
| `DISK_AWARE`                               | `1`         | Scale thresholds with free disk (`0` to disable) |
| `PRESSURE_RELAX_PCT` / `PRESSURE_RELAX_GB` | `20` / `20` | Above this much free: no pressure                |
| `PRESSURE_CRIT_PCT` / `PRESSURE_CRIT_GB`   | `10` / `2`  | At/below `min()` of these: full pressure         |
| `*_AGG`, e.g. `STALE_YEARS_DAYS_AGG`       | per knob    | Full-pressure endpoint for each knob that scales (defaults in the script, next to the knob) |

```sh
# example: only chase the giants, leave everything else
ABS_SIZE_FLOOR_MB=1000 STALE_YEARS_DAYS=99999 rad prune
```

## Run it on a schedule

After a reviewed first run, a weekly cron keeps the seed trimmed; leaving out `--force` keeps the runaway caps and the hold on a rule that jumps active.

Cron runs with a minimal environment, so `HOME` and `PATH` have to be spelled out. Substitute the user your node runs as:

```cron
# /etc/cron.d/rad-prune  Sundays 04:17
SHELL=/bin/sh
17 4 * * 0 radicle HOME=/home/radicle PATH=/usr/local/bin:/usr/bin:/bin /usr/local/bin/rad-prune --apply >> /home/radicle/.radicle/prune-audit/cron.log 2>&1
```

Point `RAD_HOME` at the node's home instead if it does not live at `$HOME/.radicle`.

To have the same job act on rule G as well, add `--block-peers --yes`. That blocks every peer the rule names, with nobody reviewing it, so only do it once you have watched a few runs name nobody.

## Audit trail

Anything this tool does is written to `$RAD_HOME/prune-audit/` (default `~/.radicle/prune-audit/`). A dry run writes the last run's evidence, the creation-date ledger and the scan cache; the rest is written only by a run that acts:

- **`prune-<UTC-timestamp>.log`**: one file per acting run: every repo removed, tab-separated (rid, size, other-seed count, last activity, reason, name, the date the matching rule measured, any threshold that repo only just cleared), plus peer blocks made under `--block-peers` with the evidence behind each.
- **`quarantine/<rid>`**: every pruned repo, held for `QUARANTINE_DAYS` ([more](#quarantine)).
- **`keep.txt`**: repos excluded from every rule, one id per line, editable by hand; `quarantine restore` appends to it.
- **`deny.txt`**: repos and identities to prune and block on sight ([more](#deny-list)). The tool only reads it. The audit log names the entry each repo was pruned for on a `# denied:` line, and records each new block of an identity, or of a repo not yet fetched, on a `blocked-denied` line.
- **`deny-files.tsv`**: files whose copies are pruned too ([more](#copies-of-denied-files)). The tool only reads it. The audit log says how much of each copy was listed files, and from which source, on a `# denied-copy:` line.
- **`cache/`**: what rules E, F and G, and the check for copies, last read out of each repo. Safe to delete at any time; the next run reads everything again.
- **`history.log`**: append-only, one line per applied run: timestamp, repos pruned, GiB moved out of storage, whether the quarantine was on, disk pressure, and the run's audit log. An unattended run reads the audit logs named here to learn what each rule usually prunes.
- **`cron.log`**: with the cron recipe above, the full console output of every run.
- **`first-seen.tsv`**: the creation-date ledger rules D, E and F read. Written on every run, dry or not.
- **`last-run/`**: what the last run decided and what it decided it on, untrimmed and tab-separated, whether or not that run acted. The terminal folds repetitive rows and cuts each evidence table to its top few; these files hold all of it, for reading later or piping elsewhere. Every file opens with the same line naming the run that wrote it (time, version, dry or applying, rules, storage path), because a plan is only readable next to the rules it was made under. Replaced whole by the next run that gets far enough to write them: a run that aborts earlier leaves the previous run's files, which is what the stamp is for.
  - `plan.tsv`: every repo the run planned to prune, one row each, same columns as the audit log above. It is the plan, not the outcome; what an applying run actually removed is in that run's `prune-*.log`.
  - `spam-batches.tsv`: every rule D template, with how many repos matched it.
  - `spam-domains.tsv`: every domain rule E condemned, with how many repos link to it.
  - `media-review.tsv`: every dump rule F found and kept because no other node seeds it.
  - `imports.tsv`: every junk-named repo rule A kept because its history starts more than 14 days before its `rad init`.
  - `parasite-peers.tsv`: every peer rule G accused, with the evidence each accusation rests on.
  - `media-unjudged.tsv`: every repo rule F could not read, or gave up on for holding more than `MEDIA_MAX_REFS` refs. These are the repos its warning counts.
  - `denied.tsv`: every repo pruned for the deny list, with the entry that named it: `listed`, or `delegate` and the identity.
  - `denied-copies.tsv`: every copy of denied files in the plan: bytes of listed files, bytes on its delegates' branches and tags, the share, how many files, the source most of them came from, and how many other sources.
  - `denied-copy-files.tsv`: every listed file each of those copies holds, by object id, with its bytes.
  - `held.tsv`: every rule an unattended run would hold back for planning far more than usual, with its planned count, its usual and its limit. Its repos are still listed in `plan.tsv`, since `--force` or a yes would prune them.
  - `scan-errors.txt`: everything the run could not read.

```sh
tail ~/.radicle/prune-audit/history.log              # totals per run, newest last
cat  ~/.radicle/prune-audit/prune-2026*.log          # exact repos removed, with reasons
grep -v '^#' ~/.radicle/prune-audit/last-run/plan.tsv | cut -f5 | sort | uniq -c  # last plan, by reason
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
4. it has at least `MEDIA_MIN_SEEDS` (0) other seeds, so by default the seed count does not spare it.

What a file *is* decides, not what it is called. Extensions (`MEDIA_EXTS`, `MEDIA_TEXT_EXTS`, `MEDIA_TEXT_NAMES`) are only a fast path: an unrecognised file has its first 16 bytes matched against media signatures, so renaming a video to `.dat` does not hide it. Archives (zip, gzip, rar, 7z) count as media; a file matching no signature counts as text and spares the repo. Reading is capped at `MEDIA_SNIFF_MAX_FILES` (200) per repo, and files past the cap count as text.

Only the repo's own content counts: the canonical branches and tags, plus the namespaces of the delegates named in `refs/rad/id`, including every issue and patch comment a delegate signed, older ones too. Every other peer's namespace is ignored, and so is a stranger's patch or comment a delegate replied to, so a stranger pushing a video onto somebody's repo cannot put that repo in the plan. A repo with a branch whose commit is missing from storage is not judged.

A branch or tag is read at its tip, so media committed and then deleted in a later commit is missed. A repo whose listing dies part-way, or with more than `MEDIA_MAX_REFS` (10000) refs, is left unjudged.

A token README is enough to put a repo over the text budget above. The **batch path** reaches such a repo anyway: it is flagged `media-batch` when it meets conditions 1, 3 and 4 above, *and*:

- at least `MEDIA_MIN_BYTES` of its media sits in files that `MEDIA_MIN_BATCH` (5) or more repos in storage also hold, byte for byte, and that this repo was not the first to hold (first by the creation-date ledger);
- everything that is not media adds up to less than `MEDIA_TEXT_CEIL_BYTES` (64 KiB), the wider budget.

`MEDIA_MIN_SEEDS=1` raises the floor, and a dump no other node announces is then listed under `# review:` for a human to look at rather than pruned. At the default floor of `0` that list is empty and rule F may prune the last copy this seed knows of, like `spam-batch` and `link-farm` before it: the evidence is what the repo holds, and a dump nobody else seeds is still a dump.

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
tests/run.sh                 # everything
tests/run.sh -k quarantine   # only the sections that mention "quarantine"
```

Needs only `bash`, `git`, `openssl` and coreutils. It builds a hermetic fixture and runs the real script against it, so it never reads or writes the real node.

The suite is cut into sections, one per fixture rebuild, and a section run on its own is the same run it gets in the whole suite. Whole runs take minutes and a single section takes seconds, so `-k` is the loop to be in while changing one rule. It takes a regular expression and runs every section whose text contains a match, so a test name, a repo id, a knob name or a rule letter all select one. The fixture is built once and kept under `TMPDIR` for an hour; `RSP_FIXTURE_CACHE=0` builds it fresh every time.

See [`CONTRIBUTING.md`](./CONTRIBUTING.md) for where to report a repo the tool got wrong, what such a report needs to carry, and how to send a patch. See [`CHANGELOG.md`](./CHANGELOG.md) for release history.

## Support

If this kept your seed clean and saved you a few bucks on your VPS bill:

- 💛 Chip in on [Liberapay](https://liberapay.com/maninak/donate) with a micro-donation, if you can comfortably spare it.
- 🌱 Seed this repo on [Radicle](https://app.radicle.at/nodes/seed.radicle.at/rad:zxvTkxzouwrYFwycnsctrMT3iM2E) and ⭐ star it on [GitHub](https://github.com/maninak/radicle-seed-prune).
- 🗣️ Tell a fellow seed operator, and bring your ideas and the edge cases you hit to [#radicle-seed-prune on Zulip](https://radicle.zulipchat.com/#narrow/channel/624837-radicle-seed-prune).

## License

[Apache License 2.0](./LICENSE). Use it, fork it, vendor it.

Copyright (c) 2026 Konstantinos Maninakis ([maninak.com](https://maninak.com)).

---

[![A radicle.tools artifact — homegrown apps and tools for Radicle](https://radicle.tools/badge/artifact.svg)](https://radicle.tools)
