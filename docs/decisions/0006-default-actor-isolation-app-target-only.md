# Decision 0006: `MainActor` Default Isolation Is Set on the App Target Only, Not on Test Targets

## Status

Superseded by [Decision 0007](0007-mainactor-default-isolation-now-covers-wevotests.md) — 2026-09-20.
Originally accepted 2026-09-19; kept below as the accurate historical record of why the
asymmetry existed and what was tried before it was resolved.

## Context

Under the Swift 6 language mode (`SWIFT_VERSION = 6.0`, set on every target),
`Wevo.xcodeproj/project.pbxproj` configures approachable concurrency asymmetrically:

- `SWIFT_APPROACHABLE_CONCURRENCY = YES` is set on **all three** targets — `Wevo`,
  `WevoTests` and `WevoUITests` — in both Debug and Release.
- `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` is set on **the `Wevo` app target only**, in
  both Debug and Release. Neither test target has it.

The consequence is that app code defaults to `@MainActor` while test code defaults to
`nonisolated`. That default is load-bearing for the app: `Wevo` is a SwiftUI + SwiftData
app whose views, view models and use cases are main-actor work by nature, and the places
that genuinely are not — `ProposeAPIClientProtocol`, `HashedPropose`, `HardenedURLSession`'s
delegate method — opt out explicitly with `nonisolated` rather than relying on the module
default.

Because the test targets keep the `nonisolated` default, a synchronous call from a test
suite into main-actor-isolated app code is rejected by the compiler. The fix applied was
per-suite: commit `493cf5e` ("test: isolate test suites to the main actor", PR #123) added
`@MainActor` to the 22 suites in `WevoTests` that lacked it — 22 files, 22 insertions, one
line each and no other change.

Read from the build settings alone, the missing setting on the test targets looks like an
oversight, and the obvious tidy-up is to set `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`
there too and delete the 22 annotations. That was tried, and it does not work. Two
independent reasons:

1. **XCTest-based targets cannot take the setting at all.** `WevoUITests` consists of
   `XCTestCase` subclasses (`WevoUITests`, `WevoUITestsLaunchTests`), and XCTest's own
   members are `nonisolated`. Making the module default `MainActor` puts every override in
   conflict with the declaration it overrides — the inherited initializers `init()`,
   `init(invocation:)` and `init(selector:)`, plus the explicit `setUpWithError()`,
   `tearDownWithError()` and `runsForEachTargetApplicationUIConfiguration` overrides —
   producing over ten errors across the two files, of the form:

   ```
   main actor-isolated instance method 'setUpWithError()' has different actor isolation
   from nonisolated overridden declaration
   ```

   This is a property of subclassing XCTest, not of these particular files: it applies to
   any `XCTestCase`-based target in this project, present or future.

2. **Applying it to `WevoTests` alone still does not build.** Swift Testing's `@Suite` types
   are not subclasses of anything, so 21 of the 22 suites do come out right for free — but
   one error remains. `MockKeychainRepositoryWithCallCount`
   (`WevoTests/UseCase/Propose/ImportProposeUseCaseTests.swift`) subclasses
   `MockKeychainRepository` (`WevoTests/Mocks/MockKeychainRepository.swift`), which is
   unannotated and whose implicit `init()` is therefore inferred `nonisolated`; the
   subclass's now-implicitly-`MainActor` `init()` is an invalid override of it. Annotating
   the subclass `nonisolated` to patch that does not contain the problem — the class then
   has to satisfy `Sendable` while holding mutable stored properties and touching
   main-actor-isolated mock state, which cascades into about a dozen further errors through
   the mock hierarchy.

Reason 2 stands on its own: even with no XCTest-based target in the project, the setting
would still not be applicable to `WevoTests` without restructuring the mocks.

## Decision

1. **`SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` stays on the `Wevo` app target only.** It
   MUST NOT be added to `WevoTests`, nor to any XCTest-based target, as a build-settings
   cleanup. The asymmetry is intentional, and this entry is the reason it looks the way it
   does.
2. **`SWIFT_APPROACHABLE_CONCURRENCY = YES` remains on all targets.** Only the default
   isolation differs between app and test code; the rest of the approachable-concurrency
   configuration does not.
3. **Test-side isolation is expressed per suite, with `@MainActor` on the suite type.** This
   is deliberately mechanical: each annotation is one line, individually reversible,
   reviewable in isolation, and leaves the mock class hierarchy untouched.
4. **A new suite needs `@MainActor` only if it exercises main-actor-isolated app code.** Not
   unconditionally. A suite that only touches `nonisolated` API — a `Codable` model, a pure
   static helper, a `nonisolated` protocol, `Foundation` or `ProcessInfo` — compiles without
   it, and annotating it anyway buys nothing. The rule is: write the suite without the
   annotation, and add it when the compiler asks for it. That every suite in `WevoTests`
   happens to carry `@MainActor` today is a fact about the current suites, not a convention
   to copy.

   In principle the annotation costs in-process parallelism, since `Wevo.xctestplan` runs
   `WevoTests` with `parallelizable = true` and main-actor suites cannot run concurrently
   with each other. **In practice no such cost has been measured on this suite set**, and
   the suspicion that it had been was the reason PR #123 was split out of #120 at all. The
   Xcode Cloud iOS unit-test runs across the stack were 4m9s before the annotations
   (baseline), 4m8s with all 22 of them in Swift 5 mode, and 4m1s with them in Swift 6 mode.
   Treat the parallelism argument as a reason not to annotate gratuitously, not as evidence
   that the current 22 annotations are costing anything.
5. **Reversing this requires more than a settings change.** Anyone who wants the module
   default on the test side must first make the mock hierarchy consistent under it (reason
   2), and must accept that no `XCTestCase`-based target can be included (reason 1). That is
   a refactor with its own justification, not a tidy-up, and it supersedes this decision
   rather than amending it.

## Consequences

- The 22 `@MainActor` annotations are permanent structure, not transitional debt. They
  should not be removed in a sweep, and a reviewer seeing one added to a new suite should
  ask only whether the suite needs it (rule 4), not whether the annotation style is right.
- Test code and app code have different default isolation, so a symbol's isolation cannot be
  inferred from where it is declared. Test authors calling into `Wevo` should expect
  main-actor isolation by default and treat the explicit `nonisolated` declarations in the
  app target as the exceptions.
- Reason 1 is recorded as the standing reason the setting is never applied to XCTest-based
  targets. It is stated here in its own right because it will keep being true of any such
  target added later — including if `WevoUITests`, currently 74 lines of unmodified Xcode
  template with no assertions and not listed in `Wevo.xctestplan`, is retired. Reason 2 is
  unaffected either way.
- **Clarification to [Decision 0004](0004-trunk-and-release-candidate-branches.md)**: that
  entry's statement that `wevo` has "no CI workflow at all" remains accurate about GitHub
  Actions — `.github/workflows/` still contains only `create-rc-branch.yml` — but Xcode
  Cloud does build and run `WevoTests` on pull requests (the `Wevo | Unit Test` checks), and
  it was an Xcode Cloud test run that PR #123 was split out in order to keep decisive. The
  branch-protection gap Decision 0004 describes is unchanged; only the "nothing runs tests"
  reading of it needs qualifying.
- This decision does not touch the app target's own isolation design: whether a given type
  in `Wevo` should be `nonisolated`, and where the module default is the wrong answer,
  remain ordinary per-change decisions.
- This decision concerns only build settings and test-suite annotations. It does not affect
  the wire protocol or signed message format, so it needs no mirrored entry in
  [`wevo-space`](https://www.github.com/h1d3mun3/wevo-space).
