# Decision 0004: Trunk (`main`) + Release-Candidate (`rc-*`) Branch Strategy

## Status

Accepted — 2026-07-19

## Context

`wevo` and [`wevo-space`](https://www.github.com/h1d3mun3/wevo-space) are
separate repositories that are nonetheless released in a coordinated way (see
[Decision 0002](0002-versioning-and-backward-compatibility.md): both currently
carry the same `2.0.0` marketing version on their respective `rc-2.0.0`
branches — `main` in this repository is still at `MARKETING_VERSION = 1.0`
pending that release). Both repositories have independently converged on the
same branching shape, but that shape had never been written down as a
decision — it only existed implicitly in `create-rc-branch.yml` and in the
branch-protection rulesets referenced by
[Decision 0003](0003-all-prs-use-merge-commits.md). This entry formalizes it,
mirroring the companion decision in `wevo-space`'s `docs/decisions/`.

Today, in both repos:

- `main` is the trunk: the default integration branch for topic-branch PRs,
  and the only branch that stays alive indefinitely.
- `rc-X.Y.Z` branches (e.g. `rc-2.0.0`) are per-release candidate branches,
  created explicitly and manually via the `create-rc-branch.yml`
  `workflow_dispatch` workflow. That workflow validates the version input
  against `^[0-9]+\.[0-9]+\.[0-9]+$`, branches from the ref it is run on, bumps
  `MARKETING_VERSION` in `Wevo.xcodeproj/project.pbxproj`, commits that bump as
  `github-actions[bot]`, and pushes the new `rc-*` branch. No other process
  bumps the marketing version.
- Because `rc-*` branches are long-lived rather than disposable, they need
  `main`'s ongoing changes synced into them while they stabilize ("merge
  `main` into `rc-*`"), and are themselves merged back into `main` to actually
  ship ("merge `rc-*` into `main`"). Decision 0003 exists specifically because
  one of these sync merges (PR #108, here) was squashed and broke ancestry —
  this branch shape is the reason that class of PR exists at all.
- All of the PR types above — topic branch → `main`/`rc-*`, `main` → `rc-*`
  sync, `rc-*` → `main` release — merge via merge commit only,
  repository-wide (Decision 0003). This decision does not revisit that; it
  documents the branch topology that Decision 0003's merge-method rule
  protects.
- Branch protection is enforced by standing rulesets, not per-branch ones: a
  "Protect RC branches" ruleset targets `refs/heads/rc-*`, and a separate
  "Protect main branch" ruleset protects `main`. Both currently allow only the
  `merge` method (Decision 0003).
- `wevo` currently has **no CI workflow at all** — `.github/workflows/`
  contains only `create-rc-branch.yml`. Nothing runs tests on PRs into
  `wevo`'s `main` or `rc-*`, unlike `wevo-space`, whose `ci.yml` runs `swift
  test` on every PR against both branch types. `wevo`'s branch protection
  therefore cannot require a status check the way `wevo-space`'s can, because
  there is no check to require.

## Decision

We adopt, as an explicit and shared convention across `wevo` and
`wevo-space`, the following branch model:

1. **`main` is the trunk.** All ordinary feature/fix work targets `main` via
   topic-branch PRs. `main` is expected to be at development quality at all
   times, not necessarily release quality.
2. **`rc-X.Y.Z` is the only branch type a release is cut from.** `main` is
   never released directly; a release always means an `rc-*` branch, created
   from `create-rc-branch.yml`, is eventually merged into `main`.
3. **The marketing/package version bump happens exactly once per release
   train, at `rc-*`-branch-creation time**, and nowhere else. Per Decision
   0002, this bump is a label only — it carries no compatibility guarantee by
   itself.
4. **Bidirectional sync between `main` and an open `rc-*` branch is routine,
   not exceptional**, for as long as the `rc-*` branch is open. Both sync
   directions and the eventual release merge are ordinary PRs and are
   therefore already bound by Decision 0003's merge-commit-only rule — that is
   what keeps repeated syncs from re-surfacing resolved conflicts.
5. **This branch shape is shared identically by `wevo` and `wevo-space`**,
   each maintaining it independently via its own `create-rc-branch.yml`.
   Sharing the shape does not imply the two repos' `rc-*` branches must be
   released in lockstep — only that the mechanism and vocabulary (`main`,
   `rc-X.Y.Z`, sync, release) mean the same thing in both. See the companion
   Decision 0004 in `wevo-space`'s `docs/decisions/`.

## Consequences

- The branch topology is now documented, not just implicit in workflow YAML —
  future changes to `create-rc-branch.yml` or the branch-protection rulesets
  should be checked against this decision, and a superseding entry written if
  the shape itself changes (e.g. allowing releases directly from `main`, or
  dropping the sync requirement).
- This decision defines *when* a marketing version bump happens (rc-branch
  creation) but, consistent with Decision 0002, still says nothing about when
  a *protocol* version (`/v1`, `signatureVersion`) should change — that
  remains a separate, per-change decision.
- **Gap, not addressed here**: `wevo` has no CI workflow, so PRs into
  `wevo`'s `main` and `rc-*` are merged with no automated test gate at all,
  unlike `wevo-space`. Adding one is a natural follow-up but is out of scope
  for this decision.
- **Out of scope, tracked separately**: whether/how to automatically trigger
  builds (e.g. `wevo-space`'s `docker-build.yml` image build, currently
  manual-only via `workflow_dispatch`) off branch events such as a `main`
  merge or an `rc-*` release. This decision fixes the branch shape those
  triggers would hang off of, but does not itself decide the trigger.
- This entry currently exists only on the `rc-2.0.0` branch, alongside
  Decisions 0001–0003, which are also not yet on `main`. It reaches `main`
  when `rc-2.0.0` is released (Decision 0002's rule 2), consistent with the
  branch model this decision itself describes.
- `rc-*` branch cleanup/retirement after a release ships is not addressed by
  this decision.
