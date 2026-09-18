import Testing
import Foundation
import SwiftData
@testable import Wevo

/// DIAGNOSTIC SELF-TEST — proves the ObjC shim converts a raised NSException into a value
/// instead of letting it abort the process.
@Suite(.serialized)
@MainActor
struct DiagSelfTest {

    /// The preprocessor must record the reason even for an exception that is caught and
    /// therefore never terminates anything -- that is what proves the hook is live.
    @Test func preprocessorRecordsTheReason() throws {
        CoreDataCrashDiagnostics.install()
        try? FileManager.default.removeItem(at: CoreDataCrashDiagnostics.reportURL)

        _ = WevoCatchNSException {
            NSException(name: .internalInconsistencyException,
                        reason: "PREPROCESSOR REACHED", userInfo: ["k": "v"]).raise()
        }

        let text = try String(contentsOf: CoreDataCrashDiagnostics.reportURL, encoding: .utf8)
        #expect(text.contains("PREPROCESSOR REACHED"))
        #expect(text.contains("NSInternalInconsistencyException"))
        try? FileManager.default.removeItem(at: CoreDataCrashDiagnostics.reportURL)
    }
}
