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

    @Test func testReturnsProposeListFromRepository() async throws {
        // Arrange
        let mockRepository = MockProposeRepository()
        let spaceID = UUID()
        let testProposes = [
            Propose(id: UUID(), spaceID: spaceID, message: "Propose 1", signatures: [], createdAt: .now, updatedAt: .now),
            Propose(id: UUID(), spaceID: spaceID, message: "Propose 2", signatures: [], createdAt: .now, updatedAt: .now)
        ]
        mockRepository.fetchAllResult = testProposes

        let useCase = LoadAllProposesUseCaseIpml(proposeRepository: mockRepository)

        // Act
        let result = try await useCase.execute(id: spaceID)

        // Assert
        #expect(result.count == 2)
        #expect(result[0].message == "Propose 1")
        #expect(result[1].message == "Propose 2")
        #expect(mockRepository.fetchAllForSpaceID == spaceID)
    }

    @Test func testReturnsEmptyArrayWhenNoProposes() async throws {
        // Arrange
        let mockRepository = MockProposeRepository()
        mockRepository.fetchAllResult = []

        let useCase = LoadAllProposesUseCaseIpml(proposeRepository: mockRepository)

        // Act
        let result = try await useCase.execute(id: UUID())

        // Assert
        #expect(result.count == 0)
    }

    @Test func testPassesCorrectSpaceID() async throws {
        // Arrange
        let mockRepository = MockProposeRepository()
        let spaceID = UUID()
        mockRepository.fetchAllResult = []

        let useCase = LoadAllProposesUseCaseIpml(proposeRepository: mockRepository)

        // Act
        _ = try await useCase.execute(id: spaceID)

        // Assert
        #expect(mockRepository.fetchAllForSpaceID == spaceID)
    }

    @Test func testThrowsWhenRepositoryThrows() async throws {
        // Arrange
        let mockRepository = MockProposeRepository()
        mockRepository.fetchAllError = NSError(domain: "Test", code: -1)

        let useCase = LoadAllProposesUseCaseIpml(proposeRepository: mockRepository)

        // Act & Assert
        await #expect(throws: NSError.self) {
            try await useCase.execute(id: UUID())
        }
    }
}
