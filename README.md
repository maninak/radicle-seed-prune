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

- `bash`, `git`, `jq`, `rad`, `awk`, `sed`, `grep`, `find`, glibc's `iconv` and coreutils on `PATH`.
- OpenSSL 3 for the media (F) and malware (H) rules, and `gzip` for the media rule (F). `openssl version` shows which OpenSSL you have; Debian 12, Ubuntu 22.04 and later ship 3.
- Optional: `sqlite3`, to lift the block on a repo pruned for inactivity once one of its delegates updates it again ([more](#blocks-the-tool-lifts-on-its-own)).

Run it as the user that owns the Radicle home you want pruned, or set `RAD_HOME` to that home.

## Usage

`rad prune` and `rad-prune` run the same script, so the examples below work either way.

```sh
rad prune                    # preview: print the plan, change nothing
rad prune --apply            # apply, asks [y/N] first when run in a terminal
rad prune --apply --yes      # answer the confirmation with y (scripts, cron)
rad prune --apply --force    # apply even past a runaway cap, or a rule planning far more than usual
rad prune --apply --restart-node  # ...and restart the node afterwards
rad prune --block-peers      # block the peers the rules name, one [y/N] each; alone, prunes nothing
rad prune quarantine ...     # list, restore, delete, purge quarantined repos
rad prune check-mine         # which of your own public repos a seed would prune, and why
rad prune --version
```

There is no `--dry-run` flag. Running with no flags is the dry run. `--apply` scans once, prints that same plan, asks `[y/N]` in a terminal, and just applies when there is nobody to ask (cron, a pipe). `--yes` answers every prompt a run asks, including the per-peer block prompt.

`--block-peers` with nobody to ask (cron, a pipe) and no `--yes` blocks nobody and prints the `rad block` commands instead.

Every setting is an environment variable, as with `rad` itself:

```sh
RAD_HOME=/var/lib/radicle rad prune          # a seed home that isn't yours
RAD=/nix/store/.../bin/rad rad-prune         # a specific rad binary
sudo -u <node-user> env RAD_HOME=/var/lib/radicle rad-prune   # as the user the node runs as
```

`--help` prints the `RULES`, `RAD_HOME`, `STORAGE` and `AUDIT_DIR` a run with those settings would use.

### Example output

A dry run against a seed of 12,292 repos:

![A dry run of rad-prune, in colour](docs/example-run.svg)

*The same output as text: [example-run.txt](docs/example-run.txt)*

`AGE(d)` is the age the matching rule measured: days since last activity for the junk-name (A), size (B) and stale (C) rules, days since creation for the spam-batch (D) and media (F) rules.

`NEAR` marks the close calls, the rows that met a rule's threshold by less than `NEAR_PCT` (20%) of it, and names that threshold, such as `age`. Review them before `--apply`, and add any you want to keep to `keep.txt`. `-` means the row was not close.

The plan goes to stdout and everything else, progress included, to stderr, so `> plan.txt` keeps them apart. On a terminal the output is in colour. `NO_COLOR=1` turns colour off, and `FORCE_COLOR=1` turns colour on in a pipe or a file too.

### Exit codes

| Code | Meaning                                                                                                                                                                                                                             |
| ---- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `0`  | Success, including a dry run, an `--apply` you declined at the prompt, and a `check-mine` that flagged nothing                                                                                                                      |
| `1`  | Something went wrong, such as a missing command, a directory it cannot read or write, a repo it could not remove, or a block it could not make or lift. The run says what                                                           |
| `2`  | Bad argument, or a setting with a bad value (the run names it)                                                                                                                                                                      |
| `3`  | The plan tripped a runaway cap; nothing was pruned. Read it, then re-run with `--force`                                                                                                                                             |
| `4`  | A rule planned far more than usual, so its repos were held back; the other repos in the plan were pruned. Read it, then `--force`                                                                                                   |
| `5`  | Refused to run: it could not read enough of the node, the disk, storage or `keep.txt` to trust what it would do, or another `--apply`, `--block-peers` or quarantine run holds the lock. The run says what, and nothing was touched |
| `6`  | `check-mine` found a repo of yours that a seed running rad-prune would prune, or would list as possible malware                                                                                                                     |

## Checking your own repos

`rad prune check-mine` lists which of your public repos a seed running rad-prune would prune or list as possible malware, why, and what to change. It changes nothing.

![rad prune check-mine, in colour](docs/example-check-mine.svg)

*The same output as text: [example-check-mine.txt](docs/example-check-mine.txt)*

It judges every public repo on this node that you are a delegate of, however new, so you can run it as soon as you publish one.

## What gets pruned

A repo is pruned when a [rule](#rules) matches it, the [deny list](#deny-list) names it or one of its delegates, or it holds [copies of denied files](#copies-of-denied-files). Pinned, private and your own repos, and repos in `keep.txt`, are never pruned, and the rules also pass over the other [exclusions](#exclusions-never-touched-by-a-rule).

### Exclusions (never touched by a rule)

| Exclusion       | Source                                                |
| --------------- | ----------------------------------------------------- |
| Pinned repos    | `config.web.pinned.repositories`                      |
| Private repos   | `rad ls --private`, or a private identity document    |
| Your own repos  | `rad ls`, or this node's signed refs in the repo      |
| Kept repos      | `$AUDIT_DIR/keep.txt`, one repo id per line ([more](#quarantine)) |
| Freshly written | storage dir modified within `FRESH_GUARD_DAYS`        |
| Unknown age     | no readable refs                                      |
| Unreadable      | hit an error when reading the repo                    |

### Deny list

Repos and identities you, or someone you trust, have already judged go in `$AUDIT_DIR/deny.txt`, one per line, with or without the `rad:` or `did:key:` prefix. `#` starts a comment. A list another operator shared with you works as is. To use several, concatenate them into this one file.

```
rad:z<rid>          # a repo: pruned and blocked, even before it arrives
did:key:z6Mk<nid>   # an identity: blocked, and every repo it is a delegate of is pruned
```

`--apply` prunes and blocks every repo and identity listed, regardless of age, size, seed count or an unfinished fetch. An identity's patches and comments in repos it is not a delegate of get none of those repos pruned. An identity that is a delegate of a pinned, private, kept or your own repo is not blocked. Denied repos do not count toward the runaway caps or the hold-back, but a run the caps stop neither prunes nor blocks any of them.

Removing a line does not undo its blocks. Run `rad unseed <rid>` or `rad unfollow <nid>`.

#### Copies of denied files

Files from a leak or media dump you pruned can turn up again in other repos. List them in `$AUDIT_DIR/deny-files.tsv`, and every run plans the repos holding copies for pruning, as `denied-copy`. While the pruned repo is in the quarantine, this command lists its media files:

```sh
rad prune quarantine files <rid> >> ~/.radicle/prune-audit/deny-files.tsv
```

Each row is `<object id> <bytes or -> <source> [date]`, fields separated by spaces or tabs, and `#` starts a comment.

A repo counts as a copy when listed images, video, audio or archives make up at least 5 MiB, and at least half the bytes, of its delegates' branches and tags, history included. Copies are pruned at any age or seed count, and no identity is blocked for one. Unlike repos the deny list names, copies count toward the runaway caps and the hold-back.

List only the pruned repo's own files, since a row counts against every repo whose delegates' branches or tags hold that file. A file that a repo here held before the repos it is listed from counts against no repo. The run names the file and that repo. If that repo is a copy after all, add it to `deny.txt`. If the files are its own, drop their rows. Rows whose source is in `keep.txt` are ignored. A shared list's ids cannot be checked by reading them, so use one only from someone you trust.

### Rules

`RULES` selects which rules run. When it is not set, all of them run:

- **A, junk-name**: prunes a repo with a disposable or random name.
- **B, size**: prunes a giant that has gone quiet.
- **C, stale**: prunes a repo that has been quiet for a long time.
- **D, spam-batch**: prunes repos stamped out in a batch from one template.
- **F, media**: prunes video, images or audio with no project around them.
- **G, parasite-peer**: names peers who use repos they are not a delegate of as file hosting, and prunes nothing ([more](#rule-g-parasite-peers)).
- **H, malware**: names identities and single repos that look like a malware operation, and by default prunes nothing ([more](#rule-h-malware-operations)).

The size (B) and stale (C) rules prune only under [disk pressure](#disk-pressure), and the run's output header marks them `waiting` until then. Leaving a rule out of `RULES` does not spare the repos it would have matched, since another rule can still prune them. For example, the stale rule (C) can prune an old media dump while the media rule (F) is off.

A rule that prunes asks for **something about the repo**, and most also ask that it is old enough *and* that enough other nodes still hold it. Defaults shown.

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
| **H, malware-op**  | a delegate is an identity named as a malware operation, with `MALWARE_PRUNE=1` ([more](#rule-h-malware-operations)) | none                      | none                     |

#### How age is measured

The junk-name (A), size (B) and stale (C) rules measure **last activity**. Activity is any signed change, however small: a commit, an issue, a comment, a reaction, a label. The tool uses the newest `creatordate` across every peer's refs.

The spam-batch (D) and media (F) rules measure **creation** instead, because spam that comments on its own repos would reset a last-activity clock. Creation is the older of the repo's oldest ref date and the day this seed first saw it (`first-seen.tsv` in the [audit directory](#audit-trail)). A pusher controls the first date and cannot reach the second.

#### Verdicts that may delete the last copy we know of

By default, `junk-id`, `spam-batch`, `media-dump`, `media-ratio` and `media-batch` prune a repo even when no other node seeds it. The seed count is only how many nodes this node has heard announce the repo, which is no proof a copy exists. These verdicts are why pruning [quarantines instead of deleting](#quarantine). To keep the last copy, set `JUNK_ID_MIN_SEEDS=1 SPAM_MIN_SEEDS=1 MEDIA_MIN_SEEDS=1`. `denied`, `denied-copy` and `malware-op` ignore seed counts.

#### Names that count as disposable

`test`, `tmp`, `temp`, `scratch`, `playground`, `sandbox`, `demo`, `dummy`, `wip`, `trash`, `junk`, `old`, `throwaway`, `helloworld`, as whole words delimited by `-`, `_`, `.` or the ends of the name; plus `foo` / `bar` / `baz`, but only as an entire name. A space is not a delimiter: `test-old` matches, `The old man` does not. A name that is *nothing but* a random hex id of `JUNK_ID_MIN_LEN`+ characters counts too (`0a1b2c3d4e5f`); both a letter and a digit are required, so `12345678` and `facade` do not.

### Disk pressure

The thresholds above are the **relaxed** values. As the disk fills, they tighten and the tool prunes more. They are at their loosest with 20% or 20 GB free, whichever is more (`PRESSURE_RELAX_PCT`, `PRESSURE_RELAX_GB`), and at their tightest with 10% or 2 GB free, whichever is less (`PRESSURE_CRIT_PCT`, `PRESSURE_CRIT_GB`). In between, the pressure the output header prints rises from 0% to 100%, and each threshold moves in a straight line toward its aggressive value:

| knob                 | relaxed (0%)    | aggressive (100%)  |
| -------------------- | --------------- | ------------------ |
| `STALE_YEARS_DAYS`   | 730             | 60                 |
| `OUTLIER_STALE_DAYS` | 90              | 14                 |
| `JUNK_STALE_DAYS`    | 30              | 7                  |
| `SPAM_STALE_DAYS`    | 7               | 1                  |
| `ABS_SIZE_FLOOR_MB`  | 500             | 50                 |
| `REL_PCTL`           | 95              | 50                 |
| `MIN_OTHER_SEEDS`    | 3               | 1                  |

The run's output header prints the live pressure and the effective thresholds. Pressure is read once, at the start of a run, and counts the quarantine copies that run will purge as free. Pressure reads free space on the whole disk, so a large log or cache also makes a run prune harder.

## Safety and recovery

- **Dry run by default.** Nothing is pruned, and nothing on the deny list is blocked, without `--apply`. A peer or identity that the parasite-peer (G) or malware (H) rule named is blocked only under `--block-peers`.
- **Quarantine instead of deletion.** A pruned repo stays on disk for `QUARANTINE_DAYS` (7) and is restorable with one command ([details](#quarantine)).
- **Minimum seed counts** keep the last copy we know of, [except where a verdict's floor is 0](#verdicts-that-may-delete-the-last-copy-we-know-of).
- **Runaway caps** (`MAX_PRUNE_COUNT`, `MAX_PRUNE_GB`) abort a plan whose rules picked more than either cap. Only `--force` or a `y` at the prompt gets past them, so an unattended run stops even with `--yes`.
- **A rule that suddenly plans far more repos than usual is held back.** An unattended run holds back a rule that plans more than `RATCHET_FLOOR` (20) repos and more than `RATCHET_FACTOR` (3) times the median it pruned over its last `RATCHET_RUNS` (8) applied runs. Its repos stay in storage, the other rules go ahead, and the run exits 4. A dry run shows what would be held, and `--force` or a `y` at the prompt gets past it. The spam-batch (D) and media (F) rules usually prune nothing, so a sudden batch of more than 20 repos from one of them waits for `--force` or a `y`.
- **Freshness guard** skips any repo whose storage directory was written within `FRESH_GUARD_DAYS` (2), which is what a fetch still arriving looks like.
- **Blind scans abort.** When more than `MAX_SCAN_FAIL_PCT` (10%) of the repos in storage cannot be read, the run stops with exit 5 instead of printing a small plan.
- **The tool lifts only blocks it made**, at most once per repo ([more](#blocks-the-tool-lifts-on-its-own)).
- **Audit log** records every prune, every block and every lifted block, with the evidence behind it.

For each selected repo, in this order:

```sh
rad unseed <rid>                              # drop whatever single seeding policy the repo has
rad block  <rid>                              # set an explicit block, so default-allow won't re-fetch it
mv <storage>/<rid> <audit>/quarantine/<rid>   # out of storage, still on disk
```

The node keeps running during a prune. After a large first run, `sudo systemctl restart radicle-node` clears a stale "inventory announce limit" warning; `--restart-node` runs that restart for you, if the run has the rights to. On some heartwood versions `rad node inventory` still lists removed repos afterwards. That listing is cosmetic, and the repos are gone.

### Quarantine

A pruned repo moves to `$AUDIT_DIR/quarantine/<rid>` instead of being deleted, and can be restored for `QUARANTINE_DAYS` (7) days. After that, the next `--apply` run that goes ahead (past the runaway caps and the prompt) deletes it for good, even if that run prunes nothing itself. At or under the critical free-space threshold, such a run empties the whole quarantine. No `--apply` run, `quarantine purge` or `quarantine delete --all` deletes a repo listed in `keep.txt` from the quarantine, even at the critical threshold ([more](#blocks-the-tool-lifts-on-its-own)). `QUARANTINE=0` deletes outright and keeps nothing.

Deleting a quarantined repo by hand (`rm -rf`) is safe at any time and only costs the ability to restore it.

```sh
rad prune quarantine list             # what is held, and for how long
rad prune quarantine restore <rid>    # put it back in storage and re-seed it
rad prune quarantine delete <rid>     # or --all: delete now, for good
rad prune quarantine purge            # delete whatever is past its window
rad prune quarantine files <rid>      # its images, video, audio and archives, as deny-files.tsv rows
```

`restore` moves the repo back into storage, clears the block, re-seeds it, and adds it to the keep list, `$AUDIT_DIR/keep.txt`, so the next run leaves it alone. The keep list is one repo id per line, editable by hand. No rule and no deny list prunes a repo listed there.

### Undoing a prune

Within the quarantine window:

```sh
rad prune quarantine restore <rid>
```

After the window the local copy is gone, and the repo is re-fetchable as long as other nodes still hold it. Two commands, in this order:

```sh
rad unseed <rid>
rad seed  <rid>
```

`rad seed` on its own leaves a blocked repo blocked, even though it prints a success line. `rad unseed` drops the block.

```sh
# every repo in a given run's plan, from that run's audit log
awk -F'\t' '!/^#/ && $1 !~ /^blocked-/ {print "rad:"$1}' \
  ~/.radicle/prune-audit/prune-20260628T183150Z.log |
  while read -r rid; do rad unseed "$rid" && rad seed "$rid"; done
```

### Blocks the tool lifts on its own

Pruning blocks a repo so the node does not fetch it back. An `--apply` run lifts a block rad-prune made when any of these holds:

- A later rad-prune release withdrew the verdict that pruned the repo (`UNDO_CHANGED` in the script). For the size (B) and stale (C) rules, that holds only while they wait for disk pressure. A deleted repo bigger than the size limit that release set for the verdict stays blocked.
- One of the repo's delegates announced new refs for it after it was pruned for inactivity (`junk-name`, `junk-id`, `size-outlier`, `stale`). If the audit log of the run that last pruned the repo recorded no delegates for it, any node announcing refs of its own counts. A node `deny.txt` names never counts. Needs `sqlite3`. This node forgets announcements after two weeks by default, so a run more than two weeks after the one before can miss some.
- The verdict that pruned the repo is a known mistake (`UNDO_PARDON` or `UNDO_LIFT` in the script).
- The repo is still in the quarantine and is in `keep.txt`. rad-prune also seeds it again, and this lift does not count against `UNDO_MAX_COUNT` or `UNDO_MAX_GB`.
- rad-prune blocked the repo but could not remove it, and the repo is now kept, pinned, private or your own, or a later release withdrew its verdict or lists it as a known mistake. It stays in storage, so this lift ignores the limits below and the critical free-space threshold.

A repo still in the quarantine goes back into storage, and a later run judges it. A deleted one is judged once this node fetches it again. Under a default seeding policy of `allow`, the node seeds both and fetches a deleted one by itself.

A run lifts a block at most once per repo, and never one the audit log records as blocked before the prune. Unless the repo is in the quarantine and in `keep.txt`, it also never lifts the block on a repo:

- that the deny list pruned, or that `deny.txt` names by its id;
- one of whose delegates `deny.txt` names, when the audit log or the quarantined copy names the delegates;
- that is pinned, private or your own, unless a failed removal left it in storage.

A run lifts the block on at most `UNDO_MAX_COUNT` (200) deleted repos, and `UNDO_MAX_GB` (10) GiB of them as measured when they were pruned. While free space is at or under the critical threshold ([more](#disk-pressure)), it lifts none. `last-run/unprune-plan.tsv` lists each block a run plans to lift, and why. `UNDO=0` turns the lifting off.

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
| D    | `SPAM_MIN_BATCH`      | `5`       | Repos needed for a batch, with names that read the same                |
| D    | `SPAM_DESC_AGREE_PCT` | `80`      | Share of that batch that must share one description                    |
| D    | `SPAM_REQUIRE_ID`     | `1`       | Demand a random id in at least one name (`0` is looser)                  |
| D    | `SPAM_STALE_DAYS`     | `7`       | Age since creation                                                      |
| D    | `SPAM_MIN_SEEDS`      | `0`       | Other seeds required; `0` may prune the last copy we know of            |
| F    | `MEDIA_MIN_BYTES`     | `65536`   | Media bytes below which a repo is not worth judging                     |
| F    | `MEDIA_TEXT_MAX_BYTES`| `2048`    | Everything that is not media, added up, must stay under this            |
| F    | `MEDIA_STALE_DAYS`    | `7`       | Age since creation                                                      |
| F    | `MEDIA_MIN_SEEDS`     | `0`       | Other seeds required; `0` may prune the last copy we know of            |
| F    | `MEDIA_MIN_BATCH`     | `5`       | Repos holding one media file, byte for byte, to call it a media batch      |
| F    | `MEDIA_TEXT_CEIL_BYTES`| `65536`  | `media-batch`'s budget for everything that is not media                 |
| F    | `MEDIA_RATIO_MIN_BYTES`| `6291456` | Images, video and audio `media-ratio` needs (6 MiB); `999999999999` turns it off |
| F    | `MEDIA_MAX_REFS`      | `10000`   | Refs above which a repo is too costly to read, so it goes unjudged      |
| F    | `MEDIA_MAX_OPS`       | `20000`   | Issue and patch ops above which a repo goes unjudged, a patch's own commits included |
| F    | `MEDIA_EXTS`          | images, video, audio, archives | `\|`-separated extensions judged as media; one you add counts as image, video or audio, never as an archive, for `media-ratio` |
| G    | `PARASITE_MIN_REPOS`  | `10`      | Non-delegated repos one file of a peer's must reach, byte for byte      |
| G    | `PARASITE_MIN_BYTES`  | `1048576` | Media bytes required across those repos (1 MiB)                         |
| G    | `PARASITE_TEXT_MAX_BYTES` | `16384` | Text budget across the repos where the peer, or another non-delegate, pushed media |
| H    | `MALWARE_STRONG_WORDS` | `hvnc\|stealer\|...` | Lower-case, `\|`-separated words, one of which an identity's repos, or a single repo, must use |
| H    | `MALWARE_WEAK_WORDS`  | `c2\|payload\|...` | Lower-case, `\|`-separated words that count towards the 3 different words the malware rule (H) needs |
| H    | `MALWARE_PRUNE`       | `0`       | `1` prunes the repos of each identity the malware rule (H) names, and lets `--block-peers` block those identities ([more](#rule-h-malware-operations)) |

**Brakes**

| Variable            | Default | Meaning                                                                                                                                                     |
| ------------------- | ------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `FRESH_GUARD_DAYS`  | `2`     | Skip repos written this recently (an in-flight fetch)                                                                                                       |
| `MAX_PRUNE_COUNT`   | `1000`  | Runaway guard: abort over this many repos                                                                                                                   |
| `MAX_PRUNE_GB`      | `80`    | Runaway guard: abort over this many whole GiB                                                                                                               |
| `RATCHET_FACTOR`    | `3`     | Hold back a rule that plans over this multiple of its recent median                                                                                         |
| `RATCHET_RUNS`      | `8`     | How many of a rule's recent applied runs its median is taken from, counting only runs in which it could prune. With fewer than 3 readable logs, or a value under 3, nothing is held |
| `RATCHET_FLOOR`     | `20`    | A rule planning this many repos or fewer is never held back                                                                                                 |
| `MAX_SCAN_FAIL_PCT` | `10`    | Abort if more than this share of the repos in storage vanished, could not be read or had no readable refs                                                                                |

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
| `KEEP_FILE`          | `$AUDIT_DIR/keep.txt` | Repos never pruned ([more](#quarantine))                   |
| `CACHE`              | `1`     | Reuse what the media (F) and parasite-peer (G) rules, and the search for copies of denied files, read out of repos that have not changed (`0` reads everything, every run) |
| `CACHE_DIR`          | `$AUDIT_DIR/cache` | Where that reading is kept                                      |
| `PLAN_COLLAPSE_ROWS` | `20`    | When the plan holds at least this many `spam-batch` (or `media-batch`) repos, it shows them as one line |
| `PLAN_FULL`          | `0`     | `1` lists every plan row and every evidence table entry, untruncated       |
| `NEAR_PCT`           | `20`    | A row's `NEAR` column names any threshold it cleared by less than this share of the threshold; `0` marks nothing |
| `PROGRESS_SECS`      | `60`    | Seconds between progress lines when the output is not a terminal (cron, a log file); `0` turns off all progress reporting |

**Disk pressure** ([what it does](#disk-pressure))

| Variable                                   | Default     | Meaning                                          |
| ------------------------------------------ | ----------- | ------------------------------------------------ |
| `DISK_AWARE`                               | `1`         | `0` turns off [disk pressure](#disk-pressure) and every check of free space: thresholds keep their relaxed values as the disk fills, and the size (B) and stale (C) rules prune at any free space |
| `PRESSURE_RELAX_PCT` / `PRESSURE_RELAX_GB` | `20` / `20` | At or above this much free: no pressure          |
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

To have the same job act on the parasite-peer rule (G) as well, add `--block-peers --yes`. That blocks every peer the rule names, with nobody reviewing it, so only do it once you have watched a few runs name nobody. With `MALWARE_PRUNE=1`, it also blocks each identity the malware rule (H) names, in the run that prunes its repos.

## Audit trail

Anything this tool does is written to `$RAD_HOME/prune-audit/` (default `~/.radicle/prune-audit/`). A dry run writes the last run's evidence, the creation-date ledger and the scan cache; the rest is written only by a run that acts:

- **`prune-<UTC-timestamp>.log`**: one file per acting run, listing every repo it goes on to prune, written before any is removed, tab-separated (rid, size, other-seed count, last activity, reason, name, the date the matching rule measured, any threshold that repo only just cleared), plus peer and identity blocks made under `--block-peers` with the evidence behind each. `#` lines record each pruned repo's delegates (`# delegates:`), each pruned repo that was already blocked (`# was-blocked:`), each repo the run blocked but could not remove (`# prune-failed:`), the identities each `malware-op` repo was pruned for (`# malware-op:`), each block the run lifted (`# unblocked:`), and, last, the run's exit code (`# exit`).
- **`quarantine/<rid>`**: every pruned repo, held for `QUARANTINE_DAYS` ([more](#quarantine)).
- **`keep.txt`**: repos never pruned ([more](#quarantine)).
- **`deny.txt`**: repos and identities to prune and block on sight ([more](#deny-list)). The tool only reads it. The audit log names the entry each repo was pruned for on a `# denied:` line, and records each new block of an identity, or of a repo not yet fetched, on a `blocked-denied` line.
- **`deny-files.tsv`**: files whose copies are pruned too ([more](#copies-of-denied-files)). The tool only reads it. The audit log says how much of each copy was listed files, and from which source, on a `# denied-copy:` line.
- **`cache/`**: what the media (F) and parasite-peer (G) rules, and the search for copies of denied files, last read out of each repo. Safe to delete at any time; the next run reads everything again.
- **`history.log`**: one line per applied run that went ahead with its plan: its totals, disk pressure, free space, and the name of its audit log. An unattended run reads the logs named here to learn what each rule usually prunes.
- **`cron.log`**: with the cron recipe above, the full console output of every run.
- **`first-seen.tsv`**: when this seed first saw each repo. The spam-batch (D) and media (F) rules read it as a repo's creation date, and the search for copies of denied files reads it to tell which repo held a listed file first. Written by every run, dry or not, except `rad prune check-mine`.
- **`last-run/`**: what the last run decided and what it decided it on, untrimmed and tab-separated, whether or not that run acted. The terminal folds repetitive rows and cuts each evidence table to its top few; these files hold all of it. Replaced whole by the next run that gets far enough to write them, so check the dated `#` line at the top of each, which names the run that wrote it.
  - `plan.tsv`: every repo the run planned to prune, one row each, same columns as the audit log above. It is the plan, not the outcome. An applying run's `prune-*.log` lists what that run went on to prune.
  - `held.tsv`: every rule an unattended run would hold back for planning far more than usual. Its repos are still listed in `plan.tsv`, since `--force` or a yes would prune them.
  - `unprune-plan.tsv`: each block the run plans to [lift](#blocks-the-tool-lifts-on-its-own), holds for a later run, or leaves blocked, with why and whether the repo is quarantined, deleted or still in storage. It is the plan, not the outcome; the audit log's `# unblocked:` lines record each lift.
  - `scan-errors.txt`: everything the run could not read.
  - `A-junk-name-kept-imports.tsv`: every junk-named repo the junk-name rule (A) kept because its history starts more than 14 days before its `rad init`.
  - `D-spam-batch-templates.tsv`: every template of the spam-batch rule (D), with how many repos matched it.
  - `F-media-kept-few-seeds.tsv`: every dump the media rule (F) found and kept because fewer than `MEDIA_MIN_SEEDS` other nodes seed it. Empty at the default of 0.
  - `F-media-unjudged.tsv`: every repo the media rule (F) could not judge, with its size.
  - `G-parasite-peers.tsv`: every peer the parasite-peer rule (G) accused, with the evidence each accusation rests on.
  - `H-malware-identities.tsv`: every matching repo of every identity the malware rule (H) named, with the words it matched.
  - `H-malware-repos.tsv`: every single repo the malware rule (H) named, with the words and the path or commit subject it matched.
  - `H-malware-op-repos.tsv`: every repo in the plan as `malware-op`, with the named identities among its delegates.
  - `deny-repos.tsv`: every repo pruned for the deny list, with the entry that named it: `listed`, or `delegate` and the identity.
  - `deny-copies.tsv`: every copy of denied files in the plan, with how much of it is listed files and where they came from.
  - `deny-copy-files.tsv`: every listed file each of those copies holds, by object id, with its bytes.

The files in `last-run/`, each `prune-*.log`, `first-seen.tsv` and `history.log` open with a few `#` lines saying what they hold. `keep.txt` gets them only when `quarantine restore` creates it.

```sh
tail ~/.radicle/prune-audit/history.log              # totals per run, newest last
cat  ~/.radicle/prune-audit/prune-2026*.log          # repos each run planned, with reasons
grep -v '^#' ~/.radicle/prune-audit/last-run/plan.tsv | cut -f5 | sort | uniq -c  # last plan, by reason
```

## Rule D: spam batches

A **spam batch** is a batch of repos one script stamped out from a single template: the same name shape with a slot filled in, the same description with a number swapped.

The spam-batch rule (D) reads digit runs and random hex ids (6 or more hex characters with a letter and a digit) in names and descriptions as wildcards, so `example-2-3a9f81c2` reads as `example-*-*`. Repos whose names read the same way are a batch when there are at least `SPAM_MIN_BATCH` (5) of them, at least one of their names has a random id (`SPAM_REQUIRE_ID=0` drops this), and at least `SPAM_DESC_AGREE_PCT` (80%) of them share one non-empty description. Only the members with that description are pruned. The member this seed saw before the others is spared, so copies pushed later cannot get it pruned. When the earliest members arrived in the same run, none is spared.

## Rule F: media dumps

A **media dump** is a repo of video, images or audio with no project around it. Once a repo is older than `MEDIA_STALE_DAYS` (7d, since creation), the media rule (F) prunes it when it matches one of these verdicts:

- `media-dump`: at least `MEDIA_MIN_BYTES` (64 KiB) of media, under `MEDIA_TEXT_MAX_BYTES` (2048 bytes) of anything else, and no source or build file (a `Makefile`, `Cargo.toml`, `package.json` and the like);
- `media-ratio`: at least `MEDIA_RATIO_MIN_BYTES` (6 MiB) of images, video and audio at the tips of its branches and tags, with no other file there but at most one README, under 0.1% of that size in anything else, no archive, and no source or build file;
- `media-batch`: at least `MEDIA_MIN_BYTES` of media in files that `MEDIA_MIN_BATCH` (5) or more repos here hold byte for byte, and that this repo was not the first to hold. This repo and each repo counted toward those 5 must hold under `MEDIA_TEXT_CEIL_BYTES` (64 KiB) of anything but media, and this repo must have no build file.

The first to hold a file is the repo this seed saw first. If copies arrived before the original, the earliest copy is spared and the original is pruned as one more copy. Add the original to `keep.txt` to spare it. Moving storage with `cp` or `rsync` can change which repo counts as first.

Archives count as media. A file with an extension the rule does not know is judged by its first bytes, so renaming a video to `.dat` does not hide it. Only the repo's own content counts: its canonical branches and tags, and what its delegates pushed or signed, issue and patch attachments included. A repo the rule cannot read in full is left unjudged and listed in `last-run/F-media-unjudged.tsv`.

`MEDIA_MIN_SEEDS=1` keeps a dump no other node announces and lists it under `# REVIEW` for a person to look at. To spare a repo the rule got wrong, add its repo id to `keep.txt`.

## Rule G: parasite peers

A **parasite peer** uses other people's repos as its file hosting. Its files sit in the storage of repos it is not a delegate of, where no repo rule can reach them. The parasite-peer rule (G) names the **peer**, and prunes nothing.

A peer is named when all of:

1. a single file of the peer's own, matched byte for byte, sits in at least `PARASITE_MIN_REPOS` (10) repos that the peer is not a delegate of and whose own refs do not hold that file;
2. the peer's media in the repos it is not a delegate of adds up to at least `PARASITE_MIN_BYTES` (1 MiB);
3. and it pushed less than `PARASITE_TEXT_MAX_BYTES` (16 KiB) of anything else into the repos where non-delegates pushed media.

A delegate of any repo in storage is never accused, and neither is this node itself.

Blocking a peer needs `--block-peers` ([usage](#usage)). Dropping a blocked peer's refs frees no disk until `git gc` runs, which rad-prune never does.

## Rule H: malware operations

The malware rule (H) names identities and single repos that read like a malware operation: a stealer, a drainer, a botnet and the panel that runs it. By default it prunes and blocks nothing. It can also name security research, so read each finding before acting on it.

It looks for strong words (`MALWARE_STRONG_WORDS`: `hvnc`, `stealer`, `crypter`, `drainer`, `keylogger`, `ransomware`, `botnet`, `scam`) and weak ones (`MALWARE_WEAK_WORDS`: `c2`, `payload`, `panel`, `loader`, `zombie`, `rat`, `exploit`), as whole words, with or without a trailing `s`.

- **An identity** is named when at least 2 of the repos it signed as a delegate, and at least half of them, use a word in their name or description, and those names and descriptions hold 3 different words, one of them strong. A repo with a word counts toward an identity only if that identity created it.
- **A single repo** is named when its name or description holds a strong word, a file path or commit subject in it holds one too, and its first commit is at most 7 days older than its `rad init`, which leaves out a mirror of somebody else's tool. The rule never prunes it.

Each finding comes with the `did:key:` or `rad:` line to add to the [deny list](#deny-list) or to `keep.txt`. In `keep.txt`, either line stops the finding being named again, and a `rad:` line also keeps that repo out of every rule and stops the malware rule (H) naming any delegate of that repo.

`MALWARE_PRUNE=1` acts on the identities the rule names instead. It prunes every repo a named identity is a delegate of as `malware-op`, whatever its seed count and however recent, once its age is known and no fetch is in flight. An `--apply` run with `--block-peers` also blocks each named identity, in the run that prunes its repos. If you decline the block or it fails, run the `rad block` line the run printed. A run that holds the rule back blocks nobody.

The rule spares a repo with signed refs from an identity in `keep.txt` or from a delegate of a pinned, kept or your own repo, and does not block a named identity that is a delegate of a spared repo. To undo a verdict, run `rad prune quarantine restore` on the repo. That clears its delegates of the rule, and prints the `rad unfollow <nid>` that lifts a block an earlier run put on one of them.

## Development

```sh
tests/run.sh                 # everything
tests/run.sh -k quarantine   # only the sections that mention "quarantine"
```

Needs only `bash`, `git`, `gzip`, `iconv`, `openssl` and coreutils. With `shellcheck` installed, it also fails on any shellcheck warning in the script or the suite. It builds a hermetic fixture and runs the real script against it, so it never reads or writes the real node.

The suite is cut into sections, one per fixture rebuild. A whole run takes minutes and a single section takes seconds. `-k` takes a regular expression and runs every section whose text contains a match, so a test name, a repo id, a setting or a rule letter all select one. The fixture is kept under `TMPDIR` for an hour; `RSP_FIXTURE_CACHE=0` builds it fresh every time.

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

[![A radicle.tools artifact (homegrown apps and tools for Radicle)](https://radicle.tools/badge/artifact.svg)](https://radicle.tools)
