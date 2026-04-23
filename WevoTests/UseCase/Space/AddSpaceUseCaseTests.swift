//
//  AddSpaceUseCaseTests.swift
//  WevoTests
//
//  Created by hidemune on 3/10/26.
//

import Testing
import Foundation
@testable import Wevo

// MARK: - Mock

struct MockFetchServerInfoUseCase: FetchServerInfoUseCase {
    var result: WevoServerInfo?
    var error: Error?

    func execute(urlString: String) async throws -> WevoServerInfo {
        if let error = error { throw error }
        guard let result = result else { throw URLError(.notConnectedToInternet) }
        return result
    }
}

// MARK: - Tests

@MainActor
struct AddSpaceUseCaseTests {

    @Test func testCreatesSpaceWithCorrectOrderIndex() async throws {
        let mockRepository = MockSpaceRepository()
        let existingSpaces = [
            Space(id: UUID(), name: "Space 1", url: "url1", defaultIdentityID: nil, orderIndex: 0, createdAt: .now, updatedAt: .now),
            Space(id: UUID(), name: "Space 2", url: "url2", defaultIdentityID: nil, orderIndex: 1, createdAt: .now, updatedAt: .now)
        ]
        mockRepository.fetchAllResult = existingSpaces

        let useCase = AddSpaceUseCaseImpl(
            spaceRepository: mockRepository,
            fetchServerInfoUseCase: MockFetchServerInfoUseCase()
        )

        try await useCase.execute(name: "New Space", primaryURL: "https://example.com", defaultIdentityID: nil)

        #expect(mockRepository.createCalled == true)
        #expect(mockRepository.createdSpace?.orderIndex == 2)
        #expect(mockRepository.createdSpace?.name == "New Space")
    }

    @Test func testFallsBackToOrderIndexZeroWhenFetchAllFails() async throws {
        let mockRepository = MockSpaceRepository()
        mockRepository.fetchAllError = NSError(domain: "Test", code: -1)

        let useCase = AddSpaceUseCaseImpl(
            spaceRepository: mockRepository,
            fetchServerInfoUseCase: MockFetchServerInfoUseCase()
        )

        try await useCase.execute(name: "New Space", primaryURL: "https://example.com", defaultIdentityID: nil)

        #expect(mockRepository.createCalled == true)
        #expect(mockRepository.createdSpace?.orderIndex == 0)
    }

    @Test func testTrimsNameAndURL() async throws {
        let mockRepository = MockSpaceRepository()
        mockRepository.fetchAllResult = []

        let useCase = AddSpaceUseCaseImpl(
            spaceRepository: mockRepository,
            fetchServerInfoUseCase: MockFetchServerInfoUseCase()
        )

        try await useCase.execute(name: "  My Space  ", primaryURL: "  https://example.com  ", defaultIdentityID: nil)

        #expect(mockRepository.createdSpace?.name == "My Space")
        #expect(mockRepository.createdSpace?.url == "https://example.com")
    }

    @Test func testPassesDefaultIdentityID() async throws {
        let mockRepository = MockSpaceRepository()
        mockRepository.fetchAllResult = []
        let defaultIdentityID = UUID()

        let useCase = AddSpaceUseCaseImpl(
            spaceRepository: mockRepository,
            fetchServerInfoUseCase: MockFetchServerInfoUseCase()
        )

        try await useCase.execute(name: "Space", primaryURL: "https://example.com", defaultIdentityID: defaultIdentityID)

        #expect(mockRepository.createdSpace?.defaultIdentityID == defaultIdentityID)
    }

    @Test func testThrowsWhenCreateFails() async throws {
        let mockRepository = MockSpaceRepository()
        mockRepository.fetchAllResult = []
        mockRepository.createError = NSError(domain: "Test", code: -1)

        let useCase = AddSpaceUseCaseImpl(
            spaceRepository: mockRepository,
            fetchServerInfoUseCase: MockFetchServerInfoUseCase()
        )

        await #expect(throws: NSError.self) {
            try await useCase.execute(name: "Space", primaryURL: "https://example.com", defaultIdentityID: nil)
        }
    }

    @Test func testAppendsPeersDiscoveredFromServerInfo() async throws {
        let mockRepository = MockSpaceRepository()
        mockRepository.fetchAllResult = []
        let mockFetchInfo = MockFetchServerInfoUseCase(
            result: WevoServerInfo(peers: ["https://node-b.example.com", "https://node-c.example.com"])
        )

        let useCase = AddSpaceUseCaseImpl(
            spaceRepository: mockRepository,
            fetchServerInfoUseCase: mockFetchInfo
        )

        try await useCase.execute(name: "Space", primaryURL: "https://node-a.example.com", defaultIdentityID: nil)

        let urls = mockRepository.createdSpace?.urls
        #expect(urls?.count == 3)
        #expect(urls?.first == "https://node-a.example.com")
        #expect(urls?.contains("https://node-b.example.com") == true)
        #expect(urls?.contains("https://node-c.example.com") == true)
    }

    @Test func testDeduplicatesPrimaryURLFromPeers() async throws {
        let mockRepository = MockSpaceRepository()
        mockRepository.fetchAllResult = []
        let mockFetchInfo = MockFetchServerInfoUseCase(
            result: WevoServerInfo(peers: ["https://node-a.example.com", "https://node-b.example.com"])
        )

        let useCase = AddSpaceUseCaseImpl(
            spaceRepository: mockRepository,
            fetchServerInfoUseCase: mockFetchInfo
        )

        try await useCase.execute(name: "Space", primaryURL: "https://node-a.example.com", defaultIdentityID: nil)

        let urls = mockRepository.createdSpace?.urls
        #expect(urls?.count == 2)
        #expect(urls?.filter { $0 == "https://node-a.example.com" }.count == 1)
    }

    @Test func testGracefullyDegradeWhenServerInfoUnreachable() async throws {
        let mockRepository = MockSpaceRepository()
        mockRepository.fetchAllResult = []
        let mockFetchInfo = MockFetchServerInfoUseCase(error: URLError(.notConnectedToInternet))

        let useCase = AddSpaceUseCaseImpl(
            spaceRepository: mockRepository,
            fetchServerInfoUseCase: mockFetchInfo
        )

        try await useCase.execute(name: "Space", primaryURL: "https://example.com", defaultIdentityID: nil)

        #expect(mockRepository.createdSpace?.urls == ["https://example.com"])
    }
}
