//
//  LoadIdentitiesWithDefaultSelectionUseCaseTests.swift
//  WevoTests
//
//  Created on 3/17/26.
//

import Testing
import Foundation
@testable import Wevo

struct LoadIdentitiesWithDefaultSelectionUseCaseTests {

    @Test func testReturnsIdentitiesAndFirstIDAsDefault() throws {
        // Arrange
        let mockRepository = MockKeychainRepository()
        let firstID = UUID()
        mockRepository.getAllIdentitiesResult = [
            Identity(id: firstID, nickname: "Alice", publicKey: "pk1"),
            Identity(id: UUID(), nickname: "Bob", publicKey: "pk2")
        ]
        let useCase = LoadIdentitiesWithDefaultSelectionUseCaseImpl(keychainRepository: mockRepository)

        // Act
        let (identities, defaultID) = try useCase.execute()

        // Assert
        #expect(identities.count == 2)
        #expect(defaultID == firstID)
    }

    @Test func testReturnsNilDefaultIDWhenEmpty() throws {
        // Arrange
        let mockRepository = MockKeychainRepository()
        mockRepository.getAllIdentitiesResult = []
        let useCase = LoadIdentitiesWithDefaultSelectionUseCaseImpl(keychainRepository: mockRepository)

        // Act
        let (identities, defaultID) = try useCase.execute()

        // Assert
        #expect(identities.isEmpty)
        #expect(defaultID == nil)
    }

    @Test func testReturnsSingleIdentityWithItsIDAsDefault() throws {
        // Arrange
        let mockRepository = MockKeychainRepository()
        let onlyID = UUID()
        mockRepository.getAllIdentitiesResult = [
            Identity(id: onlyID, nickname: "Solo", publicKey: "pk_solo")
        ]
        let useCase = LoadIdentitiesWithDefaultSelectionUseCaseImpl(keychainRepository: mockRepository)

        // Act
        let (identities, defaultID) = try useCase.execute()

        // Assert
        #expect(identities.count == 1)
        #expect(defaultID == onlyID)
    }

    @Test func testThrowsWhenRepositoryThrows() throws {
        // Arrange
        let mockRepository = MockKeychainRepository()
        mockRepository.getAllIdentitiesError = KeychainError.invalidData
        let useCase = LoadIdentitiesWithDefaultSelectionUseCaseImpl(keychainRepository: mockRepository)

        // Act & Assert
        #expect(throws: KeychainError.invalidData) {
            try useCase.execute()
        }
    }
}
