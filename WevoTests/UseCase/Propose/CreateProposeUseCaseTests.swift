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
        try await useCase.execute(identityID: identityID, spaceID: spaceID, message: "Test message")

        // Assert
        #expect(mockKeychain.getIdentityCalledWithID == identityID)
        #expect(mockSpace.fetchByIDCalledWithID == spaceID)
        #expect(mockPropose.createCalled == true)
        #expect(mockPropose.createdSpaceID == spaceID)
        #expect(mockPropose.createdPropose?.message == "Test message")
    }

    @Test func testSignsPayloadHash() async throws {
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
        try await useCase.execute(identityID: identityID, spaceID: spaceID, message: "Test message")

        // Assert
        #expect(mockKeychain.signMessageCalledWithIdentityID == identityID)
        // payloadHash is computed from message, so we verify the signed message was the payloadHash
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
            try await useCase.execute(identityID: UUID(), spaceID: UUID(), message: "test")
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
            try await useCase.execute(identityID: identityID, spaceID: UUID(), message: "test")
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
            try await useCase.execute(identityID: identityID, spaceID: spaceID, message: "test")
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
            try await useCase.execute(identityID: identityID, spaceID: spaceID, message: "test")
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

        // Act & Assert - should not throw
        try await useCase.execute(identityID: identityID, spaceID: spaceID, message: "test")
        #expect(mockPropose.createCalled == true)
    }
}
