import Testing
import Foundation
@testable import Wevo

/// DIAGNOSTIC SELF-TEST — verifies the capture plumbing without aborting the process.
@Suite(.serialized)
@MainActor
struct DiagSelfTest {

    @Test func handlerIsInstalled() {
        CoreDataCrashDiagnostics.install()
        #expect(NSGetUncaughtExceptionHandler() != nil)
    }

    @Test func writeAndDrainRoundTrip() throws {
        CoreDataCrashDiagnostics.install()
        try? FileManager.default.removeItem(at: CoreDataCrashDiagnostics.reportURL)

        CoreDataCrashDiagnostics.writeReport(
            for: NSException(name: .internalInconsistencyException,
                             reason: "DIAG SELF TEST REASON",
                             userInfo: ["key": "value"])
        )

        let text = try String(contentsOf: CoreDataCrashDiagnostics.reportURL, encoding: .utf8)
        #expect(text.contains("DIAG SELF TEST REASON"))
        #expect(text.contains("NSInternalInconsistencyException"))
        #expect(text.contains("key"))

        try? FileManager.default.removeItem(at: CoreDataCrashDiagnostics.reportURL)
    }
}
