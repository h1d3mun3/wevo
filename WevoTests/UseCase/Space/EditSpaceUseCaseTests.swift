//
//  EditSpaceUseCaseTests.swift
//  WevoTests
//
//  Created by hidemune on 3/10/26.
//

import Testing
import Foundation
@testable import Wevo

// MARK: - Mocks

class MockGetSpaceUseCase: GetSpaceUseCase {
    var result: Space?
    var error: Error?

    func execute(id: UUID) throws -> Space {
        if let error = error { throw error }
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
        let mockSpaceRepository = MockSpaceRepository()
        let mockGetSpaceUseCase = MockGetSpaceUseCase()
        let spaceID = UUID()
        mockGetSpaceUseCase.result = Space(
            id: spaceID, name: "Original", url: "original-url",
            defaultIdentityID: UUID(), orderIndex: 5, createdAt: .now, updatedAt: .now
        )

        let useCase = EditSpaceUseCaseImpl(
            spaceRepository: mockSpaceRepository,
            getSpaceUseCase: mockGetSpaceUseCase,
            fetchServerInfoUseCase: MockFetchServerInfoUseCase()
        )

        try await useCase.execute(id: spaceID, name: "  Updated  ", primaryURL: "  new-url  ", defaultIdentityID: nil)

        #expect(mockSpaceRepository.updateCalled == true)
        #expect(mockSpaceRepository.updatedSpace?.name == "Updated")
        #expect(mockSpaceRepository.updatedSpace?.url == "new-url")
    }

    @Test func testPreservesOriginalMetadata() async throws {
        let mockSpaceRepository = MockSpaceRepository()
        let mockGetSpaceUseCase = MockGetSpaceUseCase()
        let spaceID = UUID()
        let defaultIdentityID = UUID()
        let createdAt = Date(timeIntervalSince1970: 1000)
        mockGetSpaceUseCase.result = Space(
            id: spaceID, name: "Original", url: "original-url",
            defaultIdentityID: defaultIdentityID, orderIndex: 5, createdAt: createdAt, updatedAt: .now
        )

        let useCase = EditSpaceUseCaseImpl(
            spaceRepository: mockSpaceRepository,
            getSpaceUseCase: mockGetSpaceUseCase,
            fetchServerInfoUseCase: MockFetchServerInfoUseCase()
        )

        try await useCase.execute(id: spaceID, name: "Updated", primaryURL: "new-url", defaultIdentityID: defaultIdentityID)

        let updatedSpace = mockSpaceRepository.updatedSpace
        #expect(updatedSpace?.id == spaceID)
        #expect(updatedSpace?.defaultIdentityID == defaultIdentityID)
        #expect(updatedSpace?.orderIndex == 5)
        #expect(updatedSpace?.createdAt == createdAt)
    }

    @Test func testAppendsPeersDiscoveredFromServerInfo() async throws {
        let mockSpaceRepository = MockSpaceRepository()
        let mockGetSpaceUseCase = MockGetSpaceUseCase()
        let spaceID = UUID()
        mockGetSpaceUseCase.result = Space(
            id: spaceID, name: "Space", url: "https://node-a.example.com",
            defaultIdentityID: nil, orderIndex: 0, createdAt: .now, updatedAt: .now
        )
        let mockFetchInfo = MockFetchServerInfoUseCase(
            result: WevoServerInfo(peers: ["https://node-b.example.com", "https://node-c.example.com"])
        )

        let useCase = EditSpaceUseCaseImpl(
            spaceRepository: mockSpaceRepository,
            getSpaceUseCase: mockGetSpaceUseCase,
            fetchServerInfoUseCase: mockFetchInfo
        )

        try await useCase.execute(id: spaceID, name: "Space", primaryURL: "https://node-a.example.com", defaultIdentityID: nil)

        let urls = mockSpaceRepository.updatedSpace?.urls
        #expect(urls?.count == 3)
        #expect(urls?.contains("https://node-b.example.com") == true)
        #expect(urls?.contains("https://node-c.example.com") == true)
    }

    @Test func testPreservesKnownPeersWhenServerInfoUnreachable() async throws {
        let mockSpaceRepository = MockSpaceRepository()
        let mockGetSpaceUseCase = MockGetSpaceUseCase()
        let spaceID = UUID()
        mockGetSpaceUseCase.result = Space(
            id: spaceID, name: "Space",
            urls: ["https://node-a.example.com", "https://node-b.example.com"],
            defaultIdentityID: nil, orderIndex: 0, createdAt: .now, updatedAt: .now
        )

        let useCase = EditSpaceUseCaseImpl(
            spaceRepository: mockSpaceRepository,
            getSpaceUseCase: mockGetSpaceUseCase,
            fetchServerInfoUseCase: MockFetchServerInfoUseCase(error: URLError(.notConnectedToInternet))
        )

        try await useCase.execute(id: spaceID, name: "Space", primaryURL: "https://node-a.example.com", defaultIdentityID: nil)

        #expect(mockSpaceRepository.updatedSpace?.urls.count == 2)
        #expect(mockSpaceRepository.updatedSpace?.urls.contains("https://node-b.example.com") == true)
    }

    @Test func testFallsBackToSingleURLWhenServerInfoUnreachableAndNoPeers() async throws {
        let mockSpaceRepository = MockSpaceRepository()
        let mockGetSpaceUseCase = MockGetSpaceUseCase()
        let spaceID = UUID()
        mockGetSpaceUseCase.result = Space(
            id: spaceID, name: "Space", url: "https://example.com",
            defaultIdentityID: nil, orderIndex: 0, createdAt: .now, updatedAt: .now
        )

        let useCase = EditSpaceUseCaseImpl(
            spaceRepository: mockSpaceRepository,
            getSpaceUseCase: mockGetSpaceUseCase,
            fetchServerInfoUseCase: MockFetchServerInfoUseCase(error: URLError(.notConnectedToInternet))
        )

        try await useCase.execute(id: spaceID, name: "Space", primaryURL: "https://example.com", defaultIdentityID: nil)

        #expect(mockSpaceRepository.updatedSpace?.urls == ["https://example.com"])
    }

    @Test func testThrowsWhenGetSpaceFails() async throws {
        let mockSpaceRepository = MockSpaceRepository()
        let mockGetSpaceUseCase = MockGetSpaceUseCase()
        mockGetSpaceUseCase.error = NSError(domain: "Test", code: -1)

        let useCase = EditSpaceUseCaseImpl(
            spaceRepository: mockSpaceRepository,
            getSpaceUseCase: mockGetSpaceUseCase,
            fetchServerInfoUseCase: MockFetchServerInfoUseCase()
        )

        await #expect(throws: NSError.self) {
            try await useCase.execute(id: UUID(), name: "New", primaryURL: "new-url", defaultIdentityID: nil)
        }
    }

    @Test func testThrowsWhenUpdateFails() async throws {
        let mockSpaceRepository = MockSpaceRepository()
        let mockGetSpaceUseCase = MockGetSpaceUseCase()
        let spaceID = UUID()
        mockGetSpaceUseCase.result = Space(
            id: spaceID, name: "Original", url: "original-url",
            defaultIdentityID: nil, orderIndex: 0, createdAt: .now, updatedAt: .now
        )
        mockSpaceRepository.updateError = NSError(domain: "Test", code: -1)

        let useCase = EditSpaceUseCaseImpl(
            spaceRepository: mockSpaceRepository,
            getSpaceUseCase: mockGetSpaceUseCase,
            fetchServerInfoUseCase: MockFetchServerInfoUseCase()
        )

        await #expect(throws: NSError.self) {
            try await useCase.execute(id: spaceID, name: "Updated", primaryURL: "new-url", defaultIdentityID: nil)
        }
    }
}
