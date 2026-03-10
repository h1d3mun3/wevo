//
//  ImportIdentityUseCaseTests.swift
//  WevoTests
//
//  Created by hidemune on 3/10/26.
//

import Testing
import Foundation
@testable import Wevo

// MARK: - Tests

struct ImportIdentityUseCaseTests {

    @Test func testImportIdentitySuccessfully() async throws {
        // Arrange
        let mockRepository = MockKeychainRepository()
        let useCase = ImportIdentityUseCaseImpl(keychainRepository: mockRepository)

        let testID = UUID()
        let testNickname = "Test Identity"
        let testPrivateKey = Data([0x01, 0x02, 0x03])

        // Act
        try useCase.execute(id: testID, nickname: testNickname, privateKey: testPrivateKey)

        // Assert
        #expect(mockRepository.createIdentityCalled == true)
        #expect(mockRepository.createIdentityCallCount == 1)
        #expect(mockRepository.createdIdentityID == testID)
        #expect(mockRepository.createdNickname == testNickname)
        #expect(mockRepository.createdPrivateKey == testPrivateKey)
    }

    @Test func testImportIdentityWithKeychainError() async throws {
        // Arrange
        let mockRepository = MockKeychainRepository()
        mockRepository.createIdentityError = KeychainError.duplicateItem
        let useCase = ImportIdentityUseCaseImpl(keychainRepository: mockRepository)

        let testID = UUID()
        let testNickname = "Test Identity"
        let testPrivateKey = Data([0x01, 0x02, 0x03])

        // Act & Assert
        await #expect(throws: KeychainError.duplicateItem) {
            try useCase.execute(id: testID, nickname: testNickname, privateKey: testPrivateKey)
        }
    }

    @Test func testImportIdentityPreservesAllParameters() async throws {
        // Arrange
        let mockRepository = MockKeychainRepository()
        let useCase = ImportIdentityUseCaseImpl(keychainRepository: mockRepository)

        let testID = UUID(uuidString: "123E4567-E89B-12D3-A456-426614174000")!
        let testNickname = "My Important Key"
        let testPrivateKeyBytes: [UInt8] = Array(0...31)
        let testPrivateKey = Data(testPrivateKeyBytes)

        // Act
        try useCase.execute(id: testID, nickname: testNickname, privateKey: testPrivateKey)

        // Assert
        #expect(mockRepository.createdIdentityID == testID)
        #expect(mockRepository.createdNickname == "My Important Key")
        #expect(mockRepository.createdPrivateKey == testPrivateKey)
    }
}
