# Changelog

All notable changes to this project are documented here. The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

Adds two rules: E catches spam by the address a repo sends traffic to, F catches repos used as file hosting for video and images. Rule D now measures age from when a repo was created instead of from its last activity, and the `spam-family` verdict is renamed to `spam-batch`.

**Upgrading:** replace the script, change nothing else. Rules E and F are new and on by default, so read the preview before applying. If you grep plans or audit logs for `spam-family`, change it to `spam-batch`.

### Added

- **Rule E, link farms.** A link farm is a repo published to carry links rather than code. The tool collects every hostname mentioned anywhere in every repo, folds each to its registrable domain, and calls a domain spam when many repos link to it but almost none of their own code does. A repo is pruned when its own delegates link it to `LINK_MIN_SCORE` such domains; a stranger opening spam issues on your repo cannot get it deleted. Both counts are recomputed from storage every run, so there is no blocklist to maintain and registering new domains buys a spammer nothing. `LINK_SCAN=0` turns the rule off. Like `spam-batch`, `link-farm` defaults to a seed floor of `0` and so may delete a repo no other node we know of is seeding; `LINK_MIN_SEEDS=1` restores a floor. [How it works, and what it deliberately does not do](./README.md#rule-e-link-farms).

- **Rule F, media dumps.** A media dump is a repo whose files are video, images or audio with no project around them: Radicle storage is for collaborating on code, and a repo holding one `.mp4` and nothing else is using the seed as free file hosting. A repo is pruned when it carries at least `MEDIA_MIN_BYTES` of media and everything that is *not* media adds up to under `MEDIA_TEXT_MAX_BYTES`. That text budget is what tells a dump from a real repo that holds media: a game or a documented photo archive has a README, a licence or a build file and clears it many times over.

  What a file *is* decides, not what it is called. Anything the extension lists do not recognise has its first 16 bytes read and matched against media signatures, so renaming a video to `.dat` does not hide it; a file matching nothing counts as text and spares the repo. Archives count as media, since zipping a video would otherwise be a one-command evasion.

  Only the repo's own content counts: its canonical refs plus the namespaces of the delegates named in `refs/rad/id`. The delegates' own issue attachments therefore count, across a COB's whole history rather than just its newest comment, while a stranger's push can never put somebody else's repo in the plan. Blobs a stranger also holds are subtracted, except on the canonical branches and tags, which only a delegate can move: a peer replicating a repo mirrors those branches, and subtracting on that would erase the project and leave a dump-shaped remainder.

  A token README defeats the budget, and nothing about one repo can tell it from a real project's README. So a second verdict, `media-batch`, prunes a repo whose media `MEDIA_MIN_BATCH` (5) or more other repos hold byte for byte, under the wider `MEDIA_TEXT_CEIL_BYTES` budget: publishing the same files across many repos is evidence no single repo can fake. Whoever held a file first is left out of its batch, so reposting somebody's photos into five repos of your own cannot put their repo in the plan.

  Unlike the other two spam verdicts, rule F keeps the last copy we know of by default, and prints what that spared under `# review:` so the floor cannot become a permanent hiding place. A repo it cannot read in full is left unjudged rather than judged on a fragment, and counted in a warning line: that covers a repo over `MEDIA_MAX_REFS` (10000) refs, whose peers would cost minutes to walk, and one whose listing dies part-way.

  Expect a slower run. Rule F lists every file of every repo, which on an 11,151-repo seed takes about 4 minutes of a 9-minute dry run with 5 workers, roughly what rule E costs. `MEDIA_SCAN=0` turns the rule off. [How it works, and what it deliberately does not do](./README.md#rule-f-media-dumps).

- **A creation-date ledger, `$RAD_HOME/prune-audit/first-seen.tsv`.** Every date inside a repo is set by whoever pushed it, so force-pushing fresh dates onto every ref would renew rules D, E and F indefinitely. The tool now records when it first saw each repo, on every run including dry ones, and takes the older of that and the repo's oldest ref date. Nothing outside the seed can reach the ledger. Without it the tool still runs, on ref dates alone, and says so.

- **The plan reports what the run left alone**, as a `# skipped:` line counting the repos that were unreadable, written too recently, or had no readable refs. These were previously absent with no explanation.

### Changed

- **`spam-family` is now `spam-batch`** and `SPAM_MIN_FAMILY` is now `SPAM_MIN_BATCH`. Same rule, plainer name.

- **Rule D measures age from a repo's creation, not its last activity.** The spam wave this was written against appends a comment to its own repos every few days, which resets a last-activity clock. On a real seed that spared the whole wave: repos six days into a seven-day window, missed by one day, every day. Rules A, B and C still measure last activity, because for a legitimate repo being touched is exactly what a staleness rule should notice.

- **The plan's `AGE(d)` column shows the age the matching rule measured**: days since last activity for rules A to C, days since creation for D and E. A `spam-batch` repo touched yesterday used to print `1` next to a 7-day minimum, which read as a bug rather than as the verdict it is. Each per-run audit log gains a final `age_from_unix` column carrying the same date; the existing columns keep their positions.

## [0.4.0] - 2026-08-11

Adds rule D, which catches mass-generated spam repos, splits rule A by how strong its evidence is, lets the two conclusive spam verdicts take the last copy we know of, and fixes a metadata parsing bug that could file a repo under the wrong RID.

**Upgrading:** replace the script, change nothing else. Two defaults are more aggressive than 0.3.0, so read the preview before applying. Rule D is on and will add a `spam-family` block to your plan (`SPAM_MIN_FAMILY=999999` turns it off), and the `junk-id` and `spam-family` verdicts now default to a seed floor of `0`, so they may delete a repo no other node we know of is seeding (`JUNK_ID_MIN_SEEDS=1 SPAM_MIN_SEEDS=1` restores the old floor).

### Added

- **Rule D, spam families.** Bulk-generated repos give nothing away one at a time and are obvious in aggregate, so this rule is decided by the corpus, never by a single repo. Names and descriptions are skeletonised (digit runs to `#`, random-id tokens to `%`), and a repo is pruned only when its name skeleton carries a random-id slot, at least `SPAM_MIN_FAMILY` repos share that skeleton, and at least `SPAM_DESC_AGREE_PCT`% of them agree on one description skeleton. Two independent signals are required, the name shape and the description: on a real 11,684-repo seed the rule flags 974 repos in 10 template families and nothing else, leaving large legitimate mirror imports alone because each of their repos carries its own real description. Costs about 0.4s on 11.7k repos. [Full rationale, and the two evidence choices behind it](./README.md#rule-d-spam-batches).

- **Two verdicts may now delete the last copy we know of.** `junk-id` and `spam-family` default to a seed count floor of `0`; every other rule keeps its previous floor. "Other seeds" counts the nodes our routing table says announce a repo, which is not proof a copy exists elsewhere, so the floor is dropped only where the evidence is conclusive: for machine-generated bulk, "nobody else seeds it" measures worthlessness rather than rarity. A disposable *word* in a name is a guess, and a large or long-abandoned *unique* repo is what a seed exists to preserve, so `junk-name`, `size` and `stale` are unchanged. `JUNK_ID_MIN_SEEDS=1 SPAM_MIN_SEEDS=1` restores the old behaviour everywhere. Measured on a real 11,685-repo seed this currently changes nothing: every offending repo there has at least 2 other seeds, so it is future-proofing rather than a change in today's plan.

- **Rule A is now two verdicts, `junk-name` and `junk-id`**, because a disposable word in a name and a name that is nothing but a random hex id are not equally strong evidence and no longer share a seed floor (`JUNK_MIN_SEEDS` stays 1, the new `JUNK_ID_MIN_SEEDS` defaults to 0). The plan says which one fired.

- **Rule A also treats a name that is nothing but a random hex id as disposable** (`08a25d0f666d`; both letters and digits required, so `12345678` and `facade` are left alone). This is the one shape of generated bulk that rule D cannot see, since such repos carry no description to corroborate with. `JUNK_ID_MIN_LEN=0` disables it.

### Fixed

- **The launch directory can no longer manufacture scan errors.** Started from a directory the running user cannot read (`sudo -u seed` from `/root`, say), every `find` in the scan emitted `Failed to restore initial working directory` and each one counted as a scan error, so a healthy run reported `WARN: 4 scan error(s)` and buried the warnings that mean something. The script now resolves `RAD_HOME`, `STORAGE`, `CONFIG`, `AUDIT_DIR` and a path-qualified `RAD` against the caller's directory and then anchors itself at `/`, so it no longer depends on where it was launched from.

- **A repo whose description quotes an RID is no longer filed under the quoted RID.** The `rad ls` parser took the *last* `rad:z…` token on a row, and descriptions do quote RIDs, so such a repo appeared in the plan as `(?)` while its name landed on an unrelated entry. It now takes the first token, walks the trailing columns instead of counting fields (visibility, head and description are each independently missing on some rows), and keeps names containing spaces intact.

## [0.3.0] - 2026-08-03

Reliability release. Every way the tool could report a confident answer it had not earned is now closed: it either has the data, or it says so and stops. No pruning rule changed, so a plan from a healthy 0.2.0 run is still a valid plan.

**Upgrading:** replace the script, change nothing else. One caveat for automation: a dry-run can now exit `5` (it previously only exited `0` or `1`). Exit 5 means the tool refused to guess, and nothing was touched.

### Fixed

- **`RAD_HOME` now reaches `rad`.** It was resolved but never exported, so every `rad` call queried the *default* home, found nothing, and left the other-seed count at zero for every repo. All three rules gate on that count, so the plan could only ever come out empty. *Looked like:* `# WARN: could not determine our NID`, `excluded: 0 private, 0 own`, then a confident `# PLAN: prune 0 repos`.

- **One unreadable repo no longer kills the run.** A live node can delete a storage directory while `find` and `du` are walking it. That returned non-zero, met `set -e`, and took the whole run down. Every walk in the scan now tolerates it, scan errors are counted and reported, and the affected repos are dropped from the plan instead of being judged on half-read size and age data. *Looked like:* output stops dead at or just before `# scanning N repos (size + activity)...`, exit 1 or 123, no message at all.

- **Storage the tool cannot read is an abort, not an empty plan.** Run as the wrong user (root against a seed-owned home, say), it scanned zero repos and finished with a calm `# PLAN: prune 0 repos` and exit `0`. It now stops with exit `1` and names the directory.

- **Failures now say where they happened.** Any unexpected error prints the line number, the command that failed, and its exit status, instead of exiting mute.

- **A failed deletion is no longer reported as reclaimed disk.** Under `--apply`, each failed `rm` is named, and the run warns when fewer repos were deleted than planned. Both the audit log and the GiB total are written from the plan, so a partially-applied run used to leave a record claiming disk that was never freed. The audit log still lists the plan, not the outcome.

### Added

- **`MAX_SCAN_FAIL_PCT`** (default `10`). If more than this share of storage could not be read, the run aborts instead of reporting a plan. A scan that missed a third of the seed produces a small plan, and a small plan reads like good news, so the number needs a floor under it.

### Changed

- **A blind run aborts (exit 5) instead of reporting "prune 0 repos".** The preflight (node reachable, NID resolvable, routing table non-empty) used to run only under `--apply`. Dry-run now checks it too: with no usable routing table no repo can qualify, so a zero-repo plan was not an all-clear, it was the tool failing quietly.

- **Environment variables are documented** in `--help` and the README: `RAD`, `RAD_HOME`, and every threshold. There are deliberately no tuning flags. `RAD_HOME` is the variable heartwood itself reads, so a run reads like any other `rad` invocation: `RAD_HOME=/var/lib/radicle radicle-seed-prune`.

- **`--help` prints the full header** rather than a hardcoded line range that quietly drifted out of date whenever the header grew.

## [0.2.0] - 2026-07-01

### Added
- `--apply` now scans once, prints the plan, and prompts `[y/N]` before deleting when run in a terminal (it just applies non-interactively, e.g. under cron). This is a single-scan preview-then-apply, instead of a dry-run followed by a separate `--apply` that scans twice. A yes at the prompt also skips the runaway caps (you have already eyeballed the numbers).
- `--yes` (`-y`) to skip the confirmation prompt.
- `--version` flag, and the version is now shown in the run header.
- `JOBS` environment variable to control the number of parallel workers in the activity scan.
- A test suite under `tests/` (`bash tests/run.sh`). It builds a fully isolated, hermetic fixture (temp Radicle home, a `rad` stub, real bare git repos) and never touches the real node.

### Changed
- Big scan speedup: the per-repo `du` + `stat` + `git` + `awk`/`grep` calls were replaced by a single batched `du`, a single `find` for mtimes, a parallelized `git` activity pass, and bash maps plus native regex in the classify loop. Measured **~22x faster** on a ~7,900-repo seed (5m38s -> ~15s). The scan is now IO-bound (a single `du` over all storage).
- Default parallelism is `cores - 1`, leaving a core for the running node. Override with `JOBS`.
- Renamed `--restart` to `--restart-node`.

## [0.1.0] - 2026-06-28

### Added
- Initial release. Reclaim disk on a Radicle (heartwood) seed by pruning low-value repos.
- Dry-run by default; `--apply` to execute (`unseed` + `block` + delete storage, in that order).
- Selection rules: **A** junk-named & abandoned, **B** stale size outlier, **C** long-abandoned, each gated on a minimum other-seed count so the last network copy is never deleted.
- Exclusions: pinned, private, and own repos, plus freshly-written and unknown-age repos.
- Activity signal reads the newest `creatordate` across all refs, so new commits, issues, patches, comments, and reactions all count.
- Disk-pressure adaptivity: thresholds self-tighten from relaxed toward aggressive as free disk falls, with hard safety floors that never scale.
- Runaway caps, an apply-time preflight (aborts on a down node / unreadable exclusions), and a per-run audit trail (`prune-<ts>.log` + `history.log`) under `$RAD_HOME/prune-audit/`.
- `--restart` to flush the node inventory after a large run; a weekly `cron.d` recipe.
- PolyForm Noncommercial 1.0.0 license.

[0.4.0]: https://github.com/maninak/radicle-seed-prune/compare/v0.3.0...v0.4.0 [0.3.0]: https://github.com/maninak/radicle-seed-prune/compare/v0.2.0...v0.3.0 [0.2.0]: https://github.com/maninak/radicle-seed-prune/compare/v0.1.0...v0.2.0 [0.1.0]: https://github.com/maninak/radicle-seed-prune/releases/tag/v0.1.0
