//
//  GetContactNicknamesMapUseCaseTests.swift
//  WevoTests
//
//  Created on 3/17/26.
//

import Testing
import Foundation
@testable import Wevo

@MainActor
struct GetContactNicknamesMapUseCaseTests {

    @Test func testReturnsMapFromContacts() throws {
        // Arrange
        let mockRepository = MockContactRepository()
        mockRepository.fetchAllResult = [
            Contact(id: UUID(), nickname: "Alice", publicKey: "pk1", createdAt: .now),
            Contact(id: UUID(), nickname: "Bob", publicKey: "pk2", createdAt: .now)
        ]
        let useCase = GetContactNicknamesMapUseCaseImpl(contactRepository: mockRepository)

        // Act
        let result = try useCase.execute()

        // Assert
        #expect(result.count == 2)
        #expect(result["pk1"] == "Alice")
        #expect(result["pk2"] == "Bob")
    }

    @Test func testReturnsEmptyMapWhenNoContacts() throws {
        // Arrange
        let mockRepository = MockContactRepository()
        mockRepository.fetchAllResult = []
        let useCase = GetContactNicknamesMapUseCaseImpl(contactRepository: mockRepository)

        // Act
        let result = try useCase.execute()

        // Assert
        #expect(result.isEmpty)
    }

    @Test func testThrowsWhenRepositoryThrows() throws {
        // Arrange
        let mockRepository = MockContactRepository()
        mockRepository.fetchAllError = NSError(domain: "Test", code: -1)
        let useCase = GetContactNicknamesMapUseCaseImpl(contactRepository: mockRepository)

        // Act & Assert
        #expect(throws: NSError.self) {
            try useCase.execute()
        }
    }

    @Test func testDoesNotCrashWithDuplicatePublicKeys() throws {
        // Arrange
        let mockRepository = MockContactRepository()
        mockRepository.fetchAllResult = [
            Contact(id: UUID(), nickname: "Alice", publicKey: "pk1", createdAt: .now),
            Contact(id: UUID(), nickname: "Alice2", publicKey: "pk1", createdAt: .now)
        ]
        let useCase = GetContactNicknamesMapUseCaseImpl(contactRepository: mockRepository)

        // Act
        let result = try useCase.execute()

        // Assert
        #expect(result.count == 1)
        #expect(result["pk1"] == "Alice")
    }

    @Test func testUsesPublicKeyAsKey() throws {
        // Arrange
        let mockRepository = MockContactRepository()
        let publicKey = "someBase64EncodedPublicKey"
        mockRepository.fetchAllResult = [
            Contact(id: UUID(), nickname: "Charlie", publicKey: publicKey, createdAt: .now)
        ]
        let useCase = GetContactNicknamesMapUseCaseImpl(contactRepository: mockRepository)

        // Act
        let result = try useCase.execute()

        // Assert
        #expect(result[publicKey] == "Charlie")
    }
}
