//
//  ProposeAPIClientISO8601Tests.swift
//  WevoTests
//

import Testing
import Foundation
@testable import Wevo

/// Pins the contract of the shared ISO8601 parser: it must accept both the
/// fractional-seconds form the app itself writes (`iso8601String(from:)`) and the
/// plain `.withInternetDateTime` form a peer or an older export may supply.
///
/// A bare `ISO8601DateFormatter()` satisfies only the second shape, which is why
/// UI code must never roll its own formatter.
struct ProposeAPIClientISO8601Tests {

    @Test func testParsesFractionalSeconds() {
        let date = ProposeAPIClient.iso8601Date(from: "2026-09-17T06:00:00.123Z")
        #expect(date != nil)
        #expect(date?.timeIntervalSince1970 == 1789624800.123)
    }

    @Test func testParsesWithoutFractionalSeconds() {
        let date = ProposeAPIClient.iso8601Date(from: "2026-09-17T06:00:00Z")
        #expect(date != nil)
        #expect(date?.timeIntervalSince1970 == 1789624800)
    }

    @Test func testRoundTripsOwnRendering() {
        let original = Date(timeIntervalSince1970: 1789624800.5)
        let rendered = ProposeAPIClient.iso8601String(from: original)
        let parsed = ProposeAPIClient.iso8601Date(from: rendered)
        #expect(parsed != nil)
        #expect(parsed?.timeIntervalSince1970 == original.timeIntervalSince1970)
    }

    @Test func testRejectsGarbage() {
        #expect(ProposeAPIClient.iso8601Date(from: "not a date") == nil)
    }
}
