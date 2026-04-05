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

    /// Helper to generate a test Propose
    private func makePropose(
        id: UUID = UUID(),
        creatorPublicKey: String = "creatorKey",
        counterpartyPublicKey: String = "counterpartyKey",
        counterpartySignSignature: String? = nil
    ) -> Propose {
        Propose(
            id: id,
            spaceID: UUID(),
            message: "test",
            creatorPublicKey: creatorPublicKey,
            creatorSignature: "creatorSig",
            counterpartyPublicKey: counterpartyPublicKey,
            counterpartySignSignature: counterpartySignSignature,
            createdAt: .now,
            updatedAt: .now
        )
    }

    @Test func testCounterpartySetsSignSignature() async throws {
        // Arrange
        let mockKeychain = MockKeychainRepository()
        let mockPropose = MockProposeRepository()

        let proposeID = UUID()
        let identityID = UUID()
        let counterpartyKey = "counterpartyPubKey"
        let testPropose = makePropose(id: proposeID, counterpartyPublicKey: counterpartyKey)

        let testIdentity = Identity(id: identityID, nickname: "Bob", publicKey: counterpartyKey)
        mockKeychain.getIdentityResult = testIdentity
        mockKeychain.signMessageResult = "newCounterpartySig"

        let useCase = SignProposeUseCaseImpl(
            keychainRepository: mockKeychain,
            proposeRepository: mockPropose,
            apiClient: MockProposeAPIClient()
        )

        // Act
        try await useCase.execute(propose: testPropose, identityID: identityID, serverURLs: ["https://example.com"])

        // Assert: counterpartySignSignature is set
        #expect(mockPropose.updateCalled == true)
        #expect(mockPropose.updatedPropose?.counterpartySignSignature == "newCounterpartySig")
        #expect(mockPropose.updatedPropose?.counterpartyPublicKey == counterpartyKey)
    }

    @Test func testLocalStatusBecomesSignedAfterSign() async throws {
        // Arrange
        let mockKeychain = MockKeychainRepository()
        let mockPropose = MockProposeRepository()

        let proposeID = UUID()
        let identityID = UUID()
        let counterpartyKey = "counterpartyPubKey"
        let testPropose = makePropose(id: proposeID, counterpartyPublicKey: counterpartyKey)

        let testIdentity = Identity(id: identityID, nickname: "Bob", publicKey: counterpartyKey)
        mockKeychain.getIdentityResult = testIdentity
        mockKeychain.signMessageResult = "newCounterpartySig"

        let useCase = SignProposeUseCaseImpl(
            keychainRepository: mockKeychain,
            proposeRepository: mockPropose,
            apiClient: MockProposeAPIClient()
        )

        // Act
        try await useCase.execute(propose: testPropose, identityID: identityID, serverURLs: ["https://example.com"])

        // Assert: status is signed after signing
        #expect(mockPropose.updatedPropose?.localStatus == .signed)
    }

    @Test func testThrowsNotCounterpartyWhenCreatorTriesToSign() async throws {
        // Arrange
        let mockKeychain = MockKeychainRepository()
        let mockPropose = MockProposeRepository()

        let proposeID = UUID()
        let identityID = UUID()
        let creatorKey = "creatorPubKey"
        // Creator attempts to Sign (counterpartyPublicKey is a different key)
        let testPropose = makePropose(id: proposeID, creatorPublicKey: creatorKey, counterpartyPublicKey: "differentKey")

        let testIdentity = Identity(id: identityID, nickname: "Alice", publicKey: creatorKey)
        mockKeychain.getIdentityResult = testIdentity

        let useCase = SignProposeUseCaseImpl(
            keychainRepository: mockKeychain,
            proposeRepository: mockPropose,
            apiClient: MockProposeAPIClient()
        )

        // Act & Assert: notCounterparty error is thrown
        await #expect(throws: SignProposeUseCaseError.notCounterparty) {
            try await useCase.execute(propose: testPropose, identityID: identityID, serverURLs: ["https://example.com"])
        }
    }

    @Test func testThrowsNotCounterpartyWhenUnrelatedKeyTriesToSign() async throws {
        // Arrange
        let mockKeychain = MockKeychainRepository()
        let mockPropose = MockProposeRepository()

        let identityID = UUID()
        let testPropose = makePropose(creatorPublicKey: "creatorKey", counterpartyPublicKey: "counterpartyKey")

        // Attempt to Sign with an unrelated key
        let unrelatedIdentity = Identity(id: identityID, nickname: "Eve", publicKey: "unrelatedKey")
        mockKeychain.getIdentityResult = unrelatedIdentity

        let useCase = SignProposeUseCaseImpl(
            keychainRepository: mockKeychain,
            proposeRepository: mockPropose,
            apiClient: MockProposeAPIClient()
        )

        // Act & Assert
        await #expect(throws: SignProposeUseCaseError.notCounterparty) {
            try await useCase.execute(propose: testPropose, identityID: identityID, serverURLs: ["https://example.com"])
        }
    }

    @Test func testThrowsFailedToSaveProposeWhenUpdateFails() async throws {
        // Arrange
        let mockKeychain = MockKeychainRepository()
        let mockPropose = MockProposeRepository()

        let proposeID = UUID()
        let identityID = UUID()
        let counterpartyKey = "counterpartyKey"
        let testPropose = makePropose(id: proposeID, counterpartyPublicKey: counterpartyKey)

        let testIdentity = Identity(id: identityID, nickname: "Bob", publicKey: counterpartyKey)
        mockKeychain.getIdentityResult = testIdentity
        mockKeychain.signMessageResult = "newsignature"
        mockPropose.updateError = NSError(domain: "Test", code: -1)

        let useCase = SignProposeUseCaseImpl(
            keychainRepository: mockKeychain,
            proposeRepository: mockPropose,
            apiClient: MockProposeAPIClient()
        )

        // Act & Assert
        await #expect(throws: SignProposeUseCaseError.failedToSavePropose) {
            try await useCase.execute(propose: testPropose, identityID: identityID, serverURLs: ["https://example.com"])
        }
    }

    @Test func testThrowsWhenGetIdentityFails() async throws {
        // Arrange
        let mockKeychain = MockKeychainRepository()
        let mockPropose = MockProposeRepository()

        mockKeychain.getIdentityError = KeychainError.itemNotFound

        let useCase = SignProposeUseCaseImpl(
            keychainRepository: mockKeychain,
            proposeRepository: mockPropose,
            apiClient: MockProposeAPIClient()
        )

        // Act & Assert
        await #expect(throws: KeychainError.itemNotFound) {
            try await useCase.execute(propose: makePropose(), identityID: UUID(), serverURLs: ["https://example.com"])
        }
    }

    @Test func testThrowsWhenSignMessageFails() async throws {
        // Arrange
        let mockKeychain = MockKeychainRepository()
        let mockPropose = MockProposeRepository()

        let proposeID = UUID()
        let identityID = UUID()
        let counterpartyKey = "counterpartyKey"
        let testPropose = makePropose(id: proposeID, counterpartyPublicKey: counterpartyKey)

        let testIdentity = Identity(id: identityID, nickname: "Bob", publicKey: counterpartyKey)
        mockKeychain.getIdentityResult = testIdentity
        mockKeychain.signMessageError = KeychainError.biometricAuthFailed

        let useCase = SignProposeUseCaseImpl(
            keychainRepository: mockKeychain,
            proposeRepository: mockPropose,
            apiClient: MockProposeAPIClient()
        )

        // Act & Assert
        await #expect(throws: KeychainError.biometricAuthFailed) {
            try await useCase.execute(propose: testPropose, identityID: identityID, serverURLs: ["https://example.com"])
        }
    }
}
