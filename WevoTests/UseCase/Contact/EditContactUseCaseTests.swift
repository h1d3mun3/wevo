//
//  EditContactUseCaseTests.swift
//  WevoTests
//
//  Created by hidemune on 3/12/26.
//

import Testing
import Foundation
@testable import Wevo

// MARK: - Mock GetContactUseCase

class MockGetContactUseCase: GetContactUseCase {
    var result: Contact?
    var error: Error?

    func execute(id: UUID) throws -> Contact {
        if let error = error { throw error }
        guard let result = result else {
            throw NSError(domain: "MockGetContactUseCase", code: -1)
        }
        return result
    }
}

// MARK: - Tests

@MainActor
struct EditContactUseCaseTests {

    @Test func testUpdatesContactWithTrimmedValues() throws {
        // Arrange
        let mockRepository = MockContactRepository()
        let mockGetContactUseCase = MockGetContactUseCase()
        let contactID = UUID()
        let createdAt = Date(timeIntervalSince1970: 1000)
        mockGetContactUseCase.result = Contact(id: contactID, nickname: "Alice", publicKey: "oldKey", createdAt: createdAt)

        let useCase = EditContactUseCaseImpl(
            contactRepository: mockRepository,
            getContactUseCase: mockGetContactUseCase
        )

        // Act
        try useCase.execute(id: contactID, nickname: "  Alice Updated  ", publicKey: "  newKey  ")

        // Assert
        #expect(mockRepository.updateCalled == true)
        #expect(mockRepository.updatedContact?.nickname == "Alice Updated")
        #expect(mockRepository.updatedContact?.publicKey == "newKey")
    }

    @Test func testPreservesOriginalMetadata() throws {
        // Arrange
        let mockRepository = MockContactRepository()
        let mockGetContactUseCase = MockGetContactUseCase()
        let contactID = UUID()
        let createdAt = Date(timeIntervalSince1970: 1000)
        mockGetContactUseCase.result = Contact(id: contactID, nickname: "Alice", publicKey: "oldKey", createdAt: createdAt)

        let useCase = EditContactUseCaseImpl(
            contactRepository: mockRepository,
            getContactUseCase: mockGetContactUseCase
        )

        // Act
        try useCase.execute(id: contactID, nickname: "Alice Updated", publicKey: "newKey")

        // Assert
        #expect(mockRepository.updatedContact?.id == contactID)
        #expect(mockRepository.updatedContact?.createdAt == createdAt)
    }

    @Test func testThrowsWhenGetContactFails() throws {
        // Arrange
        let mockRepository = MockContactRepository()
        let mockGetContactUseCase = MockGetContactUseCase()
        mockGetContactUseCase.error = NSError(domain: "Test", code: -1)

        let useCase = EditContactUseCaseImpl(
            contactRepository: mockRepository,
            getContactUseCase: mockGetContactUseCase
        )

        // Act & Assert
        #expect(throws: NSError.self) {
            try useCase.execute(id: UUID(), nickname: "Alice", publicKey: "pk")
        }
    }

    @Test func testThrowsWhenUpdateFails() throws {
        // Arrange
        let mockRepository = MockContactRepository()
        let mockGetContactUseCase = MockGetContactUseCase()
        mockGetContactUseCase.result = Contact(id: UUID(), nickname: "Alice", publicKey: "pk", createdAt: .now)
        mockRepository.updateError = NSError(domain: "Test", code: -1)

        let useCase = EditContactUseCaseImpl(
            contactRepository: mockRepository,
            getContactUseCase: mockGetContactUseCase
        )

        // Act & Assert
        #expect(throws: NSError.self) {
            try useCase.execute(id: UUID(), nickname: "Alice Updated", publicKey: "newKey")
        }
    }
}
