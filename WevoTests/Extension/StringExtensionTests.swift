//
//  StringExtensionTests.swift
//  WevoTests
//

import Testing
import Foundation
@testable import Wevo

struct StringExtensionTests {

    @Test func testKnownSHA256Hash() {
        // SHA256("hello") is a well-known value
        #expect("hello".sha256HashedString == "2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824")
    }

    @Test func testEmptyStringSHA256Hash() {
        #expect("".sha256HashedString == "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855")
    }

    @Test func testHashIsDeterministic() {
        let input = "wevo-propose-content"
        #expect(input.sha256HashedString == input.sha256HashedString)
    }

    @Test func testDifferentInputsProduceDifferentHashes() {
        #expect("abc".sha256HashedString != "def".sha256HashedString)
    }

    @Test func testHashIsLowercaseHex() {
        let hash = "test".sha256HashedString
        #expect(hash.count == 64)
        #expect(hash.allSatisfy { $0.isHexDigit && !$0.isUppercase })
    }
}
