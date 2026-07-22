# Decision 0002: Versioning and Backward Compatibility Policy

## Status

Accepted — 2026-07-18

## Context

This decision implements one part of the compatibility requirement fixed by
[Decision 0001](0001-forward-and-backward-compatibility-requirement.md): because
`wevo` clients and `wevo-space` deployments are decentralized and cannot be forced to
upgrade in lockstep, this client must remain usable against `wevo-space` deployments
older than itself. (Forward compatibility — this client remaining usable against a
`wevo-space` deployment *newer* than itself — is partially covered below (item 4) but
not fully designed; see Open Follow-ups.)

Wevo (this repository) and its server, [`wevo-space`](https://www.github.com/h1d3mun3/wevo-space),
are versioned independently, in separate git repositories. Each carries its own
marketing/package version number:

- `wevo`: `MARKETING_VERSION` in `Wevo.xcodeproj/project.pbxproj`, currently bumped to
  `2.0.0` on the `rc-2.0.0` branch.
- `wevo-space`: the `version` string returned by the `/info` endpoint, currently also
  bumped to `2.0.0`.

Investigation of both repositories' history found that this `2.0.0` bump, in both
repos, was a standalone commit changing only the version string (produced by the
`create-rc-branch.yml` CI workflow taking an arbitrary `X.Y.Z` input) — it introduced
no API or protocol change. The actual breaking work in this project's history — a
change to the signed-message format to embed the creator's public key, and the
addition of a `signatureVersion` field on `Propose`/`Dissolve`/`Honor`/`Part` records —
had already shipped months earlier, under what were `0.x` / `1.x` version numbers on
both sides.

In other words: the marketing version number does not currently track, and has not
historically tracked, wire-protocol compatibility. Today:

- `Wevo/Network/ProposeAPIClient.swift` targets the server's `/v1` route group
  unconditionally (`baseURL.appendingPathComponent("v1")`).
- `Wevo/UseCase/Space/FetchServerInfoUseCase.swift` decodes the server's `/info`
  response but only reads the `peers` field — **it does not read or check the
  server's `version` field at all**, so this client cannot currently detect a
  server-side version change even if it wanted to.
- There is no server-version negotiation, minimum-supported-server check, or
  compatibility warning anywhere in this client.
- No `CHANGELOG.md` or migration guide exists in this repository.

This ambiguity is a problem: a future release of either side could pair a marketing
version bump with an actual breaking protocol change, and this client would have no
way to detect or warn about it — it would simply start failing at request time.

## Decision

1. **The wire protocol version is tracked separately from the marketing/package
   version.** This client's compatibility with a given `wevo-space` server is
   determined by two things, not by either side's marketing version:
   - The **HTTP route prefix** the client targets (`/v1` today; see
     `ProposeAPIClient.swift`).
   - The **`signatureVersion`** this client writes onto signed payloads
     (`Propose`/`Dissolve`/`Honor`/`Part`), which the server validates.
2. **A bump to this app's `MARKETING_VERSION`, or to the server's `/info` version
   string, does not by itself indicate a breaking change**, and must not be used to
   infer compatibility between a given client build and server deployment.
3. **Any change to the route prefix this client targets, or to the
   `signatureVersion` it writes, must be recorded in a new decision in this
   directory**, and a matching entry must be added to `wevo-space`'s
   `docs/decisions/`, cross-referenced by number.
4. **Open follow-up, not yet decided**: this client currently ignores the server's
   `/info` version field entirely (see `FetchServerInfoUseCase.swift`). Whether the
   client should start reading it — e.g. to warn the user when talking to a server
   that has moved to a route prefix or `signatureVersion` this build doesn't support —
   is not yet decided. Until a future decision addresses this, a version mismatch between
   client and server (should one ever be introduced) will surface only as failed
   requests, not as an explicit compatibility warning.
5. **Open follow-up, not yet decided**: this decision does not analyze this client's
   backward compatibility toward older `wevo-space` deployments beyond "it targets
   `/v1`, which still exists everywhere." As this client gains features that assume
   newer server capabilities, an explicit story for degrading gracefully against an
   older `wevo-space` (required by Decision 0001) will be needed and should be the
   subject of a future decision in this directory.

## Consequences

- This app's marketing/App Store version can move for release/business reasons
  without implying, or requiring, a protocol change on either side.
- As of this decision, `wevo` 1.2.0 and later, and `wevo-space` up to and including the
  `2.0.0`-labeled `rc-2.0.0` branch, all speak the same `/v1` HTTP shape and the same
  `signatureVersion`, and are therefore compatible — but this compatibility is a fact
  about the protocol, not something guaranteed by either side's marketing version
  number matching or being close.
- Because this client does not check the server's version at all, it cannot
  distinguish "server is on an incompatible future protocol" from any other network
  failure. A protocol-breaking server release would present to users as unexplained
  request failures until item 4 above is addressed.
- This decision is a partial implementation of Decision 0001: it addresses how this
  client's compatibility signals are decoupled from marketing version, but leaves
  both directions of actual compatibility design (items 4 and 5 above) open. It
  should not be read as satisfying Decision 0001 in full.
