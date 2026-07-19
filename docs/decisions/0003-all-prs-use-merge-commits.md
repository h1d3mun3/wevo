# Decision 0003: All Pull Requests Merge via Merge Commit

## Status

Accepted — 2026-07-19

## Context

This project uses long-lived branches — `main` (trunk) and per-release `rc-*`
candidates — that are synced in both directions: `main` is periodically merged
*into* an `rc-*` branch, and an `rc-*` branch is eventually merged *into* `main`
to release. Feature and fix work lands on those branches through topic-branch PRs.

Two of the "merge `main` into `rc-2.0.0`" sync PRs (#46 in
[`wevo-space`](https://www.github.com/h1d3mun3/wevo-space) and #108 here) were
**squash-merged**. Squashing a merge collapses it into a single commit with only
one parent, discarding the link to the branch that was merged in. As a result
`rc-2.0.0` no longer recorded that it already contained `main`'s history, so the
*next* sync re-derived the merge from the old divergence point and re-surfaced
conflicts that had already been resolved — the phantom-conflict problem that
forced a second, hand-resolved "merge main into rc" PR.

The squash was not a free choice: the "Protect RC branches" repository ruleset
(`refs/heads/rc-*`) had `pull_request.allowed_merge_methods = ["squash"]`, so
squash was the *only* method GitHub offered when merging into an `rc-*` branch.
Meanwhile the "Protect main branch" ruleset allowed only `["merge"]`, which is
why release PRs (`rc → main`, e.g. `wevo` #106, `wevo-space` #43/#39) were
correctly merge commits and never suffered this. The root cause was therefore the
RC ruleset forcing squash on branch-to-branch syncs.

The precise rule that avoids the problem is "never squash a merge between two
persistent branches; squash is fine for disposable topic branches." We
considered adopting that split rule, but it requires a per-PR judgement that has
already been gotten wrong, and GitHub cannot enforce a per-target-branch merge
method (the allowed methods are a single repository-wide setting).

## Decision

**Every pull request in this repository is merged with a merge commit.** This is
enforced in two places so the harmful option cannot be chosen by mistake:

- Repository level: squash and rebase merging are disabled (Settings → Pull
  Requests → only "Allow merge commits" is enabled).
- Ruleset level: the "Protect RC branches" ruleset's
  `pull_request.allowed_merge_methods` is changed from `["squash"]` to
  `["merge"]`, matching the already-correct "Protect main branch" ruleset. This
  is the change that actually fixes the incident above.

- This is deliberately the *simple* rule rather than the *minimal* one: a single
  invariant that can never regress into the ancestry-breaking case, at the cost
  of topic-branch commits appearing individually in the target branch's history.
- The same setting is applied to
  [`wevo`](https://www.github.com/h1d3mun3/wevo) and
  [`wevo-space`](https://www.github.com/h1d3mun3/wevo-space); see the companion
  Decision 0003 in the other repository.

## Consequences

- `main ↔ rc-*` syncs and `rc-* → main` releases always preserve both parents, so
  the merge-base relationship stays intact and previously-resolved conflicts do
  not reappear.
- Trunk history includes each topic branch's individual commits rather than one
  squashed commit per PR. Authors who want a tidy single commit should keep their
  topic branch tidy (or self-squash locally before opening the PR); reviewers can
  read a PR as a whole regardless.
- The merge-method configuration (repo setting + RC ruleset
  `allowed_merge_methods`) is now load-bearing. If either is ever re-enabled for
  squash/rebase, this decision is void and the phantom-conflict risk returns —
  change it only via a superseding decision here.
