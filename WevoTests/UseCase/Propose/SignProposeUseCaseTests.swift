//
//  SignProposeUseCaseTests.swift
//  WevoTests
//
//  Created by hidemune on 3/10/26.
//

import Testing
import Foundation
@testable import Wevo

@MainActor
struct SignProposeUseCaseTests {

    @Test func testAddsSignatureToPropose() async throws {
        // Arrange
        let mockKeychain = MockKeychainRepository()
        let mockPropose = MockProposeRepository()

        let proposeID = UUID()
        let identityID = UUID()
        let existingSignature = Signature(id: UUID(), publicKey: "key1", signature: "sig1", createdAt: .now)
        let testPropose = Propose(
            id: proposeID,
            spaceID: UUID(),
            message: "test",
            signatures: [existingSignature],
            createdAt: .now,
            updatedAt: .now
        )

        let testIdentity = Identity(id: identityID, nickname: "Alice", publicKey: "pubkey123")
        mockKeychain.getIdentityResult = testIdentity
        mockKeychain.signMessageResult = "newsignature"
        mockPropose.fetchByIDResult = testPropose

        let useCase = SignProposeUseCaseImpl(
            keychainRepository: mockKeychain,
            proposeRepository: mockPropose
        )

        // Act
        try await useCase.execute(to: proposeID, signIdentityID: identityID)

        // Assert
        #expect(mockPropose.updateCalled == true)
        let updatedPropose = mockPropose.updatedPropose
        #expect(updatedPropose?.signatures.count == 2)
        #expect(updatedPropose?.signatures[1].publicKey == "pubkey123")
    }

    @Test func testPreservesExistingSignatures() async throws {
        // Arrange
        let mockKeychain = MockKeychainRepository()
        let mockPropose = MockProposeRepository()

        let proposeID = UUID()
        let identityID = UUID()
        let sig1 = Signature(id: UUID(), publicKey: "key1", signature: "sig1", createdAt: .now)
        let sig2 = Signature(id: UUID(), publicKey: "key2", signature: "sig2", createdAt: .now)
        let testPropose = Propose(
            id: proposeID,
            spaceID: UUID(),
            message: "test",
            signatures: [sig1, sig2],
            createdAt: .now,
            updatedAt: .now
        )

        let testIdentity = Identity(id: identityID, nickname: "Alice", publicKey: "newkey")
        mockKeychain.getIdentityResult = testIdentity
        mockKeychain.signMessageResult = "newsignature"
        mockPropose.fetchByIDResult = testPropose

        let useCase = SignProposeUseCaseImpl(
            keychainRepository: mockKeychain,
            proposeRepository: mockPropose
        )

        // Act
        try await useCase.execute(to: proposeID, signIdentityID: identityID)

        // Assert
        let updatedPropose = mockPropose.updatedPropose
        #expect(updatedPropose?.signatures[0].publicKey == "key1")
        #expect(updatedPropose?.signatures[1].publicKey == "key2")
        #expect(updatedPropose?.signatures[2].publicKey == "newkey")
    }

    @Test func testThrowsFailedToSaveProposeWhenUpdateFails() async throws {
        // Arrange
        let mockKeychain = MockKeychainRepository()
        let mockPropose = MockProposeRepository()

        let proposeID = UUID()
        let identityID = UUID()
        let testPropose = Propose(
            id: proposeID,
            spaceID: UUID(),
            message: "test",
            signatures: [],
            createdAt: .now,
            updatedAt: .now
        )

        let testIdentity = Identity(id: identityID, nickname: "Alice", publicKey: "pubkey123")
        mockKeychain.getIdentityResult = testIdentity
        mockKeychain.signMessageResult = "newsignature"
        mockPropose.fetchByIDResult = testPropose
        mockPropose.updateError = NSError(domain: "Test", code: -1)

        let useCase = SignProposeUseCaseImpl(
            keychainRepository: mockKeychain,
            proposeRepository: mockPropose
        )

        // Act & Assert
        await #expect(throws: SignProposeUseCaseError.failedToSavePropose) {
            try await useCase.execute(to: proposeID, signIdentityID: identityID)
        }
    }

    @Test func testThrowsWhenGetIdentityFails() async throws {
        // Arrange
        let mockKeychain = MockKeychainRepository()
        let mockPropose = MockProposeRepository()

        mockKeychain.getIdentityError = KeychainError.itemNotFound

        let useCase = SignProposeUseCaseImpl(
            keychainRepository: mockKeychain,
            proposeRepository: mockPropose
        )

        // Act & Assert
        await #expect(throws: KeychainError.itemNotFound) {
            try await useCase.execute(to: UUID(), signIdentityID: UUID())
        }
    }

    @Test func testThrowsWhenProposeFetchFails() async throws {
        // Arrange
        let mockKeychain = MockKeychainRepository()
        let mockPropose = MockProposeRepository()

        let testIdentity = Identity(id: UUID(), nickname: "Alice", publicKey: "pubkey123")
        mockKeychain.getIdentityResult = testIdentity
        mockPropose.fetchByIDError = NSError(domain: "Test", code: -1)

        let useCase = SignProposeUseCaseImpl(
            keychainRepository: mockKeychain,
            proposeRepository: mockPropose
        )

        // Act & Assert
        await #expect(throws: NSError.self) {
            try await useCase.execute(to: UUID(), signIdentityID: UUID())
        }
    }

    @Test func testThrowsWhenSignMessageFails() async throws {
        // Arrange
        let mockKeychain = MockKeychainRepository()
        let mockPropose = MockProposeRepository()

        let proposeID = UUID()
        let identityID = UUID()
        let testPropose = Propose(
            id: proposeID,
            spaceID: UUID(),
            message: "test",
            signatures: [],
            createdAt: .now,
            updatedAt: .now
        )

        let testIdentity = Identity(id: identityID, nickname: "Alice", publicKey: "pubkey123")
        mockKeychain.getIdentityResult = testIdentity
        mockKeychain.signMessageError = KeychainError.biometricAuthFailed
        mockPropose.fetchByIDResult = testPropose

        let useCase = SignProposeUseCaseImpl(
            keychainRepository: mockKeychain,
            proposeRepository: mockPropose
        )

        // Act & Assert
        await #expect(throws: KeychainError.biometricAuthFailed) {
            try await useCase.execute(to: proposeID, signIdentityID: identityID)
        }
    }
}
