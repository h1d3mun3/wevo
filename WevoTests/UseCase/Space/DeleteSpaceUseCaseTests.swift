//
//  DeleteSpaceUseCaseTests.swift
//  WevoTests
//
//  Created by hidemune on 3/10/26.
//

import Testing
import Foundation
@testable import Wevo

@MainActor
struct DeleteSpaceUseCaseTests {

    @Test func testCallsDeleteWithCorrectID() async throws {
        // Arrange
        let mockRepository = MockSpaceRepository()
        let useCase = DeleteSpaceUseCaseImpl(spaceRepository: mockRepository)
        let testID = UUID()

        // Act
        try await useCase.execute(id: testID)

        // Assert
        #expect(mockRepository.deleteCalled == true)
        #expect(mockRepository.deletedID == testID)
    }

    @Test func testThrowsWhenRepositoryThrows() async throws {
        // Arrange
        let mockRepository = MockSpaceRepository()
        mockRepository.deleteError = NSError(domain: "Test", code: -1)
        let useCase = DeleteSpaceUseCaseImpl(spaceRepository: mockRepository)

        // Act & Assert
        await #expect(throws: NSError.self) {
            try await useCase.execute(id: UUID())
        }
    }
}
