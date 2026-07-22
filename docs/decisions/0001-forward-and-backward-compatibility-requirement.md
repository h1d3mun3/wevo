# Decision 0001: Forward and Backward Compatibility Are a Hard Requirement

## Status

Accepted — 2026-07-18

## Context

`wevo` and its server, `wevo-space`, together implement a decentralized system for
recording and verifying signed proposals/agreements between parties. `wevo` (this
repository) is the client; `wevo-space` is the coordination layer. Critically, `wevo`
has no single, fixed, central `wevo-space` it must talk to — a given `wevo` client
instance may connect to any `wevo-space` deployment (self-hosted, run by a
counterparty, run by a third party), and there is no central authority that owns,
operates, or can force an upgrade schedule on every `wevo-space` deployment or every
`wevo` client in the network.

As a direct consequence, at the requirements level — not as an edge case, but as a
permanent, expected condition of this system — all of the following will happen,
indefinitely, simply because peers upgrade on their own independent schedules:

- This client will need to talk to a `wevo-space` deployment **older** than itself.
- This client will need to talk to a `wevo-space` deployment **newer** than itself.
- A `wevo-space` deployment will be asked to serve a `wevo` client **older** than
  itself.
- A `wevo-space` deployment will be asked to serve a `wevo` client **newer** than
  itself.

This differs from a typical app talking to a single hosted backend the vendor
controls and can force-upgrade, where "forward compatibility" alone (an old client
still working after the vendor ships a new server) is usually sufficient. Here, there
is no privileged "latest" node — every peer is, at any given moment, potentially both
older and newer than whichever peer it happens to be talking to.

## Decision

We treat maintaining **both forward compatibility (this client, when older,
continuing to work correctly against a newer `wevo-space`) and backward compatibility
(this client, when newer, continuing to work correctly against an older
`wevo-space`)** — each as strictly as practically possible — as a hard, ongoing
architectural constraint on `wevo`, not an aspirational goal.

- This constraint applies independently in both directions.
- Exactly how far back (or how far forward) support must extend — i.e., where an
  actual support cutoff eventually gets drawn — is explicitly **out of scope** for
  this decision and is left to future, separate decisions made per version boundary.
  What this decision fixes is the default posture: compatibility is preserved unless
  a specific, documented decision says otherwise.
- Every concrete technical mechanism for achieving this — API route versioning,
  the `signatureVersion` field, decoupling the marketing/package version from
  protocol compatibility, and any future mechanism — is an implementation detail in
  service of this constraint (see [Decision 0002](0002-versioning-and-backward-compatibility.md)
  and later entries in this directory). Those mechanisms may be revised over time;
  this constraint itself should not be relaxed without a conscious, explicit decision
  to do so.

## Consequences

- Any future technical decision or code change that would break compatibility in
  either direction requires its own explicit decision record justifying the break
  and, where the break is intentional, defining what happens to the peers it affects
  (deprecation window, migration path, minimum supported server version, etc.).
  Silently breaking old *or* new peers is not acceptable by default.
- Backward compatibility (this client staying correct against an older `wevo-space`)
  needs the same design attention as forward compatibility, which is easy to neglect
  because new client features are naturally developed and tested against a
  same-version server. Concretely: this client should not assume a `wevo-space` it
  talks to supports capabilities newer than the route/signature version it targets.
- This is the governing principle for this directory: read this decision first, then
  the version-specific technical decisions that implement it. A technical decision
  that only solves one direction (e.g. only decoupling version numbers from
  compatibility signals, without a concrete forward- or backward-compat mechanism) is
  incomplete with respect to this decision and should say so explicitly, as
  [Decision 0002](0002-versioning-and-backward-compatibility.md) currently does.
