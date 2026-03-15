//
//  GetProposeUseCaseTests.swift
//  WevoTests
//

import Testing
import Foundation
@testable import Wevo

@MainActor
struct GetProposeUseCaseTests {

    @Test func testReturnsProposeFromRepository() throws {
        // Arrange
        let mockRepository = MockProposeRepository()
        let testID = UUID()
        let testPropose = Propose(
            id: testID,
            spaceID: UUID(),
            message: "Test message",
            creatorPublicKey: "creatorKey",
            creatorSignature: "creatorSig",
            counterpartyPublicKey: "counterpartyKey",
            counterpartySignSignature: nil,
            createdAt: .now,
            updatedAt: .now
        )
        mockRepository.fetchByIDResult = testPropose

        let useCase = GetProposeUseCaseImpl(proposeRepository: mockRepository)

        // Act
        let result = try useCase.execute(id: testID)

        // Assert
        #expect(result.id == testID)
        #expect(result.message == "Test message")
        #expect(mockRepository.fetchByIDCalledWithID == testID)
    }

    @Test func testThrowsWhenRepositoryThrows() throws {
        // Arrange
        let mockRepository = MockProposeRepository()
        mockRepository.fetchByIDError = NSError(domain: "Test", code: -1)

        let useCase = GetProposeUseCaseImpl(proposeRepository: mockRepository)

        // Act & Assert
        #expect(throws: NSError.self) {
            try useCase.execute(id: UUID())
        }
    }

    @Test func testThrowsWhenProposeNotFound() throws {
        // Arrange
        let mockRepository = MockProposeRepository()
        mockRepository.fetchByIDError = ProposeRepositoryError.proposeNotFound(UUID())

        let useCase = GetProposeUseCaseImpl(proposeRepository: mockRepository)

        // Act & Assert
        #expect(throws: ProposeRepositoryError.self) {
            try useCase.execute(id: UUID())
        }
    }
}
