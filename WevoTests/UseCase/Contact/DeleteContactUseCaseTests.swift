//
//  DeleteContactUseCaseTests.swift
//  WevoTests
//
//  Created by hidemune on 3/12/26.
//

import Testing
import Foundation
@testable import Wevo

@MainActor
struct DeleteContactUseCaseTests {

    @Test func testCallsDeleteWithCorrectID() throws {
        // Arrange
        let mockRepository = MockContactRepository()
        let useCase = DeleteContactUseCaseImpl(contactRepository: mockRepository)
        let testID = UUID()

        // Act
        try useCase.execute(id: testID)

        // Assert
        #expect(mockRepository.deleteCalled == true)
        #expect(mockRepository.deletedID == testID)
    }

    @Test func testThrowsWhenRepositoryThrows() throws {
        // Arrange
        let mockRepository = MockContactRepository()
        mockRepository.deleteError = NSError(domain: "Test", code: -1)
        let useCase = DeleteContactUseCaseImpl(contactRepository: mockRepository)

        // Act & Assert
        #expect(throws: NSError.self) {
            try useCase.execute(id: UUID())
        }
    }
}
