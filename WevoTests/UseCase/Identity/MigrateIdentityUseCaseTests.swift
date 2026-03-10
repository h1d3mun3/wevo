//
//  MigrateIdentityUseCaseTests.swift
//  WevoTests
//
//  Created by hidemune on 3/10/26.
//

import Testing
import Foundation
@testable import Wevo

struct MigrateIdentityUseCaseTests {

    @Test func testCallsMigrateKeyWithCorrectID() throws {
        // Arrange
        let mockRepository = MockKeychainRepository()
        let useCase = MigrateIdentityUseCaseImpl(keychainRepository: mockRepository)
        let testID = UUID()

        // Act
        try useCase.execute(id: testID)

        // Assert
        #expect(mockRepository.migrateKeyCalled == true)
        #expect(mockRepository.migrateKeyCalledWithID == testID)
    }

    @Test func testThrowsWhenRepositoryThrows() throws {
        // Arrange
        let mockRepository = MockKeychainRepository()
        mockRepository.migrateKeyError = KeychainError.itemNotFound
        let useCase = MigrateIdentityUseCaseImpl(keychainRepository: mockRepository)

        // Act & Assert
        #expect(throws: KeychainError.itemNotFound) {
            try useCase.execute(id: UUID())
        }
    }
}
