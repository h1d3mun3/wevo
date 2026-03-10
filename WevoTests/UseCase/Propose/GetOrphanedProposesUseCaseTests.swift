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

    @Test func testReturnsOrphanedProposeList() throws {
        // Arrange
        let mockRepository = MockProposeRepository()
        let orphanedSpaceID = UUID()
        let testProposes = [
            Propose(id: UUID(), spaceID: orphanedSpaceID, message: "Orphaned 1", signatures: [], createdAt: .now, updatedAt: .now),
            Propose(id: UUID(), spaceID: orphanedSpaceID, message: "Orphaned 2", signatures: [], createdAt: .now, updatedAt: .now)
        ]
        mockRepository.fetchAllOrphanedResult = testProposes

        let useCase = GetOrphanedProposesUseCaseImpl(proposeRepository: mockRepository)
        let validSpaceIDs = Set([UUID(), UUID()])

        // Act
        let result = try useCase.execute(validSpaceIDs: validSpaceIDs)

        // Assert
        #expect(result.count == 2)
        #expect(result[0].message == "Orphaned 1")
        #expect(result[1].message == "Orphaned 2")
        #expect(mockRepository.fetchAllOrphanedValidSpaceIDs == validSpaceIDs)
    }

    @Test func testReturnsEmptyArrayWhenNoOrphanedProposes() throws {
        // Arrange
        let mockRepository = MockProposeRepository()
        mockRepository.fetchAllOrphanedResult = []

        let useCase = GetOrphanedProposesUseCaseImpl(proposeRepository: mockRepository)
        let validSpaceIDs = Set([UUID()])

        // Act
        let result = try useCase.execute(validSpaceIDs: validSpaceIDs)

        // Assert
        #expect(result.count == 0)
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
        let validSpaceIDs = Set([UUID()])

        // Act & Assert
        #expect(throws: NSError.self) {
            try useCase.execute(validSpaceIDs: validSpaceIDs)
        }
    }
}
