# Contributing

## Where to talk

[**#radicle-seed-prune** on the Radicle Zulip](https://radicle.zulipchat.com/#narrow/channel/624837-radicle-seed-prune) takes questions, ideas, tuning advice and false positives. Reading it needs no account; posting needs a free Zulip login. Releases are announced in [#Announcements](https://radicle.zulipchat.com/#narrow/channel/409174-Announcements/topic/radicle-seed-prune).

Issues and patches belong on Radicle, at [`rad:zxvTkxzouwrYFwycnsctrMT3iM2E`](https://app.radicle.at/nodes/seed.radicle.at/rad:zxvTkxzouwrYFwycnsctrMT3iM2E). GitHub is a mirror for downloads and releases: its issue tracker, wiki and pull requests are all turned off there.

## Reporting a repo the tool should not have pruned

Restore it first. Inside the quarantine window, 7 days by default, nothing is lost:

```sh
radicle-seed-prune quarantine restore <rid>
```

`restore` moves the repo back into storage, clears the block, re-seeds it, and adds it to `keep.txt`, so no later run touches that repo again.

Then post in Zulip with:

- the repo id, and the rule that caught it (the `reason` column)
- the version, from `radicle-seed-prune --version`
- that repo's row from `$RAD_HOME/prune-audit/last-run/plan.tsv`
- for rules D, E, F and G, the matching rows from the evidence file beside it: `spam-batches.tsv`, `spam-domains.tsv`, `media-review.tsv`, `parasite-peers.tsv`. Those rows are what the rule decided on, and without them a tuning can only be guessed at.

Spam that every rule missed is as welcome as a false positive: send the repo id, and what marks it as junk/spam/abuse to your eye.

## Sending code

```sh
rad clone rad:zxvTkxzouwrYFwycnsctrMT3iM2E
git checkout -b my-change
git push rad HEAD:refs/patches
```

Before you push:

- Run `tests/run.sh`, and do not send the patch until every section of it passes. While writing, `tests/run.sh -k <regex>` runs a single section in seconds where the whole suite takes minutes.
- Add a fixture for any rule you add or change, one that goes red when that rule breaks. Prove that it does: flip the value the fixture asserts, watch the test fail, then restore the value. A rule that deletes nothing in any test is untested.
- Write for the reader, ahead of both brevity and cleverness, because the only thing between a subtle bug and mass deletion of other people's data is a human reading a rule and seeing that it is wrong. Prefer the obvious construct over the short one, and a named variable over a nested expression. One rule, one delimited block, with a comment saying what evidence that rule acts on and why the evidence is enough to delete on. Every threshold is a named variable at the top of the script, carrying its unit and its why.
