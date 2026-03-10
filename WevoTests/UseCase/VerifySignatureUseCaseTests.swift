//
//  VerifySignatureUseCaseTests.swift
//  WevoTests
//
//  Created by hidemune on 3/10/26.
//

import Testing
import Foundation
@testable import Wevo

struct VerifySignatureUseCaseTests {

    @Test func testReturnsTrueWhenVerificationSucceeds() throws {
        // Arrange
        let mockRepository = MockKeychainRepository()
        mockRepository.verifySignatureResult = true
        let useCase = VerifySignatureUseCaseImpl(keychainRepository: mockRepository)

        // Act
        let result = try useCase.execute(
            signature: "sig123",
            message: "test message",
            publicKey: "pubkey123"
        )

        // Assert
        #expect(result == true)
    }

    @Test func testReturnsFalseWhenVerificationFails() throws {
        // Arrange
        let mockRepository = MockKeychainRepository()
        mockRepository.verifySignatureResult = false
        let useCase = VerifySignatureUseCaseImpl(keychainRepository: mockRepository)

        // Act
        let result = try useCase.execute(
            signature: "sig123",
            message: "test message",
            publicKey: "pubkey123"
        )

        // Assert
        #expect(result == false)
    }

    @Test func testThrowsVerificationFailedWhenRepositoryThrows() throws {
        // Arrange
        let mockRepository = MockKeychainRepository()
        mockRepository.verifySignatureError = KeychainError.invalidData
        let useCase = VerifySignatureUseCaseImpl(keychainRepository: mockRepository)

        // Act & Assert
        #expect(throws: VerifySignatureUseCaseError.verificationFailed) {
            try useCase.execute(
                signature: "invalid",
                message: "test",
                publicKey: "invalid"
            )
        }
    }
}
