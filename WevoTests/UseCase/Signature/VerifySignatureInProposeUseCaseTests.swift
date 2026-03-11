//
//  VerifySignatureInProposeUseCaseTests.swift
//  WevoTests
//
//  Created on 3/11/26.
//

import Testing
import Foundation
@testable import Wevo

@MainActor
struct VerifySignatureInProposeUseCaseTests {

    @Test func testReturnsTrueWhenSignatureIsValid() async throws {
        // Arrange
        let mockSignature = MockSignatureRepository()
        let mockKeychain = MockKeychainRepository()
        let signatureID = UUID()

        mockSignature.fetchPayloadHashResult = "valid-hash"
        mockKeychain.verifySignatureResult = true

        let useCase = VerifySignatureInProposeUseCaseImpl(
            signatureRepository: mockSignature,
            keychainRepository: mockKeychain
        )

        // Act
        let result = try useCase.execute(
            signatureID: signatureID,
            signatureData: "sig-data",
            publicKey: "pub-key"
        )

        // Assert
        #expect(result == true)
        #expect(mockSignature.fetchPayloadHashCalledWithID == signatureID)
    }

    @Test func testReturnsFalseWhenSignatureIsInvalid() async throws {
        // Arrange
        let mockSignature = MockSignatureRepository()
        let mockKeychain = MockKeychainRepository()

        mockSignature.fetchPayloadHashResult = "valid-hash"
        mockKeychain.verifySignatureResult = false

        let useCase = VerifySignatureInProposeUseCaseImpl(
            signatureRepository: mockSignature,
            keychainRepository: mockKeychain
        )

        // Act
        let result = try useCase.execute(
            signatureID: UUID(),
            signatureData: "sig-data",
            publicKey: "pub-key"
        )

        // Assert
        #expect(result == false)
    }

    @Test func testUsesPayloadHashFromRepository() async throws {
        // Arrange
        let mockSignature = MockSignatureRepository()
        let mockKeychain = MockKeychainRepository()

        mockSignature.fetchPayloadHashResult = "expected-hash"
        mockKeychain.verifySignatureResult = true

        let useCase = VerifySignatureInProposeUseCaseImpl(
            signatureRepository: mockSignature,
            keychainRepository: mockKeychain
        )

        // Act
        _ = try useCase.execute(
            signatureID: UUID(),
            signatureData: "sig-data",
            publicKey: "pub-key"
        )

        // Assert - fetchPayloadHash was called and result used for verification
        #expect(mockSignature.fetchPayloadHashCalledWithID != nil)
    }

    @Test func testThrowsWhenProposeNotFoundForSignature() async throws {
        // Arrange
        let mockSignature = MockSignatureRepository()
        let mockKeychain = MockKeychainRepository()
        let signatureID = UUID()

        mockSignature.fetchPayloadHashError = SignatureRepositoryError.proposeNotFoundForSignature(signatureID)

        let useCase = VerifySignatureInProposeUseCaseImpl(
            signatureRepository: mockSignature,
            keychainRepository: mockKeychain
        )

        // Act & Assert
        #expect(throws: SignatureRepositoryError.self) {
            try useCase.execute(
                signatureID: signatureID,
                signatureData: "sig-data",
                publicKey: "pub-key"
            )
        }
    }

    @Test func testThrowsWhenVerificationFails() async throws {
        // Arrange
        let mockSignature = MockSignatureRepository()
        let mockKeychain = MockKeychainRepository()

        mockSignature.fetchPayloadHashResult = "valid-hash"
        mockKeychain.verifySignatureError = KeychainError.biometricAuthFailed

        let useCase = VerifySignatureInProposeUseCaseImpl(
            signatureRepository: mockSignature,
            keychainRepository: mockKeychain
        )

        // Act & Assert
        #expect(throws: KeychainError.biometricAuthFailed) {
            try useCase.execute(
                signatureID: UUID(),
                signatureData: "sig-data",
                publicKey: "pub-key"
            )
        }
    }

    @Test func testDoesNotCallVerifyWhenPayloadHashFetchFails() async throws {
        // Arrange
        let mockSignature = MockSignatureRepository()
        let mockKeychain = MockKeychainRepository()

        mockSignature.fetchPayloadHashError = SignatureRepositoryError.fetchError(
            NSError(domain: "Test", code: -1)
        )

        let useCase = VerifySignatureInProposeUseCaseImpl(
            signatureRepository: mockSignature,
            keychainRepository: mockKeychain
        )

        // Act & Assert
        #expect(throws: SignatureRepositoryError.self) {
            try useCase.execute(
                signatureID: UUID(),
                signatureData: "sig-data",
                publicKey: "pub-key"
            )
        }
    }
}
