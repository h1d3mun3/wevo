//
//  GetContactUseCaseTests.swift
//  WevoTests
//
//  Created by hidemune on 3/12/26.
//

import Testing
import Foundation
@testable import Wevo

@MainActor
struct GetContactUseCaseTests {

    @Test func testReturnsContactForGivenID() throws {
        // Arrange
        let mockRepository = MockContactRepository()
        let contactID = UUID()
        mockRepository.fetchByIDResult = Contact(id: contactID, nickname: "Alice", publicKey: "pk1", createdAt: .now)
        let useCase = GetContactUseCaseImpl(contactRepository: mockRepository)

        // Act
        let result = try useCase.execute(id: contactID)

        // Assert
        #expect(mockRepository.fetchByIDCalledWithID == contactID)
        #expect(result.id == contactID)
        #expect(result.nickname == "Alice")
    }

    @Test func testThrowsWhenRepositoryThrows() throws {
        // Arrange
        let mockRepository = MockContactRepository()
        mockRepository.fetchByIDError = NSError(domain: "Test", code: -1)
        let useCase = GetContactUseCaseImpl(contactRepository: mockRepository)

        // Act & Assert
        #expect(throws: NSError.self) {
            try useCase.execute(id: UUID())
        }
    }
}
