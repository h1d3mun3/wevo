//
//  GetAllIdentitiesUseCaseTests.swift
//  WevoTests
//
//  Created by hidemune on 3/10/26.
//

import Testing
import Foundation
@testable import Wevo

struct GetAllIdentitiesUseCaseTests {

    @Test func testReturnsAllIdentitiesFromRepository() throws {
        // Arrange
        let mockRepository = MockKeychainRepository()
        let testIdentities = [
            Identity(id: UUID(), nickname: "Alice", publicKey: "pubkey1"),
            Identity(id: UUID(), nickname: "Bob", publicKey: "pubkey2")
        ]
        mockRepository.getAllIdentitiesResult = testIdentities
        let useCase = GetAllIdentitiesUseCaseImpl(keychainRepository: mockRepository)

        // Act
        let result = try useCase.execute()

        // Assert
        #expect(result.count == 2)
        #expect(result[0].nickname == "Alice")
        #expect(result[1].nickname == "Bob")
    }

    @Test func testReturnsEmptyArrayWhenNoIdentities() throws {
        // Arrange
        let mockRepository = MockKeychainRepository()
        mockRepository.getAllIdentitiesResult = []
        let useCase = GetAllIdentitiesUseCaseImpl(keychainRepository: mockRepository)

        // Act
        let result = try useCase.execute()

        // Assert
        #expect(result.count == 0)
    }

    @Test func testThrowsWhenRepositoryThrows() throws {
        // Arrange
        let mockRepository = MockKeychainRepository()
        mockRepository.getAllIdentitiesError = KeychainError.invalidData
        let useCase = GetAllIdentitiesUseCaseImpl(keychainRepository: mockRepository)

        // Act & Assert
        #expect(throws: KeychainError.invalidData) {
            try useCase.execute()
        }
    }
}
