//
//  LoadAllProposesUseCaseTests.swift
//  WevoTests
//
//  Created by hidemune on 3/10/26.
//

import Testing
import Foundation
@testable import Wevo

@MainActor
struct LoadAllProposesUseCaseTests {

    /// Helper to generate a test Propose
    private func makePropose(spaceID: UUID, message: String) -> Propose {
        Propose(
            id: UUID(),
            spaceID: spaceID,
            message: message,
            creatorPublicKey: "creatorKey",
            creatorSignature: "creatorSig",
            counterpartyPublicKey: "counterpartyKey",
            counterpartySignSignature: nil,
            createdAt: .now,
            updatedAt: .now
        )
    }

    @Test func testReturnsProposeListFromRepository() throws {
        // Arrange
        let mockRepository = MockProposeRepository()
        let spaceID = UUID()
        let testProposes = [
            makePropose(spaceID: spaceID, message: "Propose 1"),
            makePropose(spaceID: spaceID, message: "Propose 2")
        ]
        mockRepository.fetchAllResult = testProposes

        let useCase = LoadAllProposesUseCaseImpl(proposeRepository: mockRepository)

        // Act
        let result = try useCase.execute(id: spaceID)

        // Assert
        #expect(result.count == 2)
        #expect(result[0].message == "Propose 1")
        #expect(result[1].message == "Propose 2")
        #expect(mockRepository.fetchAllForSpaceID == spaceID)
    }

    @Test func testReturnsEmptyArrayWhenNoProposes() throws {
        // Arrange
        let mockRepository = MockProposeRepository()
        mockRepository.fetchAllResult = []

        let useCase = LoadAllProposesUseCaseImpl(proposeRepository: mockRepository)

        // Act
        let result = try useCase.execute(id: UUID())

        // Assert
        #expect(result.count == 0)
    }

    @Test func testPassesCorrectSpaceID() throws {
        // Arrange
        let mockRepository = MockProposeRepository()
        let spaceID = UUID()
        mockRepository.fetchAllResult = []

        let useCase = LoadAllProposesUseCaseImpl(proposeRepository: mockRepository)

        // Act
        _ = try useCase.execute(id: spaceID)

        // Assert
        #expect(mockRepository.fetchAllForSpaceID == spaceID)
    }

    @Test func testThrowsWhenRepositoryThrows() throws {
        // Arrange
        let mockRepository = MockProposeRepository()
        mockRepository.fetchAllError = NSError(domain: "Test", code: -1)

        let useCase = LoadAllProposesUseCaseImpl(proposeRepository: mockRepository)

        // Act & Assert
        #expect(throws: NSError.self) {
            try useCase.execute(id: UUID())
        }
    }
}
