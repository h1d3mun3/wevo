//
//  HardenedURLSessionTests.swift
//  WevoTests
//

import Testing
import Foundation
@testable import Wevo

struct HardenedURLSessionTests {

    private func url(_ s: String) -> URL { URL(string: s)! }

    @Test func testAllowsSameHostSameScheme() {
        #expect(RedirectHardeningDelegate.allowsRedirect(
            from: url("https://api.example.com/a"), to: url("https://api.example.com/b")))
    }

    @Test func testAllowsSameHostUpgradeToHTTPS() {
        #expect(RedirectHardeningDelegate.allowsRedirect(
            from: url("http://api.example.com/a"), to: url("https://api.example.com/a")))
    }

    @Test func testRefusesDowngradeToHTTP() {
        #expect(!RedirectHardeningDelegate.allowsRedirect(
            from: url("https://api.example.com/a"), to: url("http://api.example.com/a")))
    }

    @Test func testRefusesCrossHost() {
        #expect(!RedirectHardeningDelegate.allowsRedirect(
            from: url("https://api.example.com/a"), to: url("https://evil.example.net/a")))
    }

    @Test func testRefusesCrossHostEvenWhenHTTPS() {
        // A different host is refused regardless of scheme — this is the attacker-endpoint case.
        #expect(!RedirectHardeningDelegate.allowsRedirect(
            from: url("https://api.example.com/a"), to: url("https://api.example.com.evil.net/a")))
    }

    @Test func testHostComparisonIsCaseInsensitive() {
        #expect(RedirectHardeningDelegate.allowsRedirect(
            from: url("https://API.Example.com/a"), to: url("https://api.example.com/b")))
    }

    @Test func testRefusesWhenTargetMissing() {
        #expect(!RedirectHardeningDelegate.allowsRedirect(from: url("https://api.example.com"), to: nil))
    }
}
