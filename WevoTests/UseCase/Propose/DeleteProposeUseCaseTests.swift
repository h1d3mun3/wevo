//
//  DeleteProposeUseCaseTests.swift
//  WevoTests
//
//  Created by hidemune on 3/10/26.
//

import Testing
import Foundation
@testable import Wevo

@MainActor
struct DeleteProposeUseCaseTests {

    @Test func testCallsDeleteWithCorrectID() async throws {
        // Arrange
        let mockRepository = MockProposeRepository()
        let useCase = DeleteProposeUseCaseImpl(proposeRepository: mockRepository)
        let testID = UUID()

        // Act
        try useCase.execute(id: testID)

        // Assert
        #expect(mockRepository.deleteCalled == true)
        #expect(mockRepository.deletedID == testID)
    }

    @Test func testThrowsWhenRepositoryThrows() async throws {
        // Arrange
        let mockRepository = MockProposeRepository()
        mockRepository.deleteError = NSError(domain: "Test", code: -1)
        let useCase = DeleteProposeUseCaseImpl(proposeRepository: mockRepository)

        // Act & Assert
        #expect(throws: NSError.self) {
            try useCase.execute(id: UUID())
        }
    }
}
