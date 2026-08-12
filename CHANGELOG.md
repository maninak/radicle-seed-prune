# Changelog

All notable changes to this project are documented here. The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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

- **The plan says when the disk actually comes back.** With the quarantine on, the plan says `prune N repos, X GiB out of storage but still on disk for 7d, until a later run deletes them` rather than `reclaim X GiB`, matching the completion line. `QUARANTINE=0` puts the reclaim wording back.

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
