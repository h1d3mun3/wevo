//
//  ExtensionCryptoTests.swift
//  WevoShareExtensionTests
//
//  Tests the sign → format → parse → verify round trip using CryptoKit directly,
//  without touching Keychain.
//

import Testing
import CryptoKit
import Foundation
@testable import WevoShareExtension

struct ExtensionCryptoTests {

    // MARK: - Helpers

    private func generateKeyPair() -> (privateKey: P256.Signing.PrivateKey, publicKeyBase64: String) {
        let privateKey = P256.Signing.PrivateKey()
        let publicKeyBase64 = privateKey.publicKey.rawRepresentation.base64EncodedString()
        return (privateKey, publicKeyBase64)
    }

    private func sign(text: String, privateKey: P256.Signing.PrivateKey) throws -> String {
        let data = Data(text.utf8)
        let sig = try privateKey.signature(for: data)
        return sig.derRepresentation.base64EncodedString()
    }

    private func verify(text: String, publicKeyBase64: String, signatureBase64: String) throws -> Bool {
        guard let sigData = Data(base64Encoded: signatureBase64),
              let msgData = text.data(using: .utf8),
              let pkData = Data(base64Encoded: publicKeyBase64),
              pkData.count == 64
        else { return false }
        let pk = try P256.Signing.PublicKey(rawRepresentation: pkData)
        let sig = try P256.Signing.ECDSASignature(derRepresentation: sigData)
        return pk.isValidSignature(sig, for: msgData)
    }

    // MARK: - Tests

    @Test func testSignAndVerifyRoundtrip() throws {
        let (privateKey, publicKeyBase64) = generateKeyPair()
        let message = "Hello, Wevo!"
        let signatureBase64 = try sign(text: message, privateKey: privateKey)
        let isValid = try verify(text: message, publicKeyBase64: publicKeyBase64, signatureBase64: signatureBase64)
        #expect(isValid == true)
    }

    @Test func testVerifyFailsForTamperedText() throws {
        let (privateKey, publicKeyBase64) = generateKeyPair()
        let signatureBase64 = try sign(text: "original", privateKey: privateKey)
        let isValid = try verify(text: "tampered", publicKeyBase64: publicKeyBase64, signatureBase64: signatureBase64)
        #expect(isValid == false)
    }

    @Test func testVerifyFailsForWrongKey() throws {
        let (privateKey, _) = generateKeyPair()
        let (_, otherPublicKeyBase64) = generateKeyPair()
        let signatureBase64 = try sign(text: "message", privateKey: privateKey)
        let isValid = try verify(text: "message", publicKeyBase64: otherPublicKeyBase64, signatureBase64: signatureBase64)
        #expect(isValid == false)
    }

    @Test func testFullBlockRoundtrip() throws {
        let (privateKey, publicKeyBase64) = generateKeyPair()
        let originalText = "Sign this document."

        // Sign and format
        let signatureBase64 = try sign(text: originalText, privateKey: privateKey)
        let block = SignatureBlock.format(text: originalText, publicKeyBase64: publicKeyBase64, signatureBase64: signatureBase64)

        // Parse
        let parsed = try #require(SignatureBlock.parse(block))

        // Verify
        let isValid = try verify(
            text: parsed.originalText,
            publicKeyBase64: parsed.publicKey,
            signatureBase64: parsed.signature
        )
        #expect(isValid == true)
        #expect(parsed.originalText == originalText)
    }

    @Test func testFullBlockRoundtripWithMultilineText() throws {
        let (privateKey, publicKeyBase64) = generateKeyPair()
        let originalText = "Line 1\nLine 2\nLine 3"

        let signatureBase64 = try sign(text: originalText, privateKey: privateKey)
        let block = SignatureBlock.format(text: originalText, publicKeyBase64: publicKeyBase64, signatureBase64: signatureBase64)
        let parsed = try #require(SignatureBlock.parse(block))
        let isValid = try verify(text: parsed.originalText, publicKeyBase64: parsed.publicKey, signatureBase64: parsed.signature)

        #expect(isValid == true)
        #expect(parsed.originalText == originalText)
    }
}
