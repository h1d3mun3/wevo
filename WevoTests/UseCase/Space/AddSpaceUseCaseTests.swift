//
//  AddSpaceUseCaseTests.swift
//  WevoTests
//
//  Created by hidemune on 3/10/26.
//

import Testing
import Foundation
@testable import Wevo

@MainActor
struct AddSpaceUseCaseTests {

    @Test func testCreatesSpaceWithCorrectOrderIndex() async throws {
        // Arrange
        let mockRepository = MockSpaceRepository()
        let existingSpaces = [
            Space(id: UUID(), name: "Space 1", url: "url1", defaultIdentityID: nil, orderIndex: 0, createdAt: .now, updatedAt: .now),
            Space(id: UUID(), name: "Space 2", url: "url2", defaultIdentityID: nil, orderIndex: 1, createdAt: .now, updatedAt: .now)
        ]
        mockRepository.fetchAllResult = existingSpaces

        let useCase = AddSpaceUseCaseImpl(spaceRepository: mockRepository)

        // Act
        try await useCase.execute(name: "New Space", urls: ["https://example.com"], defaultIdentityID: nil)

        // Assert
        #expect(mockRepository.createCalled == true)
        let createdSpace = mockRepository.createdSpace
        #expect(createdSpace?.orderIndex == 2)
        #expect(createdSpace?.name == "New Space")
    }

    @Test func testFallsBackToOrderIndexZeroWhenFetchAllFails() async throws {
        // Arrange
        let mockRepository = MockSpaceRepository()
        mockRepository.fetchAllError = NSError(domain: "Test", code: -1)

        let useCase = AddSpaceUseCaseImpl(spaceRepository: mockRepository)

        // Act & Assert - should not throw
        try await useCase.execute(name: "New Space", urls: ["https://example.com"], defaultIdentityID: nil)
        #expect(mockRepository.createCalled == true)
        let createdSpace = mockRepository.createdSpace
        #expect(createdSpace?.orderIndex == 0)
    }

    @Test func testTrimsNameAndURL() async throws {
        // Arrange
        let mockRepository = MockSpaceRepository()
        mockRepository.fetchAllResult = []

        let useCase = AddSpaceUseCaseImpl(spaceRepository: mockRepository)

        // Act
        try await useCase.execute(name: "  My Space  ", urls: ["  https://example.com  "], defaultIdentityID: nil)

        // Assert
        #expect(mockRepository.createCalled == true)
        let createdSpace = mockRepository.createdSpace
        #expect(createdSpace?.name == "My Space")
        #expect(createdSpace?.url == "https://example.com")
    }

    @Test func testPassesDefaultIdentityID() async throws {
        // Arrange
        let mockRepository = MockSpaceRepository()
        mockRepository.fetchAllResult = []
        let defaultIdentityID = UUID()

        let useCase = AddSpaceUseCaseImpl(spaceRepository: mockRepository)

        // Act
        try await useCase.execute(name: "Space", urls: ["url"], defaultIdentityID: defaultIdentityID)

        // Assert
        #expect(mockRepository.createCalled == true)
        let createdSpace = mockRepository.createdSpace
        #expect(createdSpace?.defaultIdentityID == defaultIdentityID)
    }

    @Test func testThrowsWhenCreateFails() async throws {
        // Arrange
        let mockRepository = MockSpaceRepository()
        mockRepository.fetchAllResult = []
        mockRepository.createError = NSError(domain: "Test", code: -1)

        let useCase = AddSpaceUseCaseImpl(spaceRepository: mockRepository)

        // Act & Assert
        await #expect(throws: NSError.self) {
            try await useCase.execute(name: "Space", urls: ["url"], defaultIdentityID: nil)
        }
    }

    @Test func testStoresAllURLsWhenMultipleProvided() async throws {
        // Arrange
        let mockRepository = MockSpaceRepository()
        mockRepository.fetchAllResult = []

        let useCase = AddSpaceUseCaseImpl(spaceRepository: mockRepository)

        // Act
        try await useCase.execute(
            name: "Space",
            urls: ["https://node-a.example.com", "https://node-b.example.com", "https://node-c.example.com"],
            defaultIdentityID: nil
        )

        // Assert
        let createdSpace = mockRepository.createdSpace
        #expect(createdSpace?.urls.count == 3)
        #expect(createdSpace?.urls.first == "https://node-a.example.com")
        #expect(createdSpace?.url == "https://node-a.example.com")
    }

    @Test func testFiltersEmptyURLsFromList() async throws {
        // Arrange
        let mockRepository = MockSpaceRepository()
        mockRepository.fetchAllResult = []

        let useCase = AddSpaceUseCaseImpl(spaceRepository: mockRepository)

        // Act
        try await useCase.execute(
            name: "Space",
            urls: ["https://node-a.example.com", "", "  ", "https://node-b.example.com"],
            defaultIdentityID: nil
        )

        // Assert
        let createdSpace = mockRepository.createdSpace
        #expect(createdSpace?.urls.count == 2)
    }
}
