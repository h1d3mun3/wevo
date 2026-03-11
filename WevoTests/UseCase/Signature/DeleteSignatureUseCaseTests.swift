//
//  DeleteSignatureUseCaseTests.swift
//  WevoTests
//
//  Created on 3/11/26.
//

import Testing
import Foundation
@testable import Wevo

@MainActor
struct DeleteSignatureUseCaseTests {

    @Test func testDeletesSignatureByID() async throws {
        // Arrange
        let mockSignature = MockSignatureRepository()
        let signatureID = UUID()

        let useCase = DeleteSignatureUseCaseImpl(signatureRepository: mockSignature)

        // Act
        try useCase.execute(id: signatureID)

        // Assert
        #expect(mockSignature.deleteCalled == true)
        #expect(mockSignature.deletedID == signatureID)
    }

    @Test func testThrowsWhenSignatureNotFound() async throws {
        // Arrange
        let mockSignature = MockSignatureRepository()
        let signatureID = UUID()
        mockSignature.deleteError = SignatureRepositoryError.signatureNotFound(signatureID)

        let useCase = DeleteSignatureUseCaseImpl(signatureRepository: mockSignature)

        // Act & Assert
        #expect(throws: SignatureRepositoryError.self) {
            try useCase.execute(id: signatureID)
        }
    }

    @Test func testThrowsWhenDeleteFails() async throws {
        // Arrange
        let mockSignature = MockSignatureRepository()
        mockSignature.deleteError = SignatureRepositoryError.deleteError(
            NSError(domain: "Test", code: -1)
        )

        let useCase = DeleteSignatureUseCaseImpl(signatureRepository: mockSignature)

        // Act & Assert
        #expect(throws: SignatureRepositoryError.self) {
            try useCase.execute(id: UUID())
        }
    }
}
