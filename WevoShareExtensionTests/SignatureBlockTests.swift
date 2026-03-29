//
//  SignatureBlockTests.swift
//  WevoShareExtensionTests
//

import Testing
@testable import WevoShareExtension

struct SignatureBlockTests {

    // MARK: - contains

    @Test func testContainsReturnsTrueWhenBlockPresent() {
        let text = SignatureBlock.format(text: "hello", publicKeyBase64: "pk", signatureBase64: "sig")
        #expect(SignatureBlock.contains(text) == true)
    }

    @Test func testContainsReturnsFalseForPlainText() {
        #expect(SignatureBlock.contains("hello world") == false)
    }

    @Test func testContainsReturnsFalseForPartialSeparator() {
        #expect(SignatureBlock.contains("hello\n\n---\n") == false)
    }

    // MARK: - format

    @Test func testFormatProducesExpectedStructure() {
        let result = SignatureBlock.format(text: "msg", publicKeyBase64: "ABC", signatureBase64: "XYZ")
        #expect(result.contains("msg"))
        #expect(result.contains("Public Key: ABC"))
        #expect(result.contains("Signature: XYZ"))
    }

    // MARK: - parse

    @Test func testParseRoundtrip() {
        let original = "Hello, World!"
        let pk = "publicKeyBase64=="
        let sig = "signatureBase64=="
        let formatted = SignatureBlock.format(text: original, publicKeyBase64: pk, signatureBase64: sig)
        let parsed = SignatureBlock.parse(formatted)

        #expect(parsed?.originalText == original)
        #expect(parsed?.publicKey == pk)
        #expect(parsed?.signature == sig)
    }

    @Test func testParseReturnsNilForPlainText() {
        #expect(SignatureBlock.parse("no signature here") == nil)
    }

    @Test func testParsePreservesMultilineOriginalText() {
        let original = "Line 1\nLine 2\nLine 3"
        let formatted = SignatureBlock.format(text: original, publicKeyBase64: "pk", signatureBase64: "sig")
        let parsed = SignatureBlock.parse(formatted)
        #expect(parsed?.originalText == original)
    }

    @Test func testParseReturnsNilWhenPublicKeyMissing() {
        let malformed = "some text\n\n---\nWevo Signature\nSignature: xyz"
        #expect(SignatureBlock.parse(malformed) == nil)
    }

    @Test func testParseReturnsNilWhenSignatureMissing() {
        let malformed = "some text\n\n---\nWevo Signature\nPublic Key: abc"
        #expect(SignatureBlock.parse(malformed) == nil)
    }

    @Test func testParseUsesLastOccurrenceOfSeparator() {
        // Original text itself contains the separator pattern — should still parse correctly
        let tricky = "before\n\n---\nWevo Signature\nPublic Key: fake\nSignature: fake"
        let outer = SignatureBlock.format(text: tricky, publicKeyBase64: "real_pk", signatureBase64: "real_sig")
        let parsed = SignatureBlock.parse(outer)
        #expect(parsed?.publicKey == "real_pk")
        #expect(parsed?.signature == "real_sig")
    }
}
