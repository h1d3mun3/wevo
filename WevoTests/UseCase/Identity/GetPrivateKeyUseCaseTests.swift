//
//  GetPrivateKeyUseCaseTests.swift
//  WevoTests
//
//  Created by hidemune on 3/10/26.
//

import Testing
import Foundation
@testable import Wevo

struct GetPrivateKeyUseCaseTests {

    @Test func testReturnsPrivateKeyDataFromRepository() throws {
        // Arrange
        let mockRepository = MockKeychainRepository()
        let testData = Data([0x01, 0x02, 0x03, 0x04])
        mockRepository.getPrivateKeyResult = testData
        let useCase = GetPrivateKeyUseCaseImpl(keychainRepository: mockRepository)

        // Act
        let result = try useCase.execute(id: UUID())

        // Assert
        #expect(result == testData)
    }

    @Test func testThrowsWhenRepositoryThrows() throws {
        // Arrange
        let mockRepository = MockKeychainRepository()
        mockRepository.getPrivateKeyError = KeychainError.biometricAuthFailed
        let useCase = GetPrivateKeyUseCaseImpl(keychainRepository: mockRepository)

        // Act & Assert
        #expect(throws: KeychainError.biometricAuthFailed) {
            try useCase.execute(id: UUID())
        }
    }
}
