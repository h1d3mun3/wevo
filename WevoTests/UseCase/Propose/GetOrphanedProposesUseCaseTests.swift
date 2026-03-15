//
//  GetOrphanedProposesUseCaseTests.swift
//  WevoTests
//
//  Created by hidemune on 3/10/26.
//

import Testing
import Foundation
@testable import Wevo

@MainActor
struct GetOrphanedProposesUseCaseTests {

    /// Helper to generate a test Propose
    private func makePropose(spaceID: UUID, message: String, createdAt: Date = .now) -> Propose {
        Propose(
            id: UUID(),
            spaceID: spaceID,
            message: message,
            creatorPublicKey: "creatorKey",
            creatorSignature: "creatorSig",
            counterpartyPublicKey: "counterpartyKey",
            counterpartySignSignature: nil,
            createdAt: createdAt,
            updatedAt: createdAt
        )
    }

    @Test func testReturnsGroupedOrphanedProposes() throws {
        // Arrange
        let mockRepository = MockProposeRepository()
        let spaceID1 = UUID()
        let spaceID2 = UUID()
        let testProposes = [
            makePropose(spaceID: spaceID1, message: "Orphaned 1"),
            makePropose(spaceID: spaceID1, message: "Orphaned 2"),
            makePropose(spaceID: spaceID2, message: "Orphaned 3")
        ]
        mockRepository.fetchAllOrphanedResult = testProposes

        let useCase = GetOrphanedProposesUseCaseImpl(proposeRepository: mockRepository)
        let validSpaceIDs = Set([UUID()])

        // Act
        let result = try useCase.execute(validSpaceIDs: validSpaceIDs)

        // Assert
        #expect(result.count == 2)

        let group1 = result.first { $0.spaceID == spaceID1 }
        let group2 = result.first { $0.spaceID == spaceID2 }
        #expect(group1?.proposes.count == 2)
        #expect(group2?.proposes.count == 1)
    }

    @Test func testSortsGroupsByLatestCreatedAt() throws {
        // Arrange
        let mockRepository = MockProposeRepository()
        let olderSpaceID = UUID()
        let newerSpaceID = UUID()
        let olderDate = Date(timeIntervalSince1970: 1000)
        let newerDate = Date(timeIntervalSince1970: 2000)

        let testProposes = [
            makePropose(spaceID: olderSpaceID, message: "Old", createdAt: olderDate),
            makePropose(spaceID: newerSpaceID, message: "New", createdAt: newerDate)
        ]
        mockRepository.fetchAllOrphanedResult = testProposes

        let useCase = GetOrphanedProposesUseCaseImpl(proposeRepository: mockRepository)

        // Act
        let result = try useCase.execute(validSpaceIDs: Set([UUID()]))

        // Assert: the newer one comes first
        #expect(result[0].spaceID == newerSpaceID)
        #expect(result[1].spaceID == olderSpaceID)
    }

    @Test func testReturnsEmptyArrayWhenNoOrphanedProposes() throws {
        // Arrange
        let mockRepository = MockProposeRepository()
        mockRepository.fetchAllOrphanedResult = []

        let useCase = GetOrphanedProposesUseCaseImpl(proposeRepository: mockRepository)

        // Act
        let result = try useCase.execute(validSpaceIDs: Set([UUID()]))

        // Assert
        #expect(result.isEmpty)
    }

    @Test func testPassesCorrectValidSpaceIDs() throws {
        // Arrange
        let mockRepository = MockProposeRepository()
        mockRepository.fetchAllOrphanedResult = []

        let useCase = GetOrphanedProposesUseCaseImpl(proposeRepository: mockRepository)
        let validSpaceIDs = Set([UUID(), UUID(), UUID()])

        // Act
        _ = try useCase.execute(validSpaceIDs: validSpaceIDs)

        // Assert
        #expect(mockRepository.fetchAllOrphanedValidSpaceIDs == validSpaceIDs)
    }

    @Test func testThrowsWhenRepositoryThrows() throws {
        // Arrange
        let mockRepository = MockProposeRepository()
        mockRepository.fetchAllOrphanedError = NSError(domain: "Test", code: -1)

        let useCase = GetOrphanedProposesUseCaseImpl(proposeRepository: mockRepository)

        // Act & Assert
        #expect(throws: NSError.self) {
            try useCase.execute(validSpaceIDs: Set([UUID()]))
        }
    }
}
