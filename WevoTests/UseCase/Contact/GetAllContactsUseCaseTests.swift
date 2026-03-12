//
//  GetAllContactsUseCaseTests.swift
//  WevoTests
//
//  Created by hidemune on 3/12/26.
//

import Testing
import Foundation
@testable import Wevo

@MainActor
struct GetAllContactsUseCaseTests {

    @Test func testReturnsContactsFromRepository() throws {
        // Arrange
        let mockRepository = MockContactRepository()
        mockRepository.fetchAllResult = [
            Contact(id: UUID(), nickname: "Alice", publicKey: "pk1", createdAt: .now),
            Contact(id: UUID(), nickname: "Bob", publicKey: "pk2", createdAt: .now)
        ]
        let useCase = GetAllContactsUseCaseImpl(contactRepository: mockRepository)

        // Act
        let result = try useCase.execute()

        // Assert
        #expect(result.count == 2)
        #expect(result[0].nickname == "Alice")
        #expect(result[1].nickname == "Bob")
    }

    @Test func testReturnsEmptyArray() throws {
        // Arrange
        let mockRepository = MockContactRepository()
        mockRepository.fetchAllResult = []
        let useCase = GetAllContactsUseCaseImpl(contactRepository: mockRepository)

        // Act
        let result = try useCase.execute()

        // Assert
        #expect(result.isEmpty)
    }

    @Test func testThrowsWhenRepositoryThrows() throws {
        // Arrange
        let mockRepository = MockContactRepository()
        mockRepository.fetchAllError = NSError(domain: "Test", code: -1)
        let useCase = GetAllContactsUseCaseImpl(contactRepository: mockRepository)

        // Act & Assert
        #expect(throws: NSError.self) {
            try useCase.execute()
        }
    }
}
