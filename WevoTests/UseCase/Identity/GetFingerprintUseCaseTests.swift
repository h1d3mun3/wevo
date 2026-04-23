//
//  GetFingerprintUseCaseTests.swift
//  WevoTests
//

import Testing
import Foundation
import CryptoKit
@testable import Wevo

struct GetFingerprintUseCaseTests {

    private let useCase = GetFingerprintUseCaseImpl()

    @Test func testReturnsEightByteColonSeparatedHexForValidJWK() {
        // Arrange
        let key = P256.Signing.PrivateKey()
        let jwk = key.publicKey.jwkString

        // Act
        let fingerprint = useCase.execute(jwkPublicKey: jwk)

        // Assert: format is "XX:XX:XX:XX:XX:XX:XX:XX"
        let parts = fingerprint.split(separator: ":", omittingEmptySubsequences: false)
        #expect(parts.count == 8)
        #expect(parts.allSatisfy { $0.count == 2 })
        #expect(parts.allSatisfy { $0.allSatisfy(\.isHexDigit) })
    }

    @Test func testReturnsFallbackForInvalidJWK() {
        // Arrange
        let invalid = "not-a-valid-jwk-string"

        // Act
        let fingerprint = useCase.execute(jwkPublicKey: invalid)

        // Assert: fallback is first 16 chars + "..."
        #expect(fingerprint == String(invalid.prefix(16)) + "...")
    }

    @Test func testReturnsFallbackForEmptyString() {
        // Act
        let fingerprint = useCase.execute(jwkPublicKey: "")

        // Assert
        #expect(fingerprint == "...")
    }

    @Test func testFingerprintIsConsistent() {
        // Arrange: same key should always produce the same fingerprint
        let key = P256.Signing.PrivateKey()
        let jwk = key.publicKey.jwkString

        // Act
        let first = useCase.execute(jwkPublicKey: jwk)
        let second = useCase.execute(jwkPublicKey: jwk)

        // Assert
        #expect(first == second)
    }

    @Test func testDifferentKeysProduceDifferentFingerprints() {
        // Arrange
        let jwk1 = P256.Signing.PrivateKey().publicKey.jwkString
        let jwk2 = P256.Signing.PrivateKey().publicKey.jwkString

        // Act
        let fp1 = useCase.execute(jwkPublicKey: jwk1)
        let fp2 = useCase.execute(jwkPublicKey: jwk2)

        // Assert
        #expect(fp1 != fp2)
    }
}
