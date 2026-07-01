# Changelog

All notable changes to this project are documented here. The format is based on
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.2.0] - 2026-07-01

### Added
- `--apply` now scans once, prints the plan, and prompts `[y/N]` before deleting when run in a
  terminal (it just applies non-interactively, e.g. under cron). This is a single-scan
  preview-then-apply, instead of a dry-run followed by a separate `--apply` that scans twice. A yes
  at the prompt also skips the runaway caps (you have already eyeballed the numbers).
- `--yes` (`-y`) to skip the confirmation prompt.
- `--version` flag, and the version is now shown in the run header.
- `JOBS` environment variable to control the number of parallel workers in the activity scan.
- A test suite under `tests/` (`bash tests/run.sh`). It builds a fully isolated, hermetic fixture
  (temp Radicle home, a `rad` stub, real bare git repos) and never touches the real node.

### Changed
- Big scan speedup: the per-repo `du` + `stat` + `git` + `awk`/`grep` calls were replaced by a
  single batched `du`, a single `find` for mtimes, a parallelized `git` activity pass, and bash maps
  plus native regex in the classify loop. Measured **~22x faster** on a ~7,900-repo seed
  (5m38s -> ~15s). The scan is now IO-bound (a single `du` over all storage).
- Default parallelism is `cores - 1`, leaving a core for the running node. Override with `JOBS`.
- Renamed `--restart` to `--restart-node`.

## [0.1.0] - 2026-06-28

### Added
- Initial release. Reclaim disk on a Radicle (heartwood) seed by pruning low-value repos.
- Dry-run by default; `--apply` to execute (`unseed` + `block` + delete storage, in that order).
- Selection rules: **A** junk-named & abandoned, **B** stale size outlier, **C** long-abandoned,
  each gated on a minimum other-seed count so the last network copy is never deleted.
- Exclusions: pinned, private, and own repos, plus freshly-written and unknown-age repos.
- Activity signal reads the newest `creatordate` across all refs, so new commits, issues, patches,
  comments, and reactions all count.
- Disk-pressure adaptivity: thresholds self-tighten from relaxed toward aggressive as free disk
  falls, with hard safety floors that never scale.
- Runaway caps, an apply-time preflight (aborts on a down node / unreadable exclusions), and a
  per-run audit trail (`prune-<ts>.log` + `history.log`) under `$RAD_HOME/prune-audit/`.
- `--restart` to flush the node inventory after a large run; a weekly `cron.d` recipe.
- PolyForm Noncommercial 1.0.0 license.

[Unreleased]: https://github.com/maninak/radicle-seed-prune/compare/v0.2.0...HEAD
[0.2.0]: https://github.com/maninak/radicle-seed-prune/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/maninak/radicle-seed-prune/releases/tag/v0.1.0
