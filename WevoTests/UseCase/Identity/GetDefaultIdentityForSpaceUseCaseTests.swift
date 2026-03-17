//
//  GetDefaultIdentityForSpaceUseCaseTests.swift
//  WevoTests
//
//  Created on 3/17/26.
//

import Testing
import Foundation
@testable import Wevo

struct GetDefaultIdentityForSpaceUseCaseTests {

    private func makeSpace(defaultIdentityID: UUID?) -> Space {
        Space(
            id: UUID(),
            name: "Test Space",
            url: "https://example.com",
            defaultIdentityID: defaultIdentityID,
            orderIndex: 0,
            createdAt: .now,
            updatedAt: .now
        )
    }

    @Test func testReturnsMatchingIdentityWhenFound() throws {
        // Arrange
        let mockRepository = MockKeychainRepository()
        let targetID = UUID()
        let targetIdentity = Identity(id: targetID, nickname: "Target", publicKey: "pk_target")
        mockRepository.getAllIdentitiesResult = [
            Identity(id: UUID(), nickname: "Other", publicKey: "pk_other"),
            targetIdentity
        ]
        let space = makeSpace(defaultIdentityID: targetID)
        let useCase = GetDefaultIdentityForSpaceUseCaseImpl(keychainRepository: mockRepository)

        // Act
        let result = try useCase.execute(space: space)

        // Assert
        #expect(result?.id == targetID)
        #expect(result?.nickname == "Target")
    }

    @Test func testReturnsNilWhenDefaultIdentityIDIsNil() throws {
        // Arrange
        let mockRepository = MockKeychainRepository()
        mockRepository.getAllIdentitiesResult = [
            Identity(id: UUID(), nickname: "Alice", publicKey: "pk1")
        ]
        let space = makeSpace(defaultIdentityID: nil)
        let useCase = GetDefaultIdentityForSpaceUseCaseImpl(keychainRepository: mockRepository)

        // Act
        let result = try useCase.execute(space: space)

        // Assert
        #expect(result == nil)
    }

    @Test func testReturnsNilWhenIdentityNotFoundInRepository() throws {
        // Arrange
        let mockRepository = MockKeychainRepository()
        mockRepository.getAllIdentitiesResult = [
            Identity(id: UUID(), nickname: "Alice", publicKey: "pk1")
        ]
        let space = makeSpace(defaultIdentityID: UUID()) // Unknown ID
        let useCase = GetDefaultIdentityForSpaceUseCaseImpl(keychainRepository: mockRepository)

        // Act
        let result = try useCase.execute(space: space)

        // Assert
        #expect(result == nil)
    }

    @Test func testThrowsWhenRepositoryThrows() throws {
        // Arrange
        let mockRepository = MockKeychainRepository()
        mockRepository.getAllIdentitiesError = KeychainError.invalidData
        let space = makeSpace(defaultIdentityID: UUID())
        let useCase = GetDefaultIdentityForSpaceUseCaseImpl(keychainRepository: mockRepository)

        // Act & Assert
        #expect(throws: KeychainError.invalidData) {
            try useCase.execute(space: space)
        }
    }

    @Test func testDoesNotCallRepositoryWhenDefaultIdentityIDIsNil() throws {
        // Arrange
        let mockRepository = MockKeychainRepository()
        // getAllIdentitiesError set to ensure it would fail if called
        mockRepository.getAllIdentitiesError = KeychainError.invalidData
        let space = makeSpace(defaultIdentityID: nil)
        let useCase = GetDefaultIdentityForSpaceUseCaseImpl(keychainRepository: mockRepository)

        // Act - should NOT throw because repository is not called when defaultIdentityID is nil
        let result = try useCase.execute(space: space)

        // Assert
        #expect(result == nil)
    }
}
