//
//  EditSpaceUseCaseTests.swift
//  WevoTests
//
//  Created by hidemune on 3/10/26.
//

import Testing
import Foundation
@testable import Wevo

// MARK: - Mock GetSpaceUseCase

class MockGetSpaceUseCase: GetSpaceUseCase {
    var result: Space?
    var error: Error?

    func execute(id: UUID) throws -> Space {
        if let error = error {
            throw error
        }
        guard let result = result else {
            throw NSError(domain: "MockGetSpaceUseCase", code: -1)
        }
        return result
    }
}

// MARK: - Tests

@MainActor
struct EditSpaceUseCaseTests {

    @Test func testUpdatesSpaceWithTrimmedValues() async throws {
        // Arrange
        let mockSpaceRepository = MockSpaceRepository()
        let mockGetSpaceUseCase = MockGetSpaceUseCase()

        let spaceID = UUID()
        let originalSpace = Space(
            id: spaceID,
            name: "Original",
            url: "original-url",
            defaultIdentityID: UUID(),
            orderIndex: 5,
            createdAt: .now,
            updatedAt: .now
        )
        mockGetSpaceUseCase.result = originalSpace

        let useCase = EditSpaceUseCaseImpl(
            spaceRepository: mockSpaceRepository,
            getSpaceUseCase: mockGetSpaceUseCase
        )

        // Act
        try await useCase.execute(id: spaceID, name: "  Updated  ", urlString: "  new-url  ", defaultIdentityID: nil)

        // Assert
        #expect(mockSpaceRepository.updateCalled == true)
        let updatedSpace = mockSpaceRepository.updatedSpace
        #expect(updatedSpace?.name == "Updated")
        #expect(updatedSpace?.url == "new-url")
    }

    @Test func testPreservesOriginalMetadata() async throws {
        // Arrange
        let mockSpaceRepository = MockSpaceRepository()
        let mockGetSpaceUseCase = MockGetSpaceUseCase()

        let spaceID = UUID()
        let defaultIdentityID = UUID()
        let createdAt = Date(timeIntervalSince1970: 1000)
        let originalSpace = Space(
            id: spaceID,
            name: "Original",
            url: "original-url",
            defaultIdentityID: defaultIdentityID,
            orderIndex: 5,
            createdAt: createdAt,
            updatedAt: .now
        )
        mockGetSpaceUseCase.result = originalSpace

        let useCase = EditSpaceUseCaseImpl(
            spaceRepository: mockSpaceRepository,
            getSpaceUseCase: mockGetSpaceUseCase
        )

        // Act
        try await useCase.execute(id: spaceID, name: "Updated", urlString: "new-url", defaultIdentityID: defaultIdentityID)

        // Assert
        let updatedSpace = mockSpaceRepository.updatedSpace
        #expect(updatedSpace?.id == spaceID)
        #expect(updatedSpace?.defaultIdentityID == defaultIdentityID)
        #expect(updatedSpace?.orderIndex == 5)
        #expect(updatedSpace?.createdAt == createdAt)
    }

    @Test func testThrowsWhenGetSpaceFails() async throws {
        // Arrange
        let mockSpaceRepository = MockSpaceRepository()
        let mockGetSpaceUseCase = MockGetSpaceUseCase()
        mockGetSpaceUseCase.error = NSError(domain: "Test", code: -1)

        let useCase = EditSpaceUseCaseImpl(
            spaceRepository: mockSpaceRepository,
            getSpaceUseCase: mockGetSpaceUseCase
        )

        // Act & Assert
        await #expect(throws: NSError.self) {
            try await useCase.execute(id: UUID(), name: "New", urlString: "new-url", defaultIdentityID: nil)
        }
    }

    @Test func testThrowsWhenUpdateFails() async throws {
        // Arrange
        let mockSpaceRepository = MockSpaceRepository()
        let mockGetSpaceUseCase = MockGetSpaceUseCase()

        let spaceID = UUID()
        let originalSpace = Space(
            id: spaceID,
            name: "Original",
            url: "original-url",
            defaultIdentityID: nil,
            orderIndex: 0,
            createdAt: .now,
            updatedAt: .now
        )
        mockGetSpaceUseCase.result = originalSpace
        mockSpaceRepository.updateError = NSError(domain: "Test", code: -1)

        let useCase = EditSpaceUseCaseImpl(
            spaceRepository: mockSpaceRepository,
            getSpaceUseCase: mockGetSpaceUseCase
        )

        // Act & Assert
        await #expect(throws: NSError.self) {
            try await useCase.execute(id: spaceID, name: "Updated", urlString: "new-url", defaultIdentityID: nil)
        }
    }
}
