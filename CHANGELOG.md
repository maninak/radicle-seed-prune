# Changelog

All notable changes to this project are documented here. The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Upgrading

Replace the script, then do a dry run. The media rule (F) now needs `gzip` and OpenSSL 3, and the dry run stops and says so if either is missing.

The first `--apply` may lift the block on repos earlier releases pruned, including repos pruned for inactivity that a node has announced refs for since. A dry run lists them in `last-run/undo.tsv`. Those releases recorded neither a repo's delegates nor a block that stood before the prune, so to keep one of those repos blocked, add its repo id to `deny.txt` first. To lift none, set `UNDO=0`.

The files rad-prune writes in the audit directory now open with a few `#` lines saying what they hold, so the line naming the run is no longer the first ([details](./README.md#audit-trail)). A script that reads them must skip lines starting with `#`. Five files in `last-run/` are renamed:

| Before | Now |
|---|---|
| `spam-batches.tsv` | `D-spam-batch-templates.tsv` |
| `spam-domains.tsv` | `E-link-farm-domains.tsv` |
| `media-review.tsv` | `F-media-kept-few-seeds.tsv` |
| `media-unjudged.tsv` | `F-media-unjudged.tsv` |
| `parasite-peers.tsv` | `G-parasite-peers.tsv` |

A run that holds back a rule exits `4`. A monitor that alerts on exit `3` should alert on `4` too.

### Added

- **`--apply` lifts the block on repos that rad-prune may have pruned by mistake.** These are repos pruned under a verdict a later release no longer trusts, repos pruned for inactivity that a node announced new refs for since (needs `sqlite3`), and known mistakes the script lists ([details](./README.md#blocks-the-tool-lifts-on-its-own)).
- **You can name repos and identities to prune and block on sight.** List them in `deny.txt` in the audit directory. `--apply` prunes and blocks each listed repo and every repo a listed identity is a delegate of, and blocks the identity too ([details](./README.md#deny-list)). Pinned, private, your own and kept repos are spared.
- **Repos that hold copies of files from a repo `deny.txt` names are pruned too.** A repo is pruned when at least 5 MiB of files listed in `deny-files.tsv` make up half or more of what its delegates committed ([details](./README.md#copies-of-denied-files)). `rad prune quarantine files <rid>` prints a quarantined repo's files in that list's format.
- **The media rule (F) catches more media dumps.** A repo with 6 MiB or more of images, video and audio, at most one README and almost nothing else is now pruned as `media-ratio` ([details](./README.md#rule-f-media-dumps)).
- **Identities and repos that look like a malware operation are listed for you to review.** Nothing is pruned or blocked ([details](./README.md#rule-h-malware-operations)). If you set `RULES` yourself, add `H` to it.

### Changed

- **When one rule plans far more repos than usual, an unattended run holds back only that rule.** The other repos in the plan are pruned, and the run exits `4` ([details](./README.md#safety-and-recovery)). It used to prune nothing and exit `3`.

### Fixed

- **Your own and private repos can no longer be pruned when `rad ls` misses them or fails.** The run now checks each repo on disk too, and stops with exit `5` when `rad ls` fails.
- **An older project brought to Radicle is no longer pruned as junk for a word like `demo` or `test` in its name.** The junk-name rule (A) spares a repo whose first commit is more than 14 days before its `rad init`.
- **The media rule (F) spares more real projects.** A source file or a build file (such as a `Makefile` or `package.json`) now spares a repo from `media-dump`, and a build file spares it from `media-batch` too. Compressed text such as `rows.csv.gz` counts as text, and a repo named after a seed's hostname with under 1 MiB of media is never flagged. Only repos with almost no text count toward a media batch, and a repo with a branch whose commit is missing from storage is no longer judged.
- **`keep.txt` is read correctly however it was saved.** A byte-order mark from some Windows editors, or a `quarantine restore` onto a file with no final line break, could make a run ignore a listed repo and prune it.
- **Repos that `rad ls` lists as `local` are no longer pruned as `spam-batch`.** Their head commit was read as their description.
- **`--apply` stops with exit `1` before it touches any repo when it cannot write storage or the quarantine.** It used to block every repo in the plan and leave them all in storage.
- **`--apply` and `--block-peers` stop with exit `1` before the scan when they cannot write the audit directory.** They could block a peer or a `deny.txt` entry and then fail to record it.
- **A run that could not remove a repo in its plan exits `1`.** It used to exit as if nothing had failed, with only a warning. The run that does remove it later no longer records the block left behind as somebody else's, which kept the undo from ever lifting it.
- **A run no longer writes over the audit log of a run that opened its own in the same second.** It waits for the next second.
- **A stopped run no longer deletes expired repos from the quarantine.** A run stopped by the runaway caps or by an `n` at the prompt used to delete them first.
- **A disk at or under the critical free-space threshold counts as full pressure even when `PRESSURE_CRIT_*` is set above `PRESSURE_RELAX_*`.**
- **A typo in `MAX_PRUNE_COUNT`, `MAX_PRUNE_GB`, a `RATCHET_*` setting, `DISK_AWARE` or `QUARANTINE` stops the run with exit `2`.** It used to turn a check off without a word, and a `QUARANTINE` typo deleted repos outright.
- **rad-prune finds `keep.txt`, `deny.txt` and the quarantine when `AUDIT_DIR` or `RAD_HOME` is a relative path.** It used to look for them under `/`, so the keep list read as empty and repos on it could be pruned.
- **A run by hand and a run from cron no longer drop each other's cache when they start bash from different paths or run with a different `HOME`.** Each used to read every repo again, as on a first run.
- **An unexpected failure always exits `1`.** It used to pass on the failed command's exit code, which could look like exit `3` or `5`.
- **rad-prune keeps working once `rad` drops `rad self --nid`.** rad 1.10 deprecates the flag.

### Security

- **A stranger can no longer get a repo pruned as a media dump by opening a patch or issue on it.** The media rule (F) now counts only comments and patches the delegates signed.
- **Only a repo's real delegates count as its delegates.** An identity merely named in its identity document, such as in the description, used to count as one, so the media rule (F) counted that identity's uploads as the repo's own.
- **A line break in a repo's description can no longer get another repo pruned.** `rad ls` printed it as is, so the text after it read as another repo's row.
- **Control characters in a repo's name or description no longer reach the terminal.** An escape sequence there could change what the plan showed.

## [0.7.0] - 2026-09-10

### Upgrading

Replace the script. Nothing else has to change.

### Changed

- **The license is Apache 2.0 from this release on.** Use it, fork it, vendor it, run it commercially.
- **A run says where it writes.** The output header names the audit directory next to the home it read, so the plan, the per-run log and the quarantine can be found without waiting for the run to end.
- **A prune that quarantined something says how to get the disk back.** Quarantined repos still occupy disk, so the closing lines name the command that deletes them now, and say that it empties what earlier runs left in there too.
- **The repos the media rule could not judge are named, not just counted.** Any run that gets as far as a plan writes them to `last-run/media-unjudged.tsv`, beside the other evidence files, so the warning's count is something you can go and look at.

### Fixed

- **`--apply` reports its progress too.** 0.6.0 gave every scanning phase a progress line but left the pruning stage silent, so a large plan announced how many repos it was about to take and then said nothing for minutes, which reads like a hang. It now shows repos pruned, the share of the plan done and the time left while it unseeds, blocks and removes each one.
- **A run that could not read a single repo date no longer reports an empty plan.** Every rule needs a repo's age, so a run that could not read any dates skips every repo, and it used to print `prune 0 repos` and exit cleanly over a seed it had in fact read nothing from. It now stops and breaks down what it could not read. `MAX_SCAN_FAIL_PCT` (default=10%) is the failsafe that sets how much of a storage may be unreadable before that happens.
- **A phase no longer reports repos it never read.** It closes with `activity: 0 of 12000 repos` where it used to close with its own total whatever it had actually read.
- **The per-repo workers no longer need `bash` on `PATH`.** They run under the same shell as the script. On a `PATH` without `bash`, which is easy to build by hand for a NixOS or systemd wrapper, every worker used to die while each phase reported repos nothing had read.
- **A command missing from `PATH` is named before the run reads anything.** `rad`, `git`, `jq`, `awk` and the coreutils the rules call are all checked up front. A missing `git` used to fail once per repo, quietly, and the run then blamed storage it could not read.
- **`quarantine restore` stops when a command it needs is missing.** It is checked against the shorter list of commands the quarantine verbs actually use. A missing `dirname` used to put the repo back on disk, warn that it could not write the keep file, and carry on, leaving the next run free to prune it again.

## [0.6.0] - 2026-08-22

### Upgrading

The script is called `rad-prune` now, not `radicle-seed-prune`, so the download URL and the file it lands in have both changed. Nothing else has to change: put it anywhere on `PATH` and `rad prune` runs it. A cron job that names the old path keeps working as long as you leave that file where it is. If you install the new name instead, edit the cron job you already have rather than adding the README's new one beside it, or the job runs twice.

### Added

- **A run says how far it has progressed.** Each phase that walks repos keeps a line in the terminal with the repos read so far, the share of the phase done and the time left, and closes with what that phase cost. Until now a run on a large seed printed nothing for minutes at a stretch, so there was no telling a slow walk from a hung one. Where the output is a log or a pipe rather than a terminal, the same reading is printed as an ordinary line every 60 seconds; that cadence is `PROGRESS_SECS`, and `PROGRESS_SECS=0` turns off progress reporting entirely.

### Changed

- **`rad prune` runs it.** The script is called `rad-prune`, and `rad` runs anything on `PATH` named that way as one of its own subcommands, so the whole tool can be typed as though heartwood shipped it.

## [0.5.1] - 2026-08-13

### Changed

- **Rule F may now take the last copy this seed knows of.** `MEDIA_MIN_SEEDS` defaults to `0`, not `1`: a media dump no other node announces is pruned rather than kept and listed under `# review:`. The old floor made "make sure nobody else seeds it" the way to keep a dump. `MEDIA_MIN_SEEDS=1` restores it, review list included; pruning still quarantines for 7 days first.

## [0.5.0] - 2026-08-13

Adds content moderation next to disk reclaim: rule E (link farms), rule F (media dumps) and rule G (parasite peers). Pruned repos are quarantined for 7 days instead of deleted, the plan folds repetitive rows, an unattended run measures its plan against its own history, and `RULES` is one switch over all rules.

### Upgrading

Replace the script. Nothing else has to change.

Rules E, F and G are new and on by default, so read one dry run before you apply this release. Three names changed, and each matters only if you had reached for it:

| If you | Use instead |
| ------------------------------------------------------ | ------------------------------------- |
| set `SPAM_MIN_FAMILY`                                    | `SPAM_MIN_BATCH`                      |
| set `LINK_SCAN=0`, `MEDIA_SCAN=0` or `PARASITE_SCAN=0`   | a `RULES` without `E`, `F` or `G`     |
| grep plans or audit logs for `spam-family`               | `spam-batch`                          |

### Added

- **Rule E, link farms.** Prunes repos published to carry links rather than code: a domain counts as spam when many repos link to it but almost none from their own code, and a repo is pruned when its own delegates link it to `LINK_MIN_SCORE` such domains ([details](./README.md#rule-e-link-farms)). Both counts are recomputed from storage every run, so there is no blocklist to maintain, and like `spam-batch` it defaults to a seed floor of `0` (`LINK_MIN_SEEDS=1` restores a floor).

- **Rule F, media dumps.** Prunes repos that are video, images or audio with almost no text, judged by file content rather than file names, and a second verdict, `media-batch`, catches the same media published across many repos ([details](./README.md#rule-f-media-dumps)). It keeps the last copy we know of by default, and it adds about 4 minutes to an uncached dry run on an 11k-repo seed.

- **Rule G, parasite peers.** Names peers whose identical file sits in many repos they do not own, and prunes nothing ([details](./README.md#rule-g-parasite-peers)). Blocking takes two opt-ins: the plan prints the `rad block` line for each named peer, `--block-peers` raises a prompt per peer, and `--block-peers --yes` answers those prompts in an unattended run (with neither a terminal nor `--yes` it blocks nobody and prints the commands).

- **Pruned repos are quarantined, not deleted.** A pruned repo is unseeded, blocked, then moved to `$AUDIT_DIR/quarantine/<rid>`, and is deleted for real `QUARANTINE_DAYS` (7) after it arrived there. `QUARANTINE=0` restores outright deletion.

- **Quarantine subcommands and a keep list.** Four verbs manage what past runs pruned:

  - `quarantine list` shows what is held, how long it has been held, and when each entry goes;
  - `quarantine restore <rid>...` puts the repo back in storage, clears the block, re-seeds it, and adds it to the keep list;
  - `quarantine delete <rid>...` (or `--all`) removes one entry now, without waiting for the window;
  - `quarantine purge` removes everything already past its window.

  The keep list is `$AUDIT_DIR/keep.txt`, one repo id per line and editable by hand, and a repo on it is excluded from every rule.

- **The plan says when the disk actually comes back.** With the quarantine on, the plan says `prune N repos, X GiB out of storage but still on disk for 7d, until a later --apply run deletes them` rather than `reclaim X GiB`, matching the completion line. `QUARANTINE=0` puts the reclaim wording back.

- **An unattended run refuses a plan far bigger than its own past runs.** It aborts when the plan is more than `RATCHET_FACTOR` (3) times the median of the last `RATCHET_RUNS` (8) applied runs, read from the history log; fewer than three past runs is not treated as a baseline. `--force` or an interactive confirmation gets past it.

- **A creation-date ledger, `$RAD_HOME/prune-audit/first-seen.tsv`.** The tool records when it first saw each repo, on every run including dry ones, and rules D, E and F age a repo by the older of that and its oldest ref date, so pushed dates alone cannot keep a repo forever young. Without the ledger it runs on ref dates alone, and says so.

- **Repeat runs reuse what they read last time.** Rules E, F and G keep what they read out of each repo in `$AUDIT_DIR/cache` and reuse it for any repo whose refs and size are both unchanged, which is nearly all of them week to week. On an 11,200-repo seed that took a run from about 10 minutes to about 3. The cache is dropped whole when the script changes, or when any setting it reads changes value; `CACHE=0` turns it off.

- **The plan reports what the run left alone**: a `# skipped:` line counting the repos that were unreadable, written too recently, or had no readable refs.

- **`--help` is a real help screen.** It lists the options, the quarantine verbs and the paths the run resolved, instead of dumping the script's several-hundred-line header comment. `quarantine --help` answers too, and an unknown verb names itself and exits `2`.

- **A `NEAR` column marks the rows that only just qualified.** It names any threshold a repo cleared by less than `NEAR_PCT` (20%), so a reviewer can see which verdicts rest on a hair rather than reading every row as equally certain. The summary under the plan counts them, and the audit log gains a matching final column.

### Changed

- **`spam-family` is now `spam-batch`**, and `SPAM_MIN_FAMILY` is now `SPAM_MIN_BATCH`. Same rule, plainer name.

- **Rule D measures age from a repo's creation, not its last activity.** Spam that comments on its own repos no longer resets the clock; rules A, B and C still measure last activity.

- **The plan's `AGE(d)` column shows the age the matching rule measured**: days since last activity for rules A to C, days since creation for D, E and F. Each per-run audit log gains a final `age_from_unix` column; the existing columns keep their positions.

- **Repetitive plan rows fold into summary lines.** Corpus verdicts (`spam-batch`, `link-farm`, `media-batch`) fold to one line per group once the group reaches `PLAN_COLLAPSE_ROWS` (20), while verdicts on a single repo are always listed in full; `PLAN_FULL=1` lists everything, including the evidence tables above the plan, which otherwise show only their top few entries.

- **Every run writes what it decided, untrimmed, to `$AUDIT_DIR/last-run/`.** The terminal folds repetitive rows and cuts each evidence table to its top few, so the full plan, the rule D templates, the rule E domains, the dumps rule F kept, the peers rule G accused and everything unreadable now go to six files, on dry runs as much as on applying ones. The run prints where they are, each file opens with a line naming the run that wrote it, and the next run replaces the set whole.

- **`RULES=ABCDEFG`, one switch for every rule.** A letter absent from `RULES` disables that rule, and a repo it would have claimed falls through to the next rule; `RULES=`, set but empty, means no rules at all. This replaces the per-rule switches `LINK_SCAN`, `MEDIA_SCAN` and `PARASITE_SCAN`, which are gone.

- **`du` now runs across all workers** instead of serially over the whole storage tree.

- **`history.log` spells the quarantine column `quarantine=on|off`** rather than `quarantined=0|1`.

### Fixed

- **Restoring a repo now clears its block on every rad version.** `quarantine restore` and the documented manual undo used `rad unblock`, which older heartwood does not have, so on those nodes the repo came back on disk and stayed blocked. Both now use `rad unseed`, which deletes the policy row whatever it holds.

- **A seed with thousands of spam batches or spam domains no longer dies while printing its own summary.** The `sort | head -5` pipelines that print the top five tripped the error trap via `SIGPIPE` under `pipefail`; the truncation now happens in the `awk` that formats the line.

- **Numbers no longer follow the operator's locale.** The script now runs under `LC_ALL=C`: under a comma locale mawk printed one internal value as `2,52e+10`, which the next awk parsed as `2`, silently zeroing the disk-pressure maths.

- **Rule E's canonical pass is filtered and capped like its other pass.** It used to spend the repo's read budget on commit and tree bytes and count links in commit messages the other pass never sees, so the two passes disagreed about what a repo's own code links to.

## [0.4.0] - 2026-08-11

Adds rule D (mass-generated spam repos), splits rule A by how strong its evidence is, lets the two conclusive spam verdicts take the last copy we know of, and fixes a parsing bug that could file a repo under the wrong RID.

### Upgrading

Replace the script. Nothing else has to change.

Rule D is on and adds a `spam-family` block to the plan (`SPAM_MIN_FAMILY=999999` turns it off), and `junk-id` and `spam-family` now default to a seed floor of `0`, meaning they can take the last copy this seed knows of (`JUNK_ID_MIN_SEEDS=1 SPAM_MIN_SEEDS=1` restores the old floor). Read one dry run before you apply this release.

### Added

- **Rule D, spam families.** Prunes bulk-generated repos on corpus evidence: names and descriptions are skeletonised, and a repo is pruned only when its name skeleton carries a random-id slot, at least `SPAM_MIN_FAMILY` repos share that skeleton, and at least `SPAM_DESC_AGREE_PCT`% of them agree on one description skeleton ([details](./README.md#rule-d-spam-batches)). On a real 11,684-repo seed it flags 974 repos in 10 template families and nothing else, in about 0.4s.

- **Two verdicts may now delete the last copy we know of.** `junk-id` and `spam-family` default to a seed count floor of `0`; every other rule keeps its previous floor, and `JUNK_ID_MIN_SEEDS=1 SPAM_MIN_SEEDS=1` restores the old behaviour everywhere.

- **Rule A is now two verdicts, `junk-name` and `junk-id`**, with separate seed floors (`JUNK_MIN_SEEDS` stays 1, the new `JUNK_ID_MIN_SEEDS` defaults to 0). The plan says which one fired.

- **Rule A treats a name that is nothing but a random hex id as disposable** (`0a1b2c3d4e5f`; both letters and digits required, so `12345678` and `facade` are left alone). `JUNK_ID_MIN_LEN=0` disables it.

### Fixed

- **The launch directory can no longer manufacture scan errors.** Started from a directory the running user cannot read, every `find` counted a `Failed to restore initial working directory` error; the script now resolves its paths against the caller's directory and anchors itself at `/`.

- **A repo whose description quotes an RID is no longer filed under the quoted RID.** The `rad ls` parser took the *last* `rad:z...` token on a row; it now takes the first, walks the trailing columns instead of counting fields, and keeps names containing spaces intact.

## [0.3.0] - 2026-08-03

Reliability release: every way the tool could report a confident answer it had not earned is now closed. No pruning rule changed.

### Upgrading

Replace the script. Nothing else has to change.

A dry run can now exit `5`, where it previously only exited `0` or `1`. It means the tool refused to guess and touched nothing.

### Fixed

- **`RAD_HOME` now reaches `rad`.** It was resolved but never exported, so every `rad` call queried the *default* home, left the other-seed count at zero for every repo, and the plan could only ever come out empty.

- **One unreadable repo no longer kills the run.** A live node can delete a storage directory mid-scan, which used to end the whole run; every walk now tolerates it, scan errors are counted and reported, and the affected repos are dropped from the plan.

- **Storage the tool cannot read is an abort, not an empty plan.** Run as the wrong user, it used to finish with `# PLAN: prune 0 repos` and exit `0`; it now stops with exit `1` and names the directory.

- **Failures now say where they happened**: line number, failing command, exit status.

- **A failed deletion is no longer reported as reclaimed disk.** Under `--apply`, each failed `rm` is named and the run warns when fewer repos were deleted than planned; the audit log still lists the plan, not the outcome.

### Added

- **`MAX_SCAN_FAIL_PCT`** (default `10`): abort when more than this share of storage could not be read, instead of reporting a small, plausible-looking plan.

### Changed

- **A blind run aborts (exit 5) instead of reporting "prune 0 repos".** The preflight (node reachable, NID resolvable, routing table non-empty) now runs on dry runs too, not only under `--apply`.

- **Environment variables are documented** in `--help` and the README: `RAD`, `RAD_HOME`, and every threshold. There are no tuning flags; `RAD_HOME` is the variable heartwood itself reads.

- **`--help` prints the full header** rather than a hardcoded line range that drifted out of date.

## [0.2.0] - 2026-07-01

### Added
- `--apply` now scans once, prints the plan, and prompts `[y/N]` before deleting when run in a terminal (it just applies non-interactively, e.g. under cron). A yes at the prompt also skips the runaway caps.
- `--yes` (`-y`) to skip the confirmation prompt.
- `--version` flag, and the version is now shown in the run header.
- `JOBS` environment variable to control the number of parallel workers.
- A test suite under `tests/` (`bash tests/run.sh`): a hermetic fixture (temp Radicle home, a `rad` stub, real bare git repos) that never touches the real node.

### Changed
- Big scan speedup, measured **~22x faster** on a ~7,900-repo seed (5m38s -> ~15s): one batched `du`, one `find` for mtimes, a parallelized `git` activity pass, and bash maps in the classify loop.
- Default parallelism is `cores - 1`, leaving a core for the running node; override with `JOBS`.
- Renamed `--restart` to `--restart-node`.

## [0.1.0] - 2026-06-28

### Added
- Initial release. Reclaim disk on a Radicle (heartwood) seed by pruning low-value repos.
- Dry-run by default; `--apply` to execute (`unseed` + `block` + delete storage, in that order).
- Selection rules: **A** junk-named & abandoned, **B** stale size outlier, **C** long-abandoned, each gated on a minimum other-seed count.
- Exclusions: pinned, private, and own repos, plus freshly-written and unknown-age repos.
- Activity signal reads the newest `creatordate` across all refs, so commits, issues, patches, comments, and reactions all count.
- Disk-pressure adaptivity: thresholds self-tighten as free disk falls, with hard floors that never scale.
- Runaway caps, an apply-time preflight, and a per-run audit trail (`prune-<ts>.log` + `history.log`) under `$RAD_HOME/prune-audit/`.
- `--restart` to flush the node inventory after a large run; a weekly `cron.d` recipe.
- PolyForm Noncommercial 1.0.0 license.
