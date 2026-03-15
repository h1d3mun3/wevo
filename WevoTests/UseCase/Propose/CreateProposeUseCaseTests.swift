//
//  CreateProposeUseCaseTests.swift
//  WevoTests
//
//  Created by hidemune on 3/10/26.
//

import Testing
import Foundation
@testable import Wevo

@MainActor
struct CreateProposeUseCaseTests {

    private let counterpartyPublicKey = "counterpartyPubKey123"

    @Test func testCreatesAndSavesPropose() async throws {
        // Arrange
        let mockKeychain = MockKeychainRepository()
        let mockSpace = MockSpaceRepository()
        let mockPropose = MockProposeRepository()

        let identityID = UUID()
        let spaceID = UUID()
        let testIdentity = Identity(id: identityID, nickname: "Alice", publicKey: "pubkey123")
        let testSpace = Space(id: spaceID, name: "Test Space", url: "https://example.com", defaultIdentityID: nil, orderIndex: 0, createdAt: .now, updatedAt: .now)

        mockKeychain.getIdentityResult = testIdentity
        mockKeychain.signMessageResult = "signature123"
        mockSpace.fetchByIDResult = testSpace

        let useCase = CreateProposeUseCaseImpl(
            keychainRepository: mockKeychain,
            spaceRepository: mockSpace,
            proposeRepository: mockPropose
        )

        // Act
        try await useCase.execute(identityID: identityID, spaceID: spaceID, message: "Test message", counterpartyPublicKey: counterpartyPublicKey)

        // Assert
        #expect(mockKeychain.getIdentityCalledWithID == identityID)
        #expect(mockSpace.fetchByIDCalledWithID == spaceID)
        #expect(mockPropose.createCalled == true)
        #expect(mockPropose.createdSpaceID == spaceID)
        #expect(mockPropose.createdPropose?.message == "Test message")
    }

    @Test func testCreatorPublicKeyIsSetCorrectly() async throws {
        // Arrange
        let mockKeychain = MockKeychainRepository()
        let mockSpace = MockSpaceRepository()
        let mockPropose = MockProposeRepository()

        let identityID = UUID()
        let spaceID = UUID()
        let testIdentity = Identity(id: identityID, nickname: "Alice", publicKey: "pubkey123")
        let testSpace = Space(id: spaceID, name: "Test", url: "https://example.com", defaultIdentityID: nil, orderIndex: 0, createdAt: .now, updatedAt: .now)

        mockKeychain.getIdentityResult = testIdentity
        mockKeychain.signMessageResult = "signature123"
        mockSpace.fetchByIDResult = testSpace

        let useCase = CreateProposeUseCaseImpl(
            keychainRepository: mockKeychain,
            spaceRepository: mockSpace,
            proposeRepository: mockPropose
        )

        // Act
        try await useCase.execute(identityID: identityID, spaceID: spaceID, message: "Test message", counterpartyPublicKey: counterpartyPublicKey)

        // Assert: creatorPublicKey and counterpartyPublicKey are correctly set
        #expect(mockPropose.createdPropose?.creatorPublicKey == "pubkey123")
        #expect(mockPropose.createdPropose?.counterpartyPublicKey == counterpartyPublicKey)
        #expect(mockPropose.createdPropose?.counterpartySignSignature == nil)
    }

    @Test func testLocalStatusIsProposedAfterCreate() async throws {
        // Arrange
        let mockKeychain = MockKeychainRepository()
        let mockSpace = MockSpaceRepository()
        let mockPropose = MockProposeRepository()

        let identityID = UUID()
        let spaceID = UUID()
        let testIdentity = Identity(id: identityID, nickname: "Alice", publicKey: "pubkey123")
        let testSpace = Space(id: spaceID, name: "Test", url: "https://example.com", defaultIdentityID: nil, orderIndex: 0, createdAt: .now, updatedAt: .now)

        mockKeychain.getIdentityResult = testIdentity
        mockKeychain.signMessageResult = "signature123"
        mockSpace.fetchByIDResult = testSpace

        let useCase = CreateProposeUseCaseImpl(
            keychainRepository: mockKeychain,
            spaceRepository: mockSpace,
            proposeRepository: mockPropose
        )

        // Act
        try await useCase.execute(identityID: identityID, spaceID: spaceID, message: "Test message", counterpartyPublicKey: counterpartyPublicKey)

        // Assert: immediately after creation, counterpartySignSignature is nil so status is proposed
        #expect(mockPropose.createdPropose?.localStatus == .proposed)
    }

    @Test func testSignsCreatorMessage() async throws {
        // Arrange
        let mockKeychain = MockKeychainRepository()
        let mockSpace = MockSpaceRepository()
        let mockPropose = MockProposeRepository()

        let identityID = UUID()
        let spaceID = UUID()
        let testIdentity = Identity(id: identityID, nickname: "Alice", publicKey: "pubkey123")
        let testSpace = Space(id: spaceID, name: "Test", url: "https://example.com", defaultIdentityID: nil, orderIndex: 0, createdAt: .now, updatedAt: .now)

        mockKeychain.getIdentityResult = testIdentity
        mockKeychain.signMessageResult = "signature123"
        mockSpace.fetchByIDResult = testSpace

        let useCase = CreateProposeUseCaseImpl(
            keychainRepository: mockKeychain,
            spaceRepository: mockSpace,
            proposeRepository: mockPropose
        )

        // Act
        try await useCase.execute(identityID: identityID, spaceID: spaceID, message: "Test message", counterpartyPublicKey: counterpartyPublicKey)

        // Assert: signMessage was called
        #expect(mockKeychain.signMessageCalledWithIdentityID == identityID)
        #expect(mockKeychain.signMessageCalledWithMessage != nil)
    }

    @Test func testThrowsWhenGetIdentityFails() async throws {
        // Arrange
        let mockKeychain = MockKeychainRepository()
        let mockSpace = MockSpaceRepository()
        let mockPropose = MockProposeRepository()

        mockKeychain.getIdentityError = KeychainError.itemNotFound

        let useCase = CreateProposeUseCaseImpl(
            keychainRepository: mockKeychain,
            spaceRepository: mockSpace,
            proposeRepository: mockPropose
        )

        // Act & Assert
        await #expect(throws: KeychainError.itemNotFound) {
            try await useCase.execute(identityID: UUID(), spaceID: UUID(), message: "test", counterpartyPublicKey: counterpartyPublicKey)
        }
    }

    @Test func testThrowsWhenSpaceFetchFails() async throws {
        // Arrange
        let mockKeychain = MockKeychainRepository()
        let mockSpace = MockSpaceRepository()
        let mockPropose = MockProposeRepository()

        let identityID = UUID()
        let testIdentity = Identity(id: identityID, nickname: "Alice", publicKey: "pubkey123")
        mockKeychain.getIdentityResult = testIdentity
        mockSpace.fetchByIDError = NSError(domain: "Test", code: -1)

        let useCase = CreateProposeUseCaseImpl(
            keychainRepository: mockKeychain,
            spaceRepository: mockSpace,
            proposeRepository: mockPropose
        )

        // Act & Assert
        await #expect(throws: NSError.self) {
            try await useCase.execute(identityID: identityID, spaceID: UUID(), message: "test", counterpartyPublicKey: counterpartyPublicKey)
        }
    }

    @Test func testThrowsWhenSignMessageFails() async throws {
        // Arrange
        let mockKeychain = MockKeychainRepository()
        let mockSpace = MockSpaceRepository()
        let mockPropose = MockProposeRepository()

        let identityID = UUID()
        let spaceID = UUID()
        let testIdentity = Identity(id: identityID, nickname: "Alice", publicKey: "pubkey123")
        let testSpace = Space(id: spaceID, name: "Test", url: "https://example.com", defaultIdentityID: nil, orderIndex: 0, createdAt: .now, updatedAt: .now)

        mockKeychain.getIdentityResult = testIdentity
        mockKeychain.signMessageError = KeychainError.biometricAuthFailed
        mockSpace.fetchByIDResult = testSpace

        let useCase = CreateProposeUseCaseImpl(
            keychainRepository: mockKeychain,
            spaceRepository: mockSpace,
            proposeRepository: mockPropose
        )

        // Act & Assert
        await #expect(throws: KeychainError.biometricAuthFailed) {
            try await useCase.execute(identityID: identityID, spaceID: spaceID, message: "test", counterpartyPublicKey: counterpartyPublicKey)
        }
    }

    @Test func testThrowsWhenProposeCreateFails() async throws {
        // Arrange
        let mockKeychain = MockKeychainRepository()
        let mockSpace = MockSpaceRepository()
        let mockPropose = MockProposeRepository()

        let identityID = UUID()
        let spaceID = UUID()
        let testIdentity = Identity(id: identityID, nickname: "Alice", publicKey: "pubkey123")
        let testSpace = Space(id: spaceID, name: "Test", url: "https://example.com", defaultIdentityID: nil, orderIndex: 0, createdAt: .now, updatedAt: .now)

        mockKeychain.getIdentityResult = testIdentity
        mockKeychain.signMessageResult = "signature123"
        mockSpace.fetchByIDResult = testSpace
        mockPropose.createError = NSError(domain: "Test", code: -1)

        let useCase = CreateProposeUseCaseImpl(
            keychainRepository: mockKeychain,
            spaceRepository: mockSpace,
            proposeRepository: mockPropose
        )

        // Act & Assert
        await #expect(throws: NSError.self) {
            try await useCase.execute(identityID: identityID, spaceID: spaceID, message: "test", counterpartyPublicKey: counterpartyPublicKey)
        }
    }

    @Test func testDoesNotThrowWhenURLIsInvalid() async throws {
        // Arrange
        let mockKeychain = MockKeychainRepository()
        let mockSpace = MockSpaceRepository()
        let mockPropose = MockProposeRepository()

        let identityID = UUID()
        let spaceID = UUID()
        let testIdentity = Identity(id: identityID, nickname: "Alice", publicKey: "pubkey123")
        let testSpace = Space(id: spaceID, name: "Test", url: "not a valid url", defaultIdentityID: nil, orderIndex: 0, createdAt: .now, updatedAt: .now)

        mockKeychain.getIdentityResult = testIdentity
        mockKeychain.signMessageResult = "signature123"
        mockSpace.fetchByIDResult = testSpace

        let useCase = CreateProposeUseCaseImpl(
            keychainRepository: mockKeychain,
            spaceRepository: mockSpace,
            proposeRepository: mockPropose
        )

        // Act & Assert: does not throw even with an invalid URL (warning only)
        try await useCase.execute(identityID: identityID, spaceID: spaceID, message: "test", counterpartyPublicKey: counterpartyPublicKey)
        #expect(mockPropose.createCalled == true)
    }
}
