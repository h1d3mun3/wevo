//
//  ServerURLExtensionsTests.swift
//  WevoTests
//

import Testing
import Foundation
@testable import Wevo

struct ServerURLExtensionsTests {

    @Test func testHasUsableServerURL() {
        #expect(["https://example.com"].hasUsableServerURL == true)
        #expect(["http://example.com"].hasUsableServerURL == true)
        #expect(["example.com"].hasUsableServerURL == false)
        #expect([String]().hasUsableServerURL == false)
        #expect(["ftp://example.com"].hasUsableServerURL == false)
        #expect(["example.com", "https://node.example.com"].hasUsableServerURL == true)
    }

    @Test func testNormalizedServerURL() {
        #expect("example.com".normalizedServerURL == "https://example.com")
        #expect("  example.com  ".normalizedServerURL == "https://example.com")
        #expect("https://example.com".normalizedServerURL == "https://example.com")
        #expect("http://x.example.com".normalizedServerURL == "http://x.example.com")
        #expect("".normalizedServerURL == nil)
        #expect("   ".normalizedServerURL == nil)
        #expect("ftp://example.com".normalizedServerURL == nil)
    }
}
