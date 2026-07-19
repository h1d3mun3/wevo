# Decision 0005: The Signature Scheme Version Must Be Covered by the Signature (v2+)

## Status

Accepted — 2026-07-19

## Context

Every `Propose` (and its server-side `HashedPropose`) carries a `signatureVersion`
field that governs *how* its signatures are to be interpreted. Version 1 (v1) is
defined as: each operation's signed message is `"<verb>." + proposeId + payloadHash +
signerPublicKey + timestamp` (the creator's `proposed.` message additionally binds the
sorted counterparty keys and `createdAt`), where `<verb>` is one of
`proposed`/`signed`/`honored`/`parted`/`dissolved`.

`signatureVersion` is **not** part of the bytes that get signed. Every signing site
builds the message above with no version term, and every verifier
(`ImportProposeUseCase`, `MergeServerSignaturesIntoLocalProposeUseCase`,
`CheckProposeServerStatusUseCase`) hardcodes the v1 layout and never branches on
`signatureVersion`.

Today this is not exploitable: only v1 exists, so there is exactly one layout a
signature can be interpreted under. The risk is forward-looking. The moment a second
scheme (v2) is introduced with a different signed-message layout, a value that
determines *how to interpret a signature* would be sitting **outside** the signed data.
An attacker could relabel a v2-signed `Propose` as v1 (or vice versa) and a verifier
could be induced to interpret the signature under the wrong layout — a
signature/version confusion. This is the same domain-separation principle behind the
removal of the arbitrary-text signing oracle and the binding of a Propose's content to
its signed hash ([Decision 0001](0001-forward-and-backward-compatibility-requirement.md)
covers the compatibility side; this entry covers the signed-message side).

We cannot fix this by adding `signatureVersion` to the v1 signed message now: doing so
would change the bytes every existing v1 signature was computed over, invalidating all
of them — a backward-compatibility break forbidden by Decisions 0001 and 0002.

## Decision

1. **The v1 signed-message format is frozen.** It MUST NOT change — in particular,
   `signatureVersion` is deliberately *not* retrofitted into v1 signed bytes, because
   that would break every signature already in existence.
2. **Any future scheme version (v2+) MUST include `signatureVersion` in the signed
   byte string** (for example, as a leading `"v2."`-style term or an explicit version
   field within the signed message), so that a signature cryptographically commits to
   the scheme under which it was produced and cannot be reinterpreted under another.
3. **Verifiers, once v2 exists, MUST select the message layout from the record's
   `signatureVersion` and, for v2+, confirm the version embedded in the signed bytes
   matches the record's** — never silently fall back to the v1 layout for a
   v2-labelled record, and never accept a record whose declared version disagrees with
   the signed one.
4. **No code change is made now.** Only v1 exists, so there is nothing to disambiguate
   yet; this decision records the constraint while the gap is understood, so it is
   honored by design when v2 is first drafted rather than discovered afterward.

## Consequences

- The `signatureVersion` field remains a plain, unauthenticated label for as long as
  only v1 exists — safe today, but load-bearing the instant v2 is added, at which point
  rule 2 is mandatory rather than optional.
- Because this constrains the signed message format / wire protocol, a matching entry
  must be added to [`wevo-space`](https://www.github.com/h1d3mun3/wevo-space)'s
  `docs/decisions/`, cross-referencing this one (per this directory's README).
- Introducing v2 is itself a protocol change subject to Decision 0002's
  backward/forward-compatibility policy: v1 verification must keep working for v1
  records, and the two schemes must be distinguishable precisely because the version is
  now signed.
- This decision only fixes *that the version must be signed* in v2+. It does not design
  v2's message layout, choose when v2 is warranted, or decide the migration path — those
  remain separate, per-change decisions.
