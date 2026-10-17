//
//  CloudKitMirroringFlagTests.swift
//  WevoTests
//

import Testing
import Foundation
@testable import Wevo

/// Guards the contract between `Wevo.xctestplan` and `WevoApp.cloudKitMirroringDisabled`.
///
/// Unit tests run inside the app process, so `WevoApp.sharedModelContainer` is built for real
/// during a test run. If the flag stops arriving, mirroring silently comes back on and the
/// diagnostics log fills with CloudKit setup failures again — a regression nobody notices from
/// a green test run. These two tests make it a red one instead.
///
/// The key is written out here rather than shared as a constant on purpose. It necessarily lives
/// in `Wevo.xctestplan` too, so a single source of truth was never available; and any mismatch
/// between the three copies is caught by the two tests below, which is the protection a shared
/// constant would have been standing in for.
///
/// The disabled-in-production direction is deliberately not asserted:
/// `ModelConfiguration.CloudKitDatabase` conforms only to `Sendable`, not `Equatable`, so the
/// resulting value cannot be compared in either direction. The `Bool` is the only testable
/// surface, which is why the decision is exposed as one.
struct CloudKitMirroringFlagTests {

    /// Fails if the test plan loses the environment variable entry, or renames it.
    @Test func testPlanSetsTheDisableFlag() {
        let value = ProcessInfo.processInfo.environment["WEVO_DISABLE_CLOUDKIT_MIRRORING"]
        #expect(
            value != nil,
            """
            Wevo.xctestplan must set WEVO_DISABLE_CLOUDKIT_MIRRORING in \
            defaultOptions.environmentVariableEntries. Without it the app under test mirrors to \
            CloudKit, fails setup because no test environment has an iCloud account, and retries \
            until the diagnostics log is unreadable.
            """
        )
    }

    /// Fails if the flag is still arriving but the code that reads it stops agreeing — a renamed
    /// key on the app side, an inverted condition, or the `#if DEBUG` gate moved wrongly.
    @Test func mirroringIsReportedDisabledUnderTest() {
        #expect(
            WevoApp.cloudKitMirroringDisabled,
            """
            WevoApp.cloudKitMirroringDisabled is false while the flag is being set. The key it \
            reads no longer matches WEVO_DISABLE_CLOUDKIT_MIRRORING as spelled in \
            Wevo.xctestplan, or the condition reading it has changed.
            """
        )
    }
}
