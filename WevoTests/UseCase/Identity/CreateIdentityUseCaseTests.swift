//
//  CreateIdentityUseCaseTests.swift
//  WevoTests
//
//  Created by hidemune on 3/10/26.
//

import Testing
import Foundation
@testable import Wevo

struct CreateIdentityUseCaseTests {

    @Test func testCallsCreateIdentityOnRepository() throws {
        // Arrange
        let mockRepository = MockKeychainRepository()
        let useCase = CreateIdentityUseCaseImpl(keychainRepository: mockRepository)

        // Act
        try useCase.execute(nickname: "Test Identity")

        // Assert
        #expect(mockRepository.createIdentityCalled == true)
        #expect(mockRepository.createIdentityCallCount == 1)
        #expect(mockRepository.createdNickname == "Test Identity")
        #expect(mockRepository.createdPrivateKey != nil)
        #expect(mockRepository.createdPrivateKey?.count ?? 0 > 0)
    }

    @Test func testTrimsWhitespaceFromNickname() throws {
        // Arrange
        let mockRepository = MockKeychainRepository()
        let useCase = CreateIdentityUseCaseImpl(keychainRepository: mockRepository)

        // Act
        try useCase.execute(nickname: "  Alice  ")

        // Assert
        #expect(mockRepository.createdNickname == "Alice")
    }

    @Test func testNicknameAllWhitespaceBecomesEmpty() throws {
        // Arrange
        let mockRepository = MockKeychainRepository()
        let useCase = CreateIdentityUseCaseImpl(keychainRepository: mockRepository)

        // Act
        try useCase.execute(nickname: "   \t\n   ")

        // Assert
        #expect(mockRepository.createdNickname == "")
    }

    @Test func testThrowsWhenRepositoryThrows() throws {
        // Arrange
        let mockRepository = MockKeychainRepository()
        mockRepository.createIdentityError = KeychainError.invalidData
        let useCase = CreateIdentityUseCaseImpl(keychainRepository: mockRepository)

        // Act & Assert
        #expect(throws: KeychainError.invalidData) {
            try useCase.execute(nickname: "Test")
        }
    }
}
