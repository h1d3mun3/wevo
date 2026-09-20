# Decision 0007: `MainActor` Default Isolation Now Covers `WevoTests` Too

## Status

Accepted — 2026-09-20

## Context

[Decision 0006](0006-default-actor-isolation-app-target-only.md) set
`SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` on the `Wevo` app target only, leaving
`WevoTests` on the `nonisolated` module default and compensating with an explicit
`@MainActor` on every suite that touched main-actor-isolated app code — 22 suites at the
time, since grown to 73 annotations (72 test suites plus one, `CloudKitMirroringFlagTests`,
added by PR #135 after 0006 was written). That decision gave two reasons the setting
could not simply be added to `WevoTests`:

1. **XCTest-based targets cannot take the setting at all.** `WevoUITests` subclassed
   `XCTestCase`, whose own members are `nonisolated`, so a `MainActor` module default put
   every inherited override in conflict with its `nonisolated` declaration.
2. **The mock class hierarchy was not consistent under it.** `MockKeychainRepositoryWithCallCount`
   (`WevoTests/UseCase/Propose/ImportProposeUseCaseTests.swift`) subclassed
   `MockKeychainRepository` (`WevoTests/Mocks/MockKeychainRepository.swift`), overriding only
   `verifySignature`. Under a `MainActor` module default, the subclass's implicitly-`MainActor`
   `init()` became an invalid override of the differently-inferred base `init()`.

Decision 0006 explicitly left the door open to reversing itself: "Anyone who wants the
module default on the test side must first make the mock hierarchy consistent under it
... and must accept that no `XCTestCase`-based target can be included. That is a refactor
with its own justification, not a tidy-up, and it supersedes this decision rather than
amending it."

Both conditions are now met:

- Reason 1 is moot. `WevoUITests` was removed entirely in PR #130
  (`chore/remove-wevo-ui-tests`), before 0006 was even written down — `xcodebuild -list`
  shows only `Wevo` and `WevoTests` as targets today.
- Reason 2's sole cause — the one and only inheritance relationship among the project's
  `Mock*` test doubles — has been removed (see Decision below).

## Decision

1. **`MockKeychainRepositoryWithCallCount` was rewritten as a composition (decorator)
   instead of a subclass.** It now conforms to `KeychainRepository` directly, holds a
   private `MockKeychainRepository` instance, forwards every protocol method to it except
   `verifySignature` (which keeps its existing per-call-result logic), and exposes
   `resultsPerCall` as before. No call site changed. `ImportProposeUseCaseTests.makeUseCase`'s
   `keychainRepository` parameter was loosened from the concrete `MockKeychainRepository` type
   to `(any KeychainRepository)?` to accept it, which is also a more honest signature — the
   use case under test only ever depends on the protocol.
2. **`SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` is now set on the `WevoTests` target**
   (Debug and Release), matching the `Wevo` app target.
3. **All 73 now-redundant explicit `@MainActor` annotations were deleted** from `WevoTests`
   — both the per-suite ones added by PR #123 (and since) and the handful on `Mock*` classes
   (`MockProposeRepository`, `MockSpaceRepository`, `MockContactRepository`,
   `MockDependencyContainer` and its nested mocks) that existed only to satisfy their
   `@MainActor`-isolated protocols (`ProposeRepository`, `SpaceRepository`,
   `ContactRepository`, `DependencyContainer`) before the module default covered them too.
4. **One real (non-redundant) isolation fix was needed**: `MockProposeAPIClient`
   (`WevoTests/Mocks/MockProposeAPIClient.swift`) conforms to `ProposeAPIClientProtocol`,
   which is declared `nonisolated protocol` in the app target (its real implementation is an
   `actor`). Under the new module default, the class's protocol-witness methods were
   inferred `nonisolated` to satisfy that conformance, while its stored properties defaulted
   to `MainActor` — a genuine conflict, not a redundant annotation. It was resolved the same
   way the app target already handles this class of type (see 0006's own precedent):
   `MockProposeAPIClient` is now declared `nonisolated` explicitly, matching the protocol it
   implements.
5. **Future mocks that need to override or specialize another mock's behavior must use
   composition (a decorator wrapping the base mock), not subclassing.** Subclassing a
   `Mock*` class is what reintroduces reason 2. Future mocks conforming to a `nonisolated`
   protocol (following `ProposeAPIClientProtocol`'s pattern) should be declared `nonisolated`
   explicitly, the same way `MockProposeAPIClient` now is, rather than relying on the module
   default and then working around the resulting conflict.

## Consequences

- The asymmetry Decision 0006 documented no longer exists: app code and test code now
  share the same default actor isolation, and a symbol's isolation can once again be
  inferred from where it's declared without checking for a per-suite override.
- Decision 0006 remains in the repository, marked superseded, as the historical record of
  why the asymmetry existed for about a day and what made it possible to remove.
- Verification: `xcodebuild build-for-testing` for `WevoTests` succeeds with zero errors and
  no new warnings; the full `WevoTests` suite (505 tests) passes, including every
  `ImportProposeUseCaseTests` case that exercises the newly-composed
  `MockKeychainRepositoryWithCallCount`.
- This decision concerns only test-target build settings, mock structure, and test-suite
  annotations. It does not affect the wire protocol or signed message format, so it needs
  no mirrored entry in [`wevo-space`](https://www.github.com/h1d3mun3/wevo-space).
