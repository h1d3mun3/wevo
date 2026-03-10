//
//  EditIdentityUseCaseTests.swift
//  WevoTests
//
//  Created by hidemune on 3/10/26.
//

import Testing
import Foundation
@testable import Wevo

struct EditIdentityUseCaseTests {

    @Test func testCallsUpdateNicknameWithCorrectID() throws {
        // Arrange
        let mockRepository = MockKeychainRepository()
        let useCase = EditIdentityUseCaseImpl(keychainRepository: mockRepository)
        let testID = UUID()

        // Act
        try useCase.execute(id: testID, newNickname: "Bob")

        // Assert
        #expect(mockRepository.updateNicknameCalled == true)
        #expect(mockRepository.updatedNicknameID == testID)
        #expect(mockRepository.updatedNicknameValue == "Bob")
    }

    @Test func testTrimsWhitespaceFromNickname() throws {
        // Arrange
        let mockRepository = MockKeychainRepository()
        let useCase = EditIdentityUseCaseImpl(keychainRepository: mockRepository)

        // Act
        try useCase.execute(id: UUID(), newNickname: "  Bob  ")

        // Assert
        #expect(mockRepository.updatedNicknameValue == "Bob")
    }

    @Test func testNicknameAllWhitespaceBecomesEmpty() throws {
        // Arrange
        let mockRepository = MockKeychainRepository()
        let useCase = EditIdentityUseCaseImpl(keychainRepository: mockRepository)

        // Act
        try useCase.execute(id: UUID(), newNickname: "   \t\n   ")

        // Assert
        #expect(mockRepository.updatedNicknameValue == "")
    }

    @Test func testThrowsWhenRepositoryThrows() throws {
        // Arrange
        let mockRepository = MockKeychainRepository()
        mockRepository.updateNicknameError = KeychainError.itemNotFound
        let useCase = EditIdentityUseCaseImpl(keychainRepository: mockRepository)

        // Act & Assert
        #expect(throws: KeychainError.itemNotFound) {
            try useCase.execute(id: UUID(), newNickname: "NewName")
        }
    }
}
