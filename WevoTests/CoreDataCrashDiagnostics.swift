//
//  CoreDataCrashDiagnostics.swift
//  WevoTests
//
//  DIAGNOSTIC ONLY — NOT FOR MERGE.
//
//  Xcode Cloud reports the repository-test failures as
//  "Crash: Wevo at specialized static Runner._applyScopingTraits(for:testCase:_:)".
//  The real fault is an uncaught Objective-C exception thrown out of
//  -[NSSQLDefaultConnectionManager handleStoreRequest:] during
//  NSManagedObjectContext.save(), but the reason is nowhere to be found: the .ips
//  crash reports have an empty `asi`, the xcresult attachment is just that same
//  .ips, and the xcodebuild log carries no CoreData output.
//
//  Swift's `do/catch` in ProposeRepositoryImpl.create cannot intercept it either —
//  it is an NSException, not a Swift Error — so the process aborts with no message.
//
//  This installs an uncaught-exception handler that prints name, reason, userInfo
//  and the call stack to stderr (which does reach the xcodebuild log), and turns on
//  CoreData's own stderr logging.
//

import Foundation
import Testing

/// Set aside at install time. A C function pointer cannot capture context, so the previous
/// handler has to live at file scope for the handler below to reach it.
private var previousUncaughtExceptionHandler: (@convention(c) (NSException) -> Void)?

private func wevoUncaughtExceptionHandler(_ exception: NSException) {
    CoreDataCrashDiagnostics.writeReport(for: exception)
    previousUncaughtExceptionHandler?(exception)
}

enum CoreDataCrashDiagnostics {

    /// Survives the abort, unlike stderr.
    static let reportURL = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent("wevo-uncaught-exception.txt")


    private static let installed: Bool = {
        // CoreData reads these as user defaults; setting them here covers the case where the
        // test plan's launch arguments do not come through.
        UserDefaults.standard.set(1, forKey: "com.apple.CoreData.Logging.stderr")
        UserDefaults.standard.set(1, forKey: "com.apple.CoreData.SQLDebug")

        previousUncaughtExceptionHandler = NSGetUncaughtExceptionHandler()
        NSSetUncaughtExceptionHandler(wevoUncaughtExceptionHandler)
        return true
    }()

    /// Formats and persists the report. Separated out so the write path can be exercised by a
    /// test without actually aborting the process.
    static func writeReport(for exception: NSException) {
        var out = "\n===== WEVO DIAGNOSTIC: UNCAUGHT EXCEPTION =====\n"
        out += "name    : \(exception.name.rawValue)\n"
        out += "reason  : \(exception.reason ?? "(nil)")\n"
        out += "userInfo: \(exception.userInfo.map { String(describing: $0) } ?? "(nil)")\n"
        out += "stack   :\n"
        for frame in exception.callStackSymbols { out += "  \(frame)\n" }
        out += "==============================================\n"
        FileHandle.standardError.write(Data(out.utf8))
        fflush(stderr)
        // stderr from the test host stays inside the simulator clone and never reaches the
        // xcodebuild log, so persist it as well.
        try? out.write(to: reportURL, atomically: true, encoding: .utf8)
    }

    /// Idempotent; safe to call from every test.
    ///
    /// Also drains any report left behind by a previous test that aborted. The crashed process is
    /// gone by then, but XCTest relaunches the host for the next test and the app container -- and
    /// so the file -- survives within the run. Recording it as an Issue is what gets the reason
    /// into the xcresult, which is the only channel that reaches CI.
    static func install() {
        _ = installed
        guard let text = try? String(contentsOf: reportURL, encoding: .utf8) else { return }
        try? FileManager.default.removeItem(at: reportURL)
        Issue.record("A previous test in this process aborted on an uncaught exception:\n\(text)")
    }
}
