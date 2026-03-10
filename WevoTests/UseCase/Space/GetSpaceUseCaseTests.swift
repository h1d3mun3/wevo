//
//  GetSpaceUseCaseTests.swift
//  WevoTests
//
//  Created by hidemune on 3/10/26.
//

import Testing
import Foundation
@testable import Wevo

@MainActor
struct GetSpaceUseCaseTests {

    @Test func testReturnsSpaceFromRepository() async throws {
        // Arrange
        let mockRepository = MockSpaceRepository()
        let testID = UUID()
        let testSpace = Space(
            id: testID,
            name: "Test Space",
            url: "https://example.com",
            defaultIdentityID: nil,
            orderIndex: 0,
            createdAt: .now,
            updatedAt: .now
        )
        mockRepository.fetchByIDResult = testSpace

        let useCase = GetSpaceUseCaseImpl(spaceRepository: mockRepository)

        // Act
        let result = try await useCase.execute(id: testID)

        // Assert
        #expect(result.id == testID)
        #expect(result.name == "Test Space")
        #expect(mockRepository.fetchByIDCalledWithID == testID)
    }

    @Test func testThrowsWhenRepositoryThrows() async throws {
        // Arrange
        let mockRepository = MockSpaceRepository()
        mockRepository.fetchByIDError = NSError(domain: "Test", code: -1)

        let useCase = GetSpaceUseCaseImpl(spaceRepository: mockRepository)

        // Act & Assert
        await #expect(throws: NSError.self) {
            try await useCase.execute(id: UUID())
        }
    }
}
