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
- **Moderates content**: prunes mass-generated spam and media dumps, and names peers who push their own files into repos they are not a delegate of.

Tuned against and running in production for seed.radicle.at seeding the whole public Radicle network. Read the plan before you apply anything.

## Install

```sh
src=$(mktemp -d)
rad clone rad:zxvTkxzouwrYFwycnsctrMT3iM2E "$src"
git -C "$src" fetch -q rad://zxvTkxzouwrYFwycnsctrMT3iM2E/z6MkvAFBkdph6yXSZDkkVqf9FfCcvkG29JD4KbwwnGphDRLV 'refs/tags/*:refs/tags/*'
tag=$(git -C "$src" tag --sort=-v:refname | head -1) \
  && git -C "$src" checkout -q "$tag" \
  && sudo install -m 755 "$src/rad-prune" /usr/local/bin/rad-prune
```

Cloning ensures you're installing the unaltered script as signed by the repo's delegate, at the latest release the delegate tagged. Re-run these same lines later to install a newer version.

Alternatively, fetch it over HTTPS and trust GitHub for the transfer:

```sh
curl -LO https://github.com/maninak/radicle-seed-prune/releases/latest/download/rad-prune
chmod +x rad-prune
sudo mv rad-prune /usr/local/bin/
```

### Requirements

- `bash`, `git`, `jq`, `rad`, `awk`, `sed`, `grep`, `find` and coreutils on `PATH`.
- For the media rule (F), `gzip` and OpenSSL 3. `openssl version` shows which OpenSSL you have; Debian 12, Ubuntu 22.04 and later ship 3.
- Optional: `flock` (util-linux), so that two runs cannot change storage or the quarantine at once. Without it, a run warns and goes ahead.
- Optional: `sqlite3`, to [automatically unprune](#blocks-the-tool-lifts-on-its-own) a repo pruned for inactivity once one of its delegates updates it again.

Run it as the user that owns the Radicle home you want pruned, or set `RAD_HOME` to that home.

## Usage

`rad` runs `rad-prune` from `PATH` as `rad prune`, so the examples below work either way.

```sh
rad prune                    # preview: print the plan, change nothing
rad prune --apply            # apply, asks [y/N] first when run in a terminal
rad prune --apply --yes      # answer the confirmation with y (scripts, cron)
rad prune --apply --force    # apply even past a runaway cap, or a rule planning far more than usual
rad prune --apply --restart-node  # ...and restart the node afterwards
rad prune --block-peers      # block what the parasite-peer rule (G) found, one [y/N] per peer; prunes nothing
rad prune quarantine ...     # list, restore, delete, purge quarantined repos
rad prune check              # which of your own public repos a seed would prune, and why
rad prune --version
```

There is no `--dry-run` flag. Running with no flags is the dry run. `--apply` scans once, prints that same plan, asks `[y/N]` in a terminal, and just applies when there is nobody to ask (cron, a pipe). `--yes` answers every prompt a run asks, including the per-peer block prompt.

`--block-peers` is its own action and does not imply `--apply`; pass both flags if you mean both actions. It asks once per peer before blocking that peer. `--block-peers --yes` answers those prompts with y, which is the form a cron job wants. `--block-peers` alone with nobody to ask (cron, a pipe) blocks nobody and prints the `rad block` commands instead.

The plan is sorted largest repo first and totals the disk the run would free. `--help` lists the options and the quarantine verbs, and prints the paths this run resolved.

Every setting is an environment variable, as with `rad` itself:

```sh
RAD_HOME=/var/lib/radicle rad prune          # a seed home that isn't yours
RAD=/nix/store/.../bin/rad rad-prune         # a specific rad binary
sudo -u <node-user> env RAD_HOME=/var/lib/radicle rad-prune   # as the user the node runs as
```

A run missing a command it needs names the command and stops. A systemd unit, a Nix wrapper or `sudo` (through its `secure_path`) can hand the run a `PATH` that lacks a command you have installed. To hand it your own `PATH`: `sudo -u <node-user> env PATH="$PATH" RAD_HOME=/var/lib/radicle rad-prune`.

### Example output

A dry run against a seed of 12,292 repos:

```
# radicle-seed-prune 0.8.0  2026-10-04T04:16:49Z   mode=DRY-RUN
# home=/var/lib/radicle  audit=/var/lib/radicle/prune-audit
# disk: 125.5GB free (46.5%)  pressure=0% [relax>=54GB crit<=2GB]
# rules: A junk(>30d, seeds>=1, spare-import>14d; id-names seeds>=0)  B size(>500MB & >=P95, >90d, seeds>=3) [WAITING: no disk pressure]  C stale(>730d, seeds>=3) [WAITING: no disk pressure]  D spam(batch>=5 & desc>=80%, >7d, seeds>=0)
# rule F media-dump(>=64KB of media and <2048B of anything else, no source or build file, >7d, seeds>=0)  media-ratio(>=6144KB of images+video+audio at the tips, anything else <1/1000 of that, no archive, nothing else at the tips but <=1 README)  media-batch(>=64KB of media held by >=5 repos, <65536B of anything else)
# rule G parasite-peer(one file of theirs in >=10 repos they are not a delegate of, >=1MB media, <16384B of anything else) [reports only; --block-peers asks per peer]
# rule H malware-op(>=3 malware words, one strong, in the names and descriptions of >=2 and >=50% of the repos an identity signed as a delegate; or one repo with a strong word in its name or description and in a file path or commit subject, first commit <=7d before its rad init) [reports only]
# excluded: 9 pinned, 6 private, 0 own, 0 kept; 0 identity(s) cleared of the malware rule (H)
# spam batches: 10 template(s) matching 999 repos, before the age and seed checks:
#     111  template-a-*-*
#     105  template-b-*-*
#     104  template-c-*-*
#     103  template-d-*-*
#     102  template-e-*-*
#   ...and 5 more (PLAN_FULL=1 lists them)
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
zEXAMPLEREPOjjjjjjjjjjjjjjj            8.9MB     22      191 media-dump    -               example-media-repo-9
[... 17 more single-repo rows ...]
zEXAMPLEREPOxxxxxxxxxxxxxxx          128.9KB      9       30 junk-name     age             example-demo-repo
zEXAMPLEREPOyyyyyyyyyyyyyyy           75.0KB     10       30 junk-name     age             example-hello-world
zEXAMPLEREPOwwwwwwwwwwwwwww           73.9KB     13       31 junk-name     age             example-test-2
(440 repos)                           50.8MB                 spam-batch    0 near          same pattern across many repos; PLAN_FULL=1 lists them
(23 repos)                             1.3GB                 media-batch   0 near          same pattern across many repos; PLAN_FULL=1 lists them

# PLAN: prune 492 repos, 2.08 GiB out of storage but still on disk for 7d, until a later --apply run deletes them
#   junk-name         6 repos      0.00 GiB
#   media-batch      23 repos      1.29 GiB
#   media-dump       23 repos      0.75 GiB
#   spam-batch      440 repos      0.05 GiB
#   8 of them cleared a threshold by under 20%: see the NEAR column, which names the threshold that was close. Read those rows first.
# the untrimmed plan and the evidence behind it: /var/lib/radicle/prune-audit/last-run/
# DRY-RUN: nothing in storage changed. Re-run with --apply to execute.
```

Corpus verdicts (`spam-batch`, `media-batch`) fold to one summary line per group at `PLAN_COLLAPSE_ROWS` (20) rows. Single-repo verdicts are always listed in full, and `PLAN_FULL=1` lists everything. The evidence tables above the plan (spam templates, scan errors, and any media dumps a raised `MEDIA_MIN_SEEDS` kept) show their top few entries and say how many they left out; `PLAN_FULL=1` prints those whole too.

`AGE(d)` is the age the matching rule measured: days since last activity for the junk-name (A), size (B) and stale (C) rules, days since creation for the spam-batch (D) and media (F) rules.

`NEAR` names any threshold the row cleared by less than `NEAR_PCT` (20%), and is `-` when the row cleared every one of them comfortably. It reports the numbers the matching rule tested: `age` for every rule, `seeds` where the rule has a seed floor above zero, plus `import` on `junk-name` rows, `size` for the size rule (B) and `media` for the media rule (F). For copies of denied files it reports only `bytes` and `share`. Rows whose `NEAR` is not `-` are the ones to read first, and the summary under the plan counts them. `NEAR_PCT=0` marks nothing.

The plan goes to stdout and everything else, progress included, to stderr, so `> plan.txt` keeps them apart.

### Exit codes

| Code | Meaning                                                                                                                                |
| ---- | -------------------------------------------------------------------------------------------------------------------------------------- |
| `0`  | Success, including a dry run, an `--apply` you declined at the prompt, and a `check` that flagged nothing                              |
| `1`  | Something went wrong, such as a missing command, a directory it cannot read or write, or a repo it could not remove. The run says what |
| `2`  | Bad argument, or a setting with a bad value (the run names it)                                                                         |
| `3`  | The plan tripped a runaway cap; nothing was pruned. Read it, then re-run with `--force`                                                |
| `4`  | A rule planned far more than usual, so its repos were held back; the other repos in the plan were pruned. Read it, then `--force`      |
| `5`  | Refused to run: it could not read enough of the node, the disk, storage or `keep.txt` to trust a plan, or another `--apply`, `--block-peers` or quarantine run holds the lock. The run says what, and nothing was touched |
| `6`  | `check` found a repo of yours that a seed running rad-prune would prune                                                                |

## Checking your own repos

`rad prune check` lists which of your public repos a seed running rad-prune would prune, why, and what to change. It changes nothing, and exits `6` when a seed would prune at least one.

```text
$ rad prune check
# 2 public repo(s) of yours, judged by the media (F) and spam-batch (D) rules as a seed would judge them once old enough
would-prune  example-clips  rad:z<rid>  as media-dump
  It holds images, video, audio or archives, no source or build file, and under 2048 bytes of anything else.
  Fix: add what the media belongs to, such as its source, its build files or pages that use it, or host the media elsewhere and link to it.
  Biggest files on its branches and tags. The media rule (F) also counts the delegates' issue and patch attachments and the other delegates' branches, not listed here:
       48.0 MiB  main  assets/intro.mp4
ok           example-project  rad:z<rid>
# Not checked: the junk-name (A), size (B), stale (C), parasite-peer (G) and malware (H) rules, ...
```

It judges every public repo on this node that you are a delegate of, however new, so you can run it as soon as you publish one.

## What gets pruned

A repo is pruned when a [rule](#rules) matches it, the [deny list](#deny-list) names it or one of its delegates, or it holds [copies of denied files](#copies-of-denied-files). Pinned, private and your own repos, and repos in `keep.txt`, are never pruned, and the rules also pass over the other [exclusions](#exclusions-never-touched-by-a-rule).

### Exclusions (never touched by a rule)

| Exclusion       | Source                                                |
| --------------- | ----------------------------------------------------- |
| Pinned repos    | `config.web.pinned.repositories`                      |
| Private repos   | `rad ls --private`, or a private identity document    |
| Your own repos  | `rad ls`, or this node's signed refs in the repo      |
| Kept repos      | `$AUDIT_DIR/keep.txt`, one repo id per line ([more](#quarantine)), or a `did:key:` identity, which only the malware rule (H) reads |
| Freshly written | storage dir modified within `FRESH_GUARD_DAYS`        |
| Unknown age     | no readable refs (also counted against `MAX_SCAN_FAIL_PCT`) |
| Unreadable      | hit an error when reading the repo                    |

### Deny list

Repos and identities you, or someone you trust, have already judged go in `$AUDIT_DIR/deny.txt`, one per line, with or without the `rad:` or `did:key:` prefix. `#` starts a comment. A list another operator shared with you works as is. To use several, concatenate them into this one file.

```
rad:z<rid>          # a repo: pruned and blocked, even before it arrives
did:key:z6Mk<nid>   # an identity: blocked, and every repo it is a delegate of is pruned
```

`--apply` prunes and blocks as the lines above say, regardless of age, size, seed count or an unfinished fetch. An identity's patches or comments in a repo it is not a delegate of do not count. Pinned, private, your own and `keep.txt` repos are never pruned, and an identity that is a delegate of one of them is not blocked. Denied repos skip the runaway caps and the hold-back, but a run the caps stop acts on none of them.

Removing a line does not undo its blocks. Run `rad unblock <rid>` or `rad unblock <nid>`.

#### Copies of denied files

Files from a leak or a media dump can turn up again in other repos. List a pruned repo's files in `$AUDIT_DIR/deny-files.tsv`, and every run plans the repos that hold copies of them for pruning, as `denied-copy`. A pruned repo stays in the quarantine for `QUARANTINE_DAYS` (7), and while it is there the command below appends its media files to that list:

```sh
rad prune quarantine files <rid> >> ~/.radicle/prune-audit/deny-files.tsv
```

Each row is `<object id> <bytes or -> <source> [date]`, fields separated by spaces or tabs, and `#` starts a comment. A list another operator shared with you works as is, but its ids cannot be checked by reading them, so use one only from someone you trust.

A repo is a copy when its delegates' branches and tags, history included, hold at least 5 MiB of listed images, video, audio or archives, and those make up at least half of the bytes there. Files someone else pushed, or attached to an issue or patch, do not count. A row counts against every repo whose delegates committed that file, so list only files that are the denied repo's own.

A listed file that a repo here held before every repo it is listed from counts against no repo, since the file is likely that repo's own. "Before" compares when this seed first saw each repo (`first-seen.tsv`). The run names the file and that repo for you to check. If that repo is a copy after all, add it to `deny.txt`.

Copies are pruned like repos the deny list names by id, and no identity is blocked for one. Unlike those repos, copies count against the runaway caps and the hold-back. Rows whose source is in `keep.txt` are ignored.

### Rules

`RULES` selects which rules run. When it is not set, all of them run:

- **A, junk-name**: prunes a repo with a disposable or random name.
- **B, size**: prunes a giant that has gone quiet.
- **C, stale**: prunes a repo that has been quiet for a long time.
- **D, spam-batch**: prunes repos stamped out in a batch from one template.
- **F, media**: prunes video, images or audio with no project around them.
- **G, parasite-peer**: names peers who use repos they are not a delegate of as file hosting, and prunes nothing ([more](#rule-g-parasite-peers)).
- **H, malware**: names identities and single repos for a person to review, and prunes nothing ([more](#rule-h-malware-operations)).

The link-farm rule (E) is gone, and an `E` in `RULES` is ignored with a warning. The size (B) and stale (C) rules prune only under [disk pressure](#disk-pressure), and the run's header marks them `WAITING` until then. A repo that a rule left out of `RULES` would have matched falls through to the next rule.

Every rule that prunes has the same shape: **something about the repo**, *and* it is old enough, *and* enough other nodes still hold it. Defaults shown.

| Rule               | The repo looks like                                                                                    | Minimum age               | Other seeds              |
| ------------------ | ------------------------------------------------------------------------------------------------------ | ------------------------- | ------------------------ |
| **A, junk-name**   | a disposable *word* in the name (`test`, `tmp`, `old`, `demo`), unless its history starts more than 14 days before `rad init` | `JUNK_STALE_DAYS`, 30d    | ≥ `JUNK_MIN_SEEDS`, 1    |
| **A, junk-id**     | the name is *nothing but* a random hex id (`0a1b2c3d4e5f`)                                             | `JUNK_STALE_DAYS`, 30d    | ≥ `JUNK_ID_MIN_SEEDS`, 0 |
| **B, size**        | a giant: over `ABS_SIZE_FLOOR_MB` (500M) *and* in the top `REL_PCTL`% by size (P95)                    | `OUTLIER_STALE_DAYS`, 90d | ≥ `MIN_OTHER_SEEDS`, 3   |
| **C, stale**       | nothing in particular; the catch-all for whatever the other rules missed                               | `STALE_YEARS_DAYS`, 730d  | ≥ `MIN_OTHER_SEEDS`, 3   |
| **D, spam-batch**  | one of a batch stamped out from one template ([more](#rule-d-spam-batches))                            | `SPAM_STALE_DAYS`, 7d     | ≥ `SPAM_MIN_SEEDS`, 0    |
| **F, media-dump**  | video, images or audio with no project around them ([more](#rule-f-media-dumps))                       | `MEDIA_STALE_DAYS`, 7d    | ≥ `MEDIA_MIN_SEEDS`, 0   |
| **F, media-ratio** | a great deal of images, video or audio beside one short file ([more](#rule-f-media-dumps))             | `MEDIA_STALE_DAYS`, 7d    | ≥ `MEDIA_MIN_SEEDS`, 0   |
| **F, media-batch** | the same media files, published across many repos ([more](#rule-f-media-dumps))                        | `MEDIA_STALE_DAYS`, 7d    | ≥ `MEDIA_MIN_SEEDS`, 0   |

#### How age is measured

The junk-name (A), size (B) and stale (C) rules measure **last activity**. Activity is any signed change, however small: a commit, an issue, a comment, a reaction, a label. The tool uses the newest `creatordate` across every peer's refs.

The spam-batch (D) and media (F) rules measure **creation** instead, because spam that comments on its own repos would reset a last-activity clock. Creation is the older of the repo's oldest ref date and the day this seed first saw it (`$RAD_HOME/prune-audit/first-seen.tsv`, appended on every run, dry or not, but not by `check`). A pusher controls the first date and cannot reach the second.

#### Verdicts that may delete the last copy we know of

`junk-id`, `spam-batch`, `media-dump`, `media-ratio` and `media-batch`, which default to a seed floor of `0`. "Other seeds" counts the nodes our routing table says announce a repo, not proof a copy exists elsewhere; these verdicts are why pruning [quarantines instead of deleting](#quarantine). `JUNK_ID_MIN_SEEDS=1 SPAM_MIN_SEEDS=1 MEDIA_MIN_SEEDS=1` restores a floor of 1 for these. `denied` and `denied-copy` have no seed floor and no setting for one.

#### Names that count as disposable

`test`, `tmp`, `temp`, `scratch`, `playground`, `sandbox`, `demo`, `dummy`, `wip`, `trash`, `junk`, `old`, `throwaway`, `helloworld`, as whole words delimited by `-`, `_`, `.` or the ends of the name; plus `foo` / `bar` / `baz`, but only as an entire name. A space is not a delimiter: `test-old` matches, `The old man` does not. A name that is *nothing but* a random hex id of `JUNK_ID_MIN_LEN`+ characters counts too (`0a1b2c3d4e5f`); both a letter and a digit are required, so `12345678` and `facade` do not.

### Disk pressure

The thresholds above are the **relaxed** values. As free disk falls, pressure `p` rises from `0` to `1` linearly between two free-space thresholds: a relaxed one (`max(PRESSURE_RELAX_PCT%, PRESSURE_RELAX_GB)` free) and a critical one (`min(PRESSURE_CRIT_PCT%, PRESSURE_CRIT_GB)` free), and every knob is interpolated from its relaxed value toward an aggressive one:

| knob                 | relaxed (`p=0`) | aggressive (`p=1`) |
| -------------------- | --------------- | ------------------ |
| `STALE_YEARS_DAYS`   | 730             | 60                 |
| `OUTLIER_STALE_DAYS` | 90              | 14                 |
| `JUNK_STALE_DAYS`    | 30              | 7                  |
| `SPAM_STALE_DAYS`    | 7               | 1                  |
| `ABS_SIZE_FLOOR_MB`  | 500             | 50                 |
| `REL_PCTL`           | 95              | 50                 |
| `MIN_OTHER_SEEDS`    | 3               | 1                  |

The header prints the live pressure and the effective thresholds every run. Pressure is read once, at the start of a run, and counts the quarantine copies that run will purge as free. Anything else that fills the disk for a while (a cache, a log) makes that run prune as if storage had. A run warns when something other than storage and the quarantine took more than 10 GB of free space since the last run recorded in `history.log`, if that run is at most 8 days old. On one node, with every rule on and the size (B) and stale (C) rules pruning at any free space, pruning scaled from ~1.3k repos / 18 GiB at `p=0` to ~7.1k repos / 92 GiB at `p=1`.

**Hard floors never scale.** `MIN_OTHER_SEEDS` bottoms out at 1, and every exclusion holds at any pressure.

## Safety and recovery

- **Dry run by default.** Nothing is pruned, and nothing on the deny list is blocked, without `--apply`. A peer that the parasite-peer rule (G) named is blocked only under `--block-peers`.
- **Quarantine instead of deletion.** A pruned repo stays on disk for `QUARANTINE_DAYS` (7) and is restorable with one command ([details](#quarantine)).
- **Minimum seed counts** keep the last copy we know of, except for the [deny list](#deny-list) and [copies of denied files](#copies-of-denied-files), and under `junk-id`, `spam-batch` and the three verdicts of the media rule (F) ([why](#verdicts-that-may-delete-the-last-copy-we-know-of)).
- **Runaway caps** (`MAX_PRUNE_COUNT`, `MAX_PRUNE_GB`) abort a plan whose rules picked more than either cap; repos on the deny list are not counted, [copies of denied files](#copies-of-denied-files) are. Two things get past them: `--force`, or a person answering `y` at the prompt, which is a human signing off on the numbers just printed. `--yes` is not one of them, so an unattended run still stops.
- **A rule that suddenly plans far more repos than usual is held back.** An unattended run holds back a rule that plans more than `RATCHET_FACTOR` (3) times the median it pruned over its last `RATCHET_RUNS` (8) applied runs, and more than `RATCHET_FLOOR` (20) repos. Its repos stay in storage, the other rules go ahead, and the run exits 4. A dry run shows what would be held, and `--force` or a `y` at the prompt gets past it. The spam-batch (D) and media (F) rules usually prune nothing, so a sudden batch of more than 20 repos from one of them waits for `--force` or a `y`.
- **A stopped run deletes nothing from quarantine and lifts no block.** A run the runaway caps stop, or an `n` at the prompt, leaves expired repos there ([more](#quarantine)).
- **Freshness guard** skips any repo whose storage directory was written within `FRESH_GUARD_DAYS` (2), which is what a fetch still arriving looks like. The [deny list](#deny-list) and [copies of denied files](#copies-of-denied-files) do not wait for it.
- **Preflight** aborts any run if the node is down, `rad ls` fails, `config.json` cannot be read, or `keep.txt` exists but cannot be read, and an `--apply` also if the pinned repos cannot be read from `config.json`.
- **Blind scans abort.** More than `MAX_SCAN_FAIL_PCT` (10%) of the repos in storage missed is exit 5, not a small plausible plan. Three ways to miss one, counted together: it vanished mid-scan, reading it failed, or its refs would not list, which leaves it ageless and outside every rule.
- **Blocking a peer that the parasite-peer rule (G) named needs two opt-ins:** `--block-peers`, and then a `y` to the prompt it raises for that peer. Without `--block-peers` the run only prints the `rad block` line for each such peer. An unattended run has nobody to give the second opt-in, so it blocks nobody unless `--yes` gives it ([more](#rule-g-parasite-peers)).
- **The tool lifts only blocks it made**, at most once per repo ([more](#blocks-the-tool-lifts-on-its-own)).
- **One run at a time.** An `--apply`, `--block-peers` or quarantine `restore`, `delete` or `purge` stops with exit 5 while another holds the audit directory's lock. Without `flock` on `PATH`, the run warns and goes ahead.
- **Audit log** records every prune, every block and every lifted block, with the evidence behind it.

For each selected repo, in this order:

```sh
rad unseed <rid>                              # drop whatever single seeding policy the repo has
rad block  <rid>                              # set an explicit block, so default-allow won't re-fetch it
mv <storage>/<rid> <audit>/quarantine/<rid>   # out of storage, still on disk
```

`rad unseed` must run **before** `rad block`, because unseeding clears whatever policy row the repo has, block included, and a repo with no policy row re-seeds under the default-allow scope.

### Quarantine

A pruned repo moves to `$AUDIT_DIR/quarantine/<rid>` instead of being deleted. Once `QUARANTINE_DAYS` (7) days have passed since the prune, the next `--apply` run that goes ahead (past the runaway caps and the prompt) deletes it for good, even if that run prunes nothing itself, so a weekly cron deletes it on its next run. At or under the critical free-space threshold, an `--apply` run that goes ahead empties the whole quarantine. No `--apply` run or `quarantine purge` deletes a repo listed in `keep.txt` from the quarantine, even at the critical threshold, and when rad-prune made its block, the next `--apply` run [brings it back](#blocks-the-tool-lifts-on-its-own). `QUARANTINE=0` deletes outright and keeps nothing.

Every repo was unseeded and blocked before it was moved there, so nothing on the node points at the quarantine. Deleting the directory by hand (`rm -rf`) is safe at any time and only costs the ability to restore.

```sh
rad prune quarantine list             # what is held, and for how long
rad prune quarantine restore <rid>    # put it back in storage and re-seed it
rad prune quarantine delete <rid>     # or --all: delete now, for good
rad prune quarantine purge            # delete whatever is past its window
rad prune quarantine files <rid>      # its images, video, audio and archives, as deny-files.tsv rows
```

`restore` moves the repo back into storage, clears the block, re-seeds it, and adds it to the keep list, `$AUDIT_DIR/keep.txt`, so the next run leaves it alone. Its line there says when it was restored and what it was pruned as. The keep list is one repo id per line, editable by hand. No rule and no deny list prunes a repo listed there, the malware rule (H) names none of its delegates, and while it is in the quarantine, an `--apply` run lifts the block rad-prune made on it and seeds it again. A `did:key:` line there only stops the [malware rule (H)](#rule-h-malware-operations) naming that identity and the repos it signed.

### Undoing a prune

Within the quarantine window:

```sh
rad prune quarantine restore <rid>
```

After the window the local copy is gone; the repo is re-fetchable from the network as long as other nodes still hold it (what the minimum seed counts are for). Two commands, in this order:

```sh
rad unseed <rid>
rad seed  <rid>
```

`rad seed` on its own is not enough. It only rewrites an existing policy row's scope, so a blocked repo stays blocked and the fetch is refused, even though the CLI prints a success line. `rad unseed` deletes that row whatever policy it holds, which is what drops the block. Newer heartwood also has `rad unblock`; `rad unseed` is used here because it works on every version and the `rad seed` that follows puts the seeding row back either way.

```sh
# every repo a given run removed, from that run's audit log
awk -F'\t' '!/^#/ && $1 !~ /^blocked-/ {print "rad:"$1}' \
  ~/.radicle/prune-audit/prune-20260628T183150Z.log |
  while read -r rid; do rad unseed "$rid" && rad seed "$rid"; done
```

The node keeps running during a prune. After a large first run, `sudo systemctl restart radicle-node` clears the stale "inventory announce limit" warning; `--restart-node` runs that restart for you, if the run has the rights to restart the service. On some heartwood versions `rad node inventory` still lists removed RIDs afterwards. That listing is cosmetic, and the repos are gone.

### Blocks the tool lifts on its own

An `--apply` run lifts a block rad-prune made when:

- A later rad-prune release withdrew the verdict that pruned the repo (`UNDO_CHANGED` in the script). For the size (B) and stale (C) rules, that holds only while they wait for disk pressure. A deleted repo bigger than the size limit in that entry stays blocked.
- One of the repo's delegates announced new refs for it after it was pruned for inactivity (`junk-name`, `junk-id`, `size-outlier`, `stale`). If the audit log of the run that last pruned the repo recorded no delegates for it, any node announcing refs of its own counts. A node `deny.txt` names never counts. Needs `sqlite3`. This node forgets announcements after two weeks by default, so a run more than two weeks after the one before can miss some.
- The verdict that pruned the repo is a known mistake (`UNDO_PARDON` or `UNDO_LIFT` in the script). The media rule (F) also spares a repo `UNDO_PARDON` lists.
- The repo is still in the quarantine and is in `keep.txt`. rad-prune also seeds it again, and this lift does not count against `UNDO_MAX_COUNT` or `UNDO_MAX_GB`.
- rad-prune blocked the repo but could not remove it, and the repo is now kept, pinned, private or your own, or a later release withdrew its verdict or lists it as a known mistake. It stays in storage, so this lift ignores the limits below and the critical free-space threshold.

A repo still in the quarantine goes back into storage, and a later run judges it. A deleted one is judged once this node fetches it again. Unless the repo is in `keep.txt`, rad-prune seeds neither. Under a default seeding policy of `allow`, the node seeds both and fetches a deleted one by itself. Under any other policy, run `rad seed` on each repo named on a `# unblocked:` line in the run's audit log.

A run lifts a block at most once per repo, and never one the audit log records as blocked before the prune. Unless the repo is in `keep.txt`, it also never lifts the block on a repo:

- that the deny list pruned, or that `deny.txt` names by its id;
- one of whose delegates `deny.txt` names, when the audit log or the quarantined copy names the delegates;
- that is pinned, private or your own, unless a failed removal left it in storage.

A run lifts the block on at most `UNDO_MAX_COUNT` (200) deleted repos, and `UNDO_MAX_GB` (10) GiB of them as measured when they were pruned. A withdrawn size (B) or stale (C) verdict is lifted only while the disk stays at or above the relaxed free-space threshold once every repo this run brings back is counted, along with any lifted in the last 14 days that this node is still due to fetch. While free space is at or under the critical threshold ([more](#disk-pressure)), it lifts none. `last-run/unprune-plan.tsv` lists each block a run plans to lift, and why. `UNDO=0` turns the lifting off.

## Speed

The media (F) and parasite-peer (G) rules read the contents of every repo, which is most of a run. Almost nothing changes from one weekly run to the next, so what those two rules and the search for copies of denied files read is kept in `$AUDIT_DIR/cache`. A repo is reused from the cache when both its refs and its size on disk are identical to what the run that wrote that entry saw; if either has moved, the repo is read again.

On a seed of 13,181 repos on six cores, a first run takes about 10 minutes and the next one under 2.5 minutes, reusing all but 4 repos.

The whole cache is dropped whenever the script file changes, or any of the settings below changes value, so a threshold you have just tuned never leaves last week's verdicts standing. The settings that only act on a plan already made keep the cache: `MAX_PRUNE_*`, `MAX_SCAN_FAIL_PCT`, `RATCHET_*`, `UNDO*`, `QUARANTINE*` and `NEAR_PCT`. `CACHE=0` reads every repo on every run; deleting the cache directory forces one full re-read, after which caching resumes.

## Configuration

Every setting is an environment variable. Defaults shown.

**Which rules run**

| Variable | Default   | Meaning                                                                                       |
| -------- | --------- | --------------------------------------------------------------------------------------------- |
| `RULES`  | `ABCDFGH` | The rules that run; a letter absent from it means that rule neither scans nor plans anything |

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
| F    | `MEDIA_MIN_BYTES`     | `65536`   | Media bytes below which a repo is not worth judging                     |
| F    | `MEDIA_TEXT_MAX_BYTES`| `2048`    | Everything that is not media, added up, must stay under this            |
| F    | `MEDIA_STALE_DAYS`    | `7`       | Age since creation                                                      |
| F    | `MEDIA_MIN_SEEDS`     | `0`       | Other seeds required; `0` may prune the last copy we know of            |
| F    | `MEDIA_MIN_BATCH`     | `5`       | Repos holding one media file, byte for byte, to call it a campaign      |
| F    | `MEDIA_TEXT_CEIL_BYTES`| `65536`  | The batch path's wider budget for everything that is not media          |
| F    | `MEDIA_RATIO_MIN_BYTES`| `6291456` | Images, video and audio the ratio path needs (6 MiB); `999999999999` turns it off |
| F    | `MEDIA_MAX_REFS`      | `10000`   | Refs above which a repo is too costly to read, so it goes unjudged      |
| F    | `MEDIA_MAX_OPS`       | `20000`   | Issue and patch ops above which a repo goes unjudged, a patch's own commits included |
| F    | `MEDIA_EXTS`          | images, video, audio, archives | `\|`-separated extensions judged as media; one you add counts as image, video or audio, never as an archive, on the ratio path |
| G    | `PARASITE_MIN_REPOS`  | `10`      | Non-delegated repos one file of a peer's must reach, byte for byte      |
| G    | `PARASITE_MIN_BYTES`  | `1048576` | Media bytes required across those repos (1 MiB)                         |
| G    | `PARASITE_TEXT_MAX_BYTES` | `16384` | Text budget anywhere in storage; a peer who writes is a contributor   |
| H    | `MALWARE_STRONG_WORDS` | `hvnc\|stealer\|...` | Lower-case, `\|`-separated words, one of which an identity's repos, or a single repo, must use |
| H    | `MALWARE_WEAK_WORDS`  | `c2\|payload\|...` | Lower-case, `\|`-separated words that count towards the 3 different words the malware rule (H) needs |

`MEDIA_EXTS` shapes rather than fires. Everything else the content rules use to classify is a constant in the script, next to the comment saying why it has that value.

**Brakes**

| Variable            | Default | Meaning                                                                                                                                                     |
| ------------------- | ------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `FRESH_GUARD_DAYS`  | `2`     | Skip repos written this recently (an in-flight fetch)                                                                                                       |
| `MAX_PRUNE_COUNT`   | `1000`  | Runaway guard: abort over this many repos                                                                                                                   |
| `MAX_PRUNE_GB`      | `80`    | Runaway guard: abort over this many whole GiB                                                                                                               |
| `RATCHET_FACTOR`    | `3`     | Hold back a rule that plans over this multiple of its recent median                                                                                         |
| `RATCHET_RUNS`      | `8`     | A rule's median is taken over its last this many applied runs in which it could prune. With fewer than 3 readable logs, or a value under 3, nothing is held |
| `RATCHET_FLOOR`     | `20`    | A rule planning this many repos or fewer is never held back                                                                                                 |
| `MAX_SCAN_FAIL_PCT` | `10`    | Abort if more than this share of storage was vanished, unreadable or ageless                                                                                |

**Undo** ([what it does](#blocks-the-tool-lifts-on-its-own))

| Variable         | Default | Meaning                                                                        |
| ---------------- | ------- | ------------------------------------------------------------------------------ |
| `UNDO`           | `1`     | Lift the block on repos rad-prune may have pruned by mistake (`0` turns it off) |
| `UNDO_MAX_COUNT` | `200`   | Most deleted repos unblocked per run                                           |
| `UNDO_MAX_GB`    | `10`    | Most GiB of deleted repos unblocked per run, measured when they were pruned    |

**Quarantine and plan output**

| Variable             | Default | Meaning                                                                    |
| -------------------- | ------- | -------------------------------------------------------------------------- |
| `QUARANTINE`         | `1`     | Quarantine pruned repos instead of deleting (`0` deletes, with no way back) |
| `QUARANTINE_DAYS`    | `7`     | Days a quarantined repo stays recoverable before a later run purges it     |
| `KEEP_FILE`          | `$AUDIT_DIR/keep.txt` | Repos never pruned, one id per line, whose block an `--apply` run lifts while they are in the quarantine ([more](#blocks-the-tool-lifts-on-its-own)), or a `did:key:` identity, which only the malware rule (H) reads; `quarantine restore` appends to it |
| `CACHE`              | `1`     | Reuse what the media (F) and parasite-peer (G) rules, and the search for copies of denied files, read out of repos that have not changed (`0` reads everything, every run) |
| `CACHE_DIR`          | `$AUDIT_DIR/cache` | Where that reading is kept                                      |
| `PLAN_COLLAPSE_ROWS` | `20`    | Group size at which a corpus verdict folds to one summary line             |
| `PLAN_FULL`          | `0`     | `1` lists every plan row and every evidence table entry, untruncated       |
| `NEAR_PCT`           | `20`    | A row's `NEAR` column names any threshold it cleared by less than this share of the threshold; `0` marks nothing |
| `PROGRESS_SECS`      | `60`    | Seconds between progress lines when the output is not a terminal (cron, a log file); `0` turns off all progress reporting |

**Disk pressure** ([what it does](#disk-pressure))

| Variable                                   | Default     | Meaning                                          |
| ------------------------------------------ | ----------- | ------------------------------------------------ |
| `DISK_AWARE`                               | `1`         | `0` turns off [disk pressure](#disk-pressure): thresholds keep their relaxed values as the disk fills, the size (B) and stale (C) rules prune at any free space, the critical free-space threshold neither empties the quarantine nor stops lifting blocks, a disk whose size cannot be read no longer stops the run, and there is no warning when something else fills the disk |
| `PRESSURE_RELAX_PCT` / `PRESSURE_RELAX_GB` | `20` / `20` | Above this much free: no pressure                |
| `PRESSURE_CRIT_PCT` / `PRESSURE_CRIT_GB`   | `10` / `2`  | At/below `min()` of these: full pressure         |
| `*_AGG`, e.g. `STALE_YEARS_DAYS_AGG`       | per knob    | Full-pressure endpoint for each knob that scales (defaults in the script, next to the knob) |

```sh
# example: only chase the giants, leave everything else
ABS_SIZE_FLOOR_MB=1000 STALE_YEARS_DAYS=99999 rad prune
```

## Run it on a schedule

After a reviewed first run, a weekly cron keeps the seed trimmed. Leaving out `--force` keeps both safety stops on: the runaway caps, and the hold on a rule that plans far more repos than usual.

Cron runs with a minimal environment, so `HOME` and `PATH` have to be spelled out. Substitute the user your node runs as:

```cron
# /etc/cron.d/rad-prune  Sundays 04:17
SHELL=/bin/sh
17 4 * * 0 radicle HOME=/home/radicle PATH=/usr/local/bin:/usr/bin:/bin /usr/local/bin/rad-prune --apply >> /home/radicle/.radicle/prune-audit/cron.log 2>&1
```

Point `RAD_HOME` at the node's home instead if it does not live at `$HOME/.radicle`.

To have the same job act on the parasite-peer rule (G) as well, add `--block-peers --yes`. That blocks every peer the rule names, with nobody reviewing it, so only do it once you have watched a few runs name nobody.

## Audit trail

Anything this tool does is written to `$RAD_HOME/prune-audit/` (default `~/.radicle/prune-audit/`). A dry run writes the last run's evidence, the creation-date ledger and the scan cache; the rest is written only by a run that acts:

- **`prune-<UTC-timestamp>.log`**: one file per acting run: every repo removed, tab-separated (rid, size, other-seed count, last activity, reason, name, the date the matching rule measured, any threshold that repo only just cleared), plus peer blocks made under `--block-peers` with the evidence behind each. `#` lines record each pruned repo's delegates (`# delegates:`), each pruned repo that was already blocked (`# was-blocked:`), each repo the run blocked but could not remove (`# prune-failed:`), each block the run lifted (`# unblocked:`), and, last, the run's exit code (`# exit`).
- **`quarantine/<rid>`**: every pruned repo, held for `QUARANTINE_DAYS` ([more](#quarantine)).
- **`run.lock`**: held while a run changes storage or the quarantine.
- **`keep.txt`**: repos never pruned, one id per line, whose block an `--apply` run lifts while they are in the quarantine, or a `did:key:` identity, which only the malware rule (H) reads; editable by hand; `quarantine restore` appends to it.
- **`deny.txt`**: repos and identities to prune and block on sight ([more](#deny-list)). The tool only reads it. The audit log names the entry each repo was pruned for on a `# denied:` line, and records each new block of an identity, or of a repo not yet fetched, on a `blocked-denied` line.
- **`deny-files.tsv`**: files whose copies are pruned too ([more](#copies-of-denied-files)). The tool only reads it. The audit log says how much of each copy was listed files, and from which source, on a `# denied-copy:` line.
- **`cache/`**: what the media (F) and parasite-peer (G) rules, and the search for copies of denied files, last read out of each repo. Safe to delete at any time; the next run reads everything again.
- **`history.log`**: one line per applied run that went ahead with its plan: its totals, disk pressure, free space, and the name of its audit log. An unattended run reads the logs named here to learn what each rule usually prunes.
- **`cron.log`**: with the cron recipe above, the full console output of every run.
- **`first-seen.tsv`**: when this seed first saw each repo. The spam-batch (D) and media (F) rules read it as a repo's creation date, and the search for copies of denied files reads it to tell which repo held a listed file first. Written by every run, dry or not, except `rad prune check`. Deleting it makes the listed files that were set aside count against their copies again.
- **`last-run/`**: what the last run decided and what it decided it on, untrimmed and tab-separated, whether or not that run acted. The terminal folds repetitive rows and cuts each evidence table to its top few; these files hold all of it, for reading later or piping elsewhere. A file named after a rule starts with that rule's letter, so a rule's files sit together. Replaced whole by the next run that gets far enough to write them, so check the dated `#` line at the top of each, which names the run that wrote it.
  - `plan.tsv`: every repo the run planned to prune, one row each, same columns as the audit log above. It is the plan, not the outcome; what an applying run actually removed is in that run's `prune-*.log`.
  - `held.tsv`: every rule an unattended run would hold back for planning far more than usual. Its repos are still listed in `plan.tsv`, since `--force` or a yes would prune them.
  - `unprune-plan.tsv`: each block the run plans to [lift](#blocks-the-tool-lifts-on-its-own), holds for a later run, or leaves blocked, with why and whether the repo is quarantined, deleted or still in storage. It is the plan, not the outcome; the audit log's `# unblocked:` lines record each lift.
  - `scan-errors.txt`: everything the run could not read.
  - `A-junk-name-kept-imports.tsv`: every junk-named repo the junk-name rule (A) kept because its history starts more than 14 days before its `rad init`.
  - `D-spam-batch-templates.tsv`: every template of the spam-batch rule (D), with how many repos matched it.
  - `F-media-kept-few-seeds.tsv`: every dump the media rule (F) found and kept because fewer than `MEDIA_MIN_SEEDS` other nodes seed it. Empty at the default of 0.
  - `F-media-unjudged.tsv`: every repo the media rule (F) could not judge, with its size. The run warns only when one of them is new since the last run, and names the new ones.
  - `G-parasite-peers.tsv`: every peer the parasite-peer rule (G) accused, with the evidence each accusation rests on.
  - `H-malware-identities.tsv`: every matching repo of every identity the malware rule (H) named, with the words it matched.
  - `H-malware-repos.tsv`: every single repo the malware rule (H) named, with the words and the path or commit subject it matched.
  - `deny-repos.tsv`: every repo pruned for the deny list, with the entry that named it: `listed`, or `delegate` and the identity.
  - `deny-copies.tsv`: every copy of denied files in the plan, with how much of it is listed files and where they came from.
  - `deny-copy-files.tsv`: every listed file each of those copies holds, by object id, with its bytes.

The files in `last-run/`, each `prune-*.log`, `first-seen.tsv` and `history.log` open with a few `#` lines saying what they hold. `keep.txt` gets them only when `quarantine restore` creates it, since an existing one is yours and is never rewritten.

```sh
tail ~/.radicle/prune-audit/history.log              # totals per run, newest last
cat  ~/.radicle/prune-audit/prune-2026*.log          # exact repos removed, with reasons
grep -v '^#' ~/.radicle/prune-audit/last-run/plan.tsv | cut -f5 | sort | uniq -c  # last plan, by reason
```

## Rule D: spam batches

A **spam batch** is a batch of repos one script stamped out from a single template: the same name shape with a slot filled in, the same description with a number swapped. Rule D is decided by the corpus, never by a single repo.

Every name and description in storage is *skeletonised*: digit runs become `#`, random-id tokens (6+ hex characters carrying both a letter and a digit) become `%`, so `example-2-3a9f81c2` becomes `example-#-%`. Repos are grouped by that skeleton with `#` and `%` collapsed into one wildcard (`example-*-*`), and a group is a spam batch only when all of:

1. the skeleton has at least one wildcard in it, so repos that share a fixed name are not a template;
2. at least `SPAM_MIN_BATCH` repos share the skeleton;
3. at least one of them carries a **random-id** slot rather than a plain enumeration (`SPAM_REQUIRE_ID=0` drops this);
4. at least `SPAM_DESC_AGREE_PCT`% of them share **one** non-empty description skeleton.

Only the members carrying the agreed description are pruned; repos with no description at all are never flagged. Descriptions differing only by a number count as agreeing.

On a real seed mirroring the whole public network the rule flags 442 repos in 10 batches and nothing else, leaving large mirror imports alone.

## Rule F: media dumps

A **media dump** is a repo whose files are video, images or audio with no project around them, using the seed as free file hosting.

A repo is flagged when all of:

1. it carries at least `MEDIA_MIN_BYTES` (64 KiB) of media;
2. everything that is *not* media adds up to less than `MEDIA_TEXT_MAX_BYTES` (2048);
3. no branch or tag holds a source file or a build file (a `Makefile`, `Cargo.toml`, `package.json` and the like);
4. it is older than `MEDIA_STALE_DAYS` (7d, since creation);
5. it has at least `MEDIA_MIN_SEEDS` (0) other seeds, so by default the seed count does not spare it.

A README of 2048 bytes or more is enough to fail condition 2. The **ratio path** reaches such a repo anyway. It is flagged `media-ratio` when it meets every condition but 2, *and*:

- the images, video and audio at the tips of its branches and tags come to at least `MEDIA_RATIO_MIN_BYTES` (6 MiB);
- everything else adds up to less than 0.1% of that;
- the repo holds no archive;
- the tips hold nothing besides the media but a single README (`README`, alone or with `.md`, `.markdown`, `.txt`, `.rst`, `.adoc` or `.org`).

A README and a licence are two files, so this path does not flag a repo holding both.

A repo whose name starts with a hostname (`seed.example.org`, `seed.example.org-avatar`) and that holds under 1 MiB of media is read as a seed's logo, and rule F never flags it. A name ending in a media extension, such as `wallpapers.png`, does not count as a hostname. A repo the run has no name for, because `rad ls` left it out or listed it twice, is spared the same way under 1 MiB of media.

Extensions (`MEDIA_EXTS`, `MEDIA_TEXT_EXTS`, `MEDIA_TEXT_NAMES`) are only a fast path. An unrecognised file has its first 16 bytes matched against media signatures, so renaming a video to `.dat` does not hide it. A gzipped file named like text, such as `rows.csv.gz`, is judged by what it unpacks to, so binary data inside it counts as media. Archives (zip, gzip, rar, 7z) count as media; a file matching no signature counts as text and spares the repo. Reading is capped at `MEDIA_SNIFF_MAX_FILES` (200) per repo, biggest first. A repo whose unread files could change the verdict is listed as unjudged instead.

Only the repo's own content counts: the canonical branches and tags, plus the namespaces of the delegates named in `refs/rad/id`, including every issue and patch comment a delegate signed, older ones too. Every other peer's namespace is ignored, and so is a stranger's patch or comment a delegate replied to, so a stranger pushing a video onto somebody's repo cannot put that repo in the plan. A repo with a branch whose commit is missing from storage is not judged.

A branch or tag is read at its tip, so media committed and then deleted in a later commit is missed. A repo whose listing dies part-way, with more than `MEDIA_MAX_REFS` (10000) refs or `MEDIA_MAX_OPS` (20000) issue and patch ops, or whose tips list as more than `MEDIA_TIP_BYTES` (16 MiB) of file names, is left unjudged.

The **batch path** reaches repos the other two miss, such as one with a script, or with a README too long for the dump path, as long as everything besides the media stays under the wider budget below. A repo is flagged `media-batch` when it meets conditions 1, 4 and 5 above, *and*:

- at least `MEDIA_MIN_BYTES` of its media sits in files that `MEDIA_MIN_BATCH` (5) or more repos in storage also hold, byte for byte, and that this repo was not the first to hold (first by the creation-date ledger). Only repos under the wider budget below count as holders;
- everything that is not media adds up to less than `MEDIA_TEXT_CEIL_BYTES` (64 KiB), the wider budget;
- no branch or tag holds a build file. A source file alone does not spare it.

`MEDIA_MIN_SEEDS=1` raises the floor. A dump no other node announces is then kept, and listed under `# review:` for a person to look at.

## Rule G: parasite peers

A **parasite peer** uses other people's repos as its file hosting. Its files sit in the storage of repos it is not a delegate of, where no repo rule can reach them. Rule G judges the **peer**, and prunes nothing.

A peer is named when all of:

1. a single file of the peer's own, matched byte for byte, sits in at least `PARASITE_MIN_REPOS` (10) repos that the peer is not a delegate of and whose own refs do not hold that file;
2. the peer's media across those repos adds up to at least `PARASITE_MIN_BYTES` (1 MiB);
3. everything the peer has pushed anywhere in storage that is *not* media adds up to less than `PARASITE_TEXT_MAX_BYTES` (16 KiB), because a peer who writes anything is a contributor.

A delegate of any repo in storage is never accused, and neither is this node itself.

Blocking a peer needs `--block-peers` ([usage](#usage)), and each block is written to the audit log with the evidence behind it. Dropping a blocked peer's refs frees no disk until `git gc` runs, which this tool never does, so the run counts none of those bytes as reclaimed.

On the seed the defaults were tuned against, the rule names nobody in the whole public network.

## Rule H: malware operations

Rule H names identities and repos whose names, descriptions, file paths or commit subjects read like a malware operation: a stealer, a drainer, a botnet and the panel that runs it. It prunes and blocks nothing. It can also name security research, or somebody a repo's creator named as a delegate from the start who then cloned it, so read each one before acting on it.

The words come in two kinds, strong (`MALWARE_STRONG_WORDS`: `hvnc`, `stealer`, `crypter`, `drainer`, `keylogger`, `ransomware`, `botnet`, `scam`) and weak (`MALWARE_WEAK_WORDS`: `c2`, `payload`, `panel`, `loader`, `zombie`, `rat`, `exploit`). A word matches whole or with one trailing `s`, so `stealers` matches and `pirate` does not match `rat`. Joined words like `TokenStealer` or `infostealer` do not match.

### Identities

An identity's repos here are the ones it is a delegate of and signed refs in. A repo whose name or description holds a word counts for it only if the identity was a delegate when the repo was created, since any delegate can add somebody who cloned the repo as a co-delegate. Otherwise that repo is left out of its repos altogether. The identity is named when, across the names and descriptions of its repos:

1. at least one strong word appears;
2. at least 3 different words appear, strong or weak;
3. at least 2 of its repos, and at least half of them, use any of the words.

An identity that is a delegate of a pinned, kept or your own repo is never named, and neither is one the deny list already names. Being a delegate of a private repo does not spare it.

For each identity, the run prints the repos that matched, with their names and the words found, and the `did:key:` line to add to the [deny list](#deny-list). In the deny list, that line prunes every repo the identity is a delegate of except its private ones, not only the ones that matched. It also blocks the identity, unless the identity is a delegate of a private repo.

To stop naming an identity you have cleared, add the same line to `keep.txt`. That line keeps none of its repos. Keeping one of its repos instead would clear every delegate of that repo, including whoever made the identity a delegate of it.

### Single repos

A repo is named on its own when its name or description holds a strong word, and a file path at the tips of its branches and tags, or a commit subject, holds the same or another strong word. Its first commit must also be at most 7 days older than its `rad init`, which leaves out a mirror of somebody else's security tool.

Pinned, kept, private, deny-listed and your own repos are never named. Nor is a repo already listed under its identity, or one signed by an identity the section above exempts, such as a delegate of a kept repo.

For each repo, the run prints a `rad:` line, followed after a `#` by the words and the path or subject found. In the deny list, that line prunes and blocks the repo alone. In `keep.txt`, it stops the repo being named, keeps it out of every rule, and clears all its delegates of rule H, including any who never signed it. So keep a repo only once you have read it.

## Development

```sh
tests/run.sh                 # everything
tests/run.sh -k quarantine   # only the sections that mention "quarantine"
```

Needs only `bash`, `git`, `gzip`, `openssl` and coreutils. With `shellcheck` installed, it also fails on any shellcheck warning in the script or the suite, outside the worker code the script keeps in quoted heredocs. Without it, that check is skipped and the suite says so. It builds a hermetic fixture and runs the real script against it, so it never reads or writes the real node.

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
