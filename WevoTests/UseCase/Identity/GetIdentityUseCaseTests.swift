//
//  GetIdentityUseCaseTests.swift
//  WevoTests
//
//  Created by hidemune on 3/10/26.
//

import Testing
import Foundation
@testable import Wevo

struct GetIdentityUseCaseTests {

    @Test func testReturnsIdentityFromRepository() throws {
        // Arrange
        let mockRepository = MockKeychainRepository()
        let testID = UUID()
        let testIdentity = Identity(id: testID, nickname: "Alice", publicKey: "pubkey123")
        mockRepository.getIdentityResult = testIdentity
        let useCase = GetIdentityUseCaseImpl(keychainRepository: mockRepository)

        // Act
        let result = try useCase.execute(id: testID)

        // Assert
        #expect(result.id == testID)
        #expect(result.nickname == "Alice")
        #expect(mockRepository.getIdentityCalledWithID == testID)
    }

    @Test func testThrowsWhenRepositoryThrows() throws {
        // Arrange
        let mockRepository = MockKeychainRepository()
        mockRepository.getIdentityError = KeychainError.itemNotFound
        let useCase = GetIdentityUseCaseImpl(keychainRepository: mockRepository)

        // Act & Assert
        #expect(throws: KeychainError.itemNotFound) {
            try useCase.execute(id: UUID())
        }
    }
}
