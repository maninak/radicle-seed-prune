# Changelog

All notable changes to this project are documented here. The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

Adds rule D, which catches mass-generated spam repos, and fixes a metadata parsing bug that could file a repo under the wrong RID.

**Upgrading:** replace the script, change nothing else. Rule D is on by default and will add a `spam-family` block to your next plan, so read the preview before applying. `SPAM_MIN_FAMILY=999999` turns it off.

### Added

- **Rule D, spam families.** Bulk-generated repos give nothing away one at a time and are obvious in aggregate, so this rule is decided by the corpus, never by a single repo. Names and descriptions are skeletonised (digit runs to `#`, random-id tokens to `%`), and a repo is pruned only when its name skeleton carries a random-id slot, at least `SPAM_MIN_FAMILY` repos share that skeleton, and at least `SPAM_DESC_AGREE_PCT`% of them agree on one description skeleton. Demanding those two independent signals is what keeps false positives near zero: on a real 11,684-repo seed it flags 974 repos in 10 template families and nothing else, leaving large legitimate mirror imports alone because each of their repos carries its own real description. Costs about 0.4s on 11.7k repos. [Full rationale, and the two things it deliberately does not do](./README.md#rule-d-spam-families).

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

[Unreleased]: https://github.com/maninak/radicle-seed-prune/compare/v0.3.0...HEAD [0.3.0]: https://github.com/maninak/radicle-seed-prune/compare/v0.2.0...v0.3.0 [0.2.0]: https://github.com/maninak/radicle-seed-prune/compare/v0.1.0...v0.2.0 [0.1.0]: https://github.com/maninak/radicle-seed-prune/releases/tag/v0.1.0
