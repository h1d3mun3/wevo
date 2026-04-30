//
//  CreateContactUseCaseTests.swift
//  WevoTests
//
//  Created by hidemune on 3/12/26.
//

import Testing
import Foundation
@testable import Wevo

@MainActor
struct CreateContactUseCaseTests {

    @Test func testCreatesContactWithCorrectValues() throws {
        // Arrange
        let mockRepository = MockContactRepository()
        let useCase = CreateContactUseCaseImpl(contactRepository: mockRepository)

        // Act
        try useCase.execute(nickname: "Alice", publicKey: "pk1")

        // Assert
        #expect(mockRepository.createCalled == true)
        #expect(mockRepository.createdContact?.nickname == "Alice")
        #expect(mockRepository.createdContact?.publicKey == "pk1")
    }

    @Test func testTrimsNicknameAndPublicKey() throws {
        // Arrange
        let mockRepository = MockContactRepository()
        let useCase = CreateContactUseCaseImpl(contactRepository: mockRepository)

        // Act
        try useCase.execute(nickname: "  Alice  ", publicKey: "  pk1  ")

        // Assert
        #expect(mockRepository.createdContact?.nickname == "Alice")
        #expect(mockRepository.createdContact?.publicKey == "pk1")
    }

    @Test func testAssignsNewID() throws {
        // Arrange
        let mockRepository = MockContactRepository()
        let useCase = CreateContactUseCaseImpl(contactRepository: mockRepository)

        // Act
        try useCase.execute(nickname: "Alice", publicKey: "pk1")

        // Assert
        #expect(mockRepository.createdContact?.id != nil)
    }

    @Test func testThrowsWhenRepositoryThrows() throws {
        // Arrange
        let mockRepository = MockContactRepository()
        mockRepository.createError = NSError(domain: "Test", code: -1)
        let useCase = CreateContactUseCaseImpl(contactRepository: mockRepository)

        // Act & Assert
        #expect(throws: NSError.self) {
            try useCase.execute(nickname: "Alice", publicKey: "pk1")
        }
    }

    @Test func testThrowsDuplicatePublicKeyWhenSameKeyAlreadyExists() throws {
        // Arrange
        let mockRepository = MockContactRepository()
        mockRepository.fetchAllResult = [
            Contact(id: UUID(), nickname: "Alice", publicKey: "pk1", createdAt: .now)
        ]
        let useCase = CreateContactUseCaseImpl(contactRepository: mockRepository)

        // Act & Assert
        #expect(throws: CreateContactUseCaseError.self) {
            try useCase.execute(nickname: "Bob", publicKey: "pk1")
        }
        #expect(mockRepository.createCalled == false)
    }

    @Test func testThrowsDuplicatePublicKeyAfterTrimmingWhitespace() throws {
        // Arrange
        let mockRepository = MockContactRepository()
        mockRepository.fetchAllResult = [
            Contact(id: UUID(), nickname: "Alice", publicKey: "pk1", createdAt: .now)
        ]
        let useCase = CreateContactUseCaseImpl(contactRepository: mockRepository)

        // Act & Assert
        #expect(throws: CreateContactUseCaseError.self) {
            try useCase.execute(nickname: "Bob", publicKey: "  pk1  ")
        }
    }
}
