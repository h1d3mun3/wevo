//
//  GetAllSpacesUseCaseTests.swift
//  WevoTests
//
//  Created by hidemune on 3/10/26.
//

import Testing
import Foundation
@testable import Wevo

@MainActor
struct GetAllSpacesUseCaseTests {

    @Test func testReturnsSpacesFromRepository() throws {
        // Arrange
        let mockRepository = MockSpaceRepository()
        let testSpaces = [
            Space(id: UUID(), name: "Space 1", url: "url1", defaultIdentityID: nil, orderIndex: 0, createdAt: .now, updatedAt: .now),
            Space(id: UUID(), name: "Space 2", url: "url2", defaultIdentityID: nil, orderIndex: 1, createdAt: .now, updatedAt: .now)
        ]
        mockRepository.fetchAllResult = testSpaces

        let useCase = GetAllSpaceUseCaseImpl(spaceRepository: mockRepository)

        // Act
        let result = try useCase.execute()

        // Assert
        #expect(result.count == 2)
        #expect(result[0].name == "Space 1")
        #expect(result[1].name == "Space 2")
    }

    @Test func testReturnsEmptyArray() throws {
        // Arrange
        let mockRepository = MockSpaceRepository()
        mockRepository.fetchAllResult = []

        let useCase = GetAllSpaceUseCaseImpl(spaceRepository: mockRepository)

        // Act
        let result = try useCase.execute()

        // Assert
        #expect(result.count == 0)
    }

    @Test func testThrowsWhenRepositoryThrows() throws {
        // Arrange
        let mockRepository = MockSpaceRepository()
        mockRepository.fetchAllError = NSError(domain: "Test", code: -1)

        let useCase = GetAllSpaceUseCaseImpl(spaceRepository: mockRepository)

        // Act & Assert
        #expect(throws: NSError.self) {
            try useCase.execute()
        }
    }
}
