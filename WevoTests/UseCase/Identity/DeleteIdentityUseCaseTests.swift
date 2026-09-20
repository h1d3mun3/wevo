//
//  DeleteIdentityUseCaseTests.swift
//  WevoTests
//
//  Created by hidemune on 3/10/26.
//

import Testing
import Foundation
@testable import Wevo

struct DeleteIdentityUseCaseTests {

    @Test func testCallsDeleteIdentityKeyWithCorrectID() throws {
        // Arrange
        let mockRepository = MockKeychainRepository()
        let useCase = DeleteIdentityUseCaseImpl(keychainRepository: mockRepository)
        let testID = UUID()

        // Act
        try useCase.execute(id: testID)

        // Assert
        #expect(mockRepository.deleteIdentityKeyCalled == true)
        #expect(mockRepository.deletedIdentityID == testID)
    }

    @Test func testThrowsWhenRepositoryThrows() throws {
        // Arrange
        let mockRepository = MockKeychainRepository()
        mockRepository.deleteIdentityKeyError = KeychainError.itemNotFound
        let useCase = DeleteIdentityUseCaseImpl(keychainRepository: mockRepository)

        // Act & Assert
        #expect(throws: KeychainError.itemNotFound) {
            try useCase.execute(id: UUID())
        }
    }
}
