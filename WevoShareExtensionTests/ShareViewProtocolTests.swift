//
//  ShareViewProtocolTests.swift
//  WevoShareExtensionTests
//

import Testing
import CryptoKit
import Foundation
@testable import WevoShareExtension

// MARK: - Mocks

private struct MockIdentitySigningService: IdentitySigningService {
    var identities: [ExtensionIdentity] = []
    var identitiesError: Error?
    var signResult: String = "mockSignature"
    var signError: Error?
    var publicKeyResult: String = "mockPublicKey"
    var publicKeyError: Error?

    func getAllIdentities() throws -> [ExtensionIdentity] {
        if let error = identitiesError { throw error }
        return identities
    }

    func signText(_ text: String, withIdentityId id: UUID) throws -> String {
        if let error = signError { throw error }
        return signResult
    }

    func getPublicKeyRawBase64(forIdentityId id: UUID) throws -> String {
        if let error = publicKeyError { throw error }
        return publicKeyResult
    }
}

private struct MockSignatureVerifyingService: SignatureVerifyingService {
    var verifyResult: Bool = true
    var verifyError: Error?

    func verifyText(_ text: String, publicKeyBase64: String, signatureBase64: String) throws -> Bool {
        if let error = verifyError { throw error }
        return verifyResult
    }
}

// MARK: - Helpers

private func makeJWKString(from privateKey: P256.Signing.PrivateKey) -> String {
    let raw = privateKey.publicKey.rawRepresentation
    func base64url(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
    let x = base64url(raw.prefix(32))
    let y = base64url(raw.suffix(32))
    return #"{"x":"\#(x)","y":"\#(y)"}"#
}

// MARK: - fingerprint(jwkPublicKey:) Tests

struct FingerprintJWKTests {

    @Test func testReturnsEightByteColonSeparatedHexForValidJWK() {
        let jwk = makeJWKString(from: P256.Signing.PrivateKey())

        let fingerprint = ExtensionKeychainService.fingerprint(jwkPublicKey: jwk)

        let parts = fingerprint.split(separator: ":", omittingEmptySubsequences: false)
        #expect(parts.count == 8)
        #expect(parts.allSatisfy { $0.count == 2 })
        #expect(parts.allSatisfy { $0.allSatisfy(\.isHexDigit) })
    }

    @Test func testReturnsFallbackForInvalidJWK() {
        let fingerprint = ExtensionKeychainService.fingerprint(jwkPublicKey: "not-valid-jwk")
        #expect(fingerprint == "---")
    }

    @Test func testFingerprintIsConsistent() {
        let jwk = makeJWKString(from: P256.Signing.PrivateKey())
        let first = ExtensionKeychainService.fingerprint(jwkPublicKey: jwk)
        let second = ExtensionKeychainService.fingerprint(jwkPublicKey: jwk)
        #expect(first == second)
    }

    @Test func testDifferentKeysProduceDifferentFingerprints() {
        let jwk1 = makeJWKString(from: P256.Signing.PrivateKey())
        let jwk2 = makeJWKString(from: P256.Signing.PrivateKey())
        #expect(ExtensionKeychainService.fingerprint(jwkPublicKey: jwk1) != ExtensionKeychainService.fingerprint(jwkPublicKey: jwk2))
    }
}

// MARK: - IdentitySigningService Protocol Tests

struct IdentitySigningServiceTests {

    @Test func testGetAllIdentitiesReturnsInjectedIdentities() throws {
        let identity = ExtensionIdentity(id: UUID(), nickname: "Alice", publicKeyJWK: "jwk")
        var service = MockIdentitySigningService()
        service.identities = [identity]

        let result = try service.getAllIdentities()

        #expect(result.count == 1)
        #expect(result[0].nickname == "Alice")
    }

    @Test func testGetAllIdentitiesThrowsInjectedError() {
        var service = MockIdentitySigningService()
        service.identitiesError = KeychainAccessError.identityNotFound

        #expect(throws: KeychainAccessError.identityNotFound) {
            try service.getAllIdentities()
        }
    }

    @Test func testSignTextReturnsInjectedSignature() throws {
        var service = MockIdentitySigningService()
        service.signResult = "testSignature"

        let result = try service.signText("hello", withIdentityId: UUID())

        #expect(result == "testSignature")
    }

    @Test func testGetPublicKeyRawBase64ReturnsInjectedKey() throws {
        var service = MockIdentitySigningService()
        service.publicKeyResult = "base64key=="

        let result = try service.getPublicKeyRawBase64(forIdentityId: UUID())

        #expect(result == "base64key==")
    }
}

// MARK: - SignatureVerifyingService Protocol Tests

struct SignatureVerifyingServiceTests {

    @Test func testVerifyTextReturnsTrue() throws {
        let service = MockSignatureVerifyingService(verifyResult: true)
        let result = try service.verifyText("msg", publicKeyBase64: "pk", signatureBase64: "sig")
        #expect(result == true)
    }

    @Test func testVerifyTextReturnsFalse() throws {
        let service = MockSignatureVerifyingService(verifyResult: false)
        let result = try service.verifyText("msg", publicKeyBase64: "pk", signatureBase64: "sig")
        #expect(result == false)
    }

    @Test func testVerifyTextThrowsInjectedError() {
        let service = MockSignatureVerifyingService(verifyResult: true, verifyError: KeychainAccessError.invalidData)
        #expect(throws: KeychainAccessError.invalidData) {
            try service.verifyText("msg", publicKeyBase64: "pk", signatureBase64: "sig")
        }
    }
}
