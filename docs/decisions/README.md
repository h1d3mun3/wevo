# Decisions

This directory records significant design and architecture decisions for the Wevo
client — things worth writing down so future readers know *why*, not just *what*.
Each entry uses a simple format: Status, Context, Decision, Consequences.

Decisions that affect the wire protocol or server compatibility must be mirrored by a
matching entry in the [`wevo-space`](https://www.github.com/h1d3mun3/wevo-space)
server repository's `docs/decisions/`, cross-referencing each other by number and
title.

## Index

| # | Title | Status |
|---|-------|--------|
| [0001](0001-forward-and-backward-compatibility-requirement.md) | Forward and Backward Compatibility Are a Hard Requirement | Accepted |
| [0002](0002-versioning-and-backward-compatibility.md) | Versioning and Backward Compatibility Policy | Accepted |
| [0003](0003-all-prs-use-merge-commits.md) | All Pull Requests Merge via Merge Commit | Accepted |
| [0004](0004-trunk-and-release-candidate-branches.md) | Trunk (`main`) + Release-Candidate (`rc-*`) Branch Strategy | Accepted |
| [0005](0005-signature-scheme-version-must-be-signed.md) | The Signature Scheme Version Must Be Covered by the Signature (v2+) | Accepted |

## Adding a new decision

1. Copy the format of an existing entry.
2. Number sequentially (`000N-kebab-case-title.md`).
3. If the decision affects the client-server protocol or signed message format,
   add a matching entry in `wevo-space`'s `docs/decisions/` and link the two.
4. Add a row to the index table above.
