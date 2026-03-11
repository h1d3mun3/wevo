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

    @Test func testReturnsGroupedOrphanedProposes() throws {
        // Arrange
        let mockRepository = MockProposeRepository()
        let spaceID1 = UUID()
        let spaceID2 = UUID()
        let testProposes = [
            Propose(id: UUID(), spaceID: spaceID1, message: "Orphaned 1", signatures: [], createdAt: .now, updatedAt: .now),
            Propose(id: UUID(), spaceID: spaceID1, message: "Orphaned 2", signatures: [], createdAt: .now, updatedAt: .now),
            Propose(id: UUID(), spaceID: spaceID2, message: "Orphaned 3", signatures: [], createdAt: .now, updatedAt: .now)
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
            Propose(id: UUID(), spaceID: olderSpaceID, message: "Old", signatures: [], createdAt: olderDate, updatedAt: olderDate),
            Propose(id: UUID(), spaceID: newerSpaceID, message: "New", signatures: [], createdAt: newerDate, updatedAt: newerDate)
        ]
        mockRepository.fetchAllOrphanedResult = testProposes

        let useCase = GetOrphanedProposesUseCaseImpl(proposeRepository: mockRepository)

        // Act
        let result = try useCase.execute(validSpaceIDs: Set([UUID()]))

        // Assert - 新しい方が先
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
