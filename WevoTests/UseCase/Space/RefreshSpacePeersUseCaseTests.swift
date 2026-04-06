//
//  RefreshSpacePeersUseCaseTests.swift
//  WevoTests
//

import Testing
import Foundation
@testable import Wevo

@MainActor
struct RefreshSpacePeersUseCaseTests {

    // MARK: - Helpers

    func makeSpace(url: String = "https://node-a.example.com") -> Space {
        Space(
            id: UUID(),
            name: "Test Space",
            urls: [url],
            defaultIdentityID: nil,
            orderIndex: 0,
            createdAt: .now,
            updatedAt: .now
        )
    }

    func makeUseCase(space: Space, httpClient: MockHTTPClient) -> RefreshSpacePeersUseCaseImpl {
        let repo = MockSpaceRepository()
        repo.fetchAllResult = [space]
        return RefreshSpacePeersUseCaseImpl(spaceRepository: repo, httpClient: httpClient)
    }

    // MARK: - Tests

    @Test("Updates nodeURLs when /info returns new peers")
    func testUpdatesNodeURLsFromInfoResponse() async throws {
        let space = makeSpace()
        let repo = MockSpaceRepository()
        repo.fetchAllResult = [space]
        let json = #"{"version":"0.2.0","peers":["https://node-b.example.com"]}"#
        let useCase = RefreshSpacePeersUseCaseImpl(
            spaceRepository: repo,
            httpClient: MockHTTPClient.responding(statusCode: 200, body: json)
        )

        await useCase.execute()

        #expect(repo.updateCalled)
        #expect(repo.updatedSpace?.urls == ["https://node-a.example.com", "https://node-b.example.com"])
    }

    @Test("Does not update when /info returns no new peers")
    func testDoesNotUpdateWhenURLsUnchanged() async throws {
        let space = Space(
            id: UUID(),
            name: "Test Space",
            urls: ["https://node-a.example.com", "https://node-b.example.com"],
            defaultIdentityID: nil,
            orderIndex: 0,
            createdAt: .now,
            updatedAt: .now
        )
        let repo = MockSpaceRepository()
        repo.fetchAllResult = [space]
        let json = #"{"version":"0.2.0","peers":["https://node-b.example.com"]}"#
        let useCase = RefreshSpacePeersUseCaseImpl(
            spaceRepository: repo,
            httpClient: MockHTTPClient.responding(statusCode: 200, body: json)
        )

        await useCase.execute()

        #expect(!repo.updateCalled)
    }

    @Test("Keeps existing URLs when /info is unreachable")
    func testKeepsExistingURLsWhenInfoFails() async throws {
        let space = makeSpace()
        let repo = MockSpaceRepository()
        repo.fetchAllResult = [space]
        let useCase = RefreshSpacePeersUseCaseImpl(
            spaceRepository: repo,
            httpClient: MockHTTPClient.throwing(URLError(.notConnectedToInternet))
        )

        await useCase.execute()

        #expect(!repo.updateCalled)
    }

    @Test("Skips spaces with empty primary URL")
    func testSkipsSpaceWithEmptyURL() async throws {
        let space = Space(
            id: UUID(),
            name: "No URL Space",
            urls: [],
            defaultIdentityID: nil,
            orderIndex: 0,
            createdAt: .now,
            updatedAt: .now
        )
        let repo = MockSpaceRepository()
        repo.fetchAllResult = [space]
        let useCase = RefreshSpacePeersUseCaseImpl(
            spaceRepository: repo,
            httpClient: MockHTTPClient.throwing(URLError(.badURL))
        )

        await useCase.execute()

        #expect(!repo.updateCalled)
    }

    @Test("Handles fetchAll failure gracefully")
    func testHandlesFetchAllError() async throws {
        let repo = MockSpaceRepository()
        repo.fetchAllError = NSError(domain: "test", code: -1)
        let useCase = RefreshSpacePeersUseCaseImpl(
            spaceRepository: repo,
            httpClient: MockHTTPClient.responding(statusCode: 200, body: #"{"version":"0.2.0","peers":[]}"#)
        )

        // Should not throw
        await useCase.execute()

        #expect(!repo.updateCalled)
    }

    @Test("Excludes primary URL from peers to avoid duplicates")
    func testExcludesPrimaryURLFromPeers() async throws {
        let space = makeSpace()
        let repo = MockSpaceRepository()
        repo.fetchAllResult = [space]
        // /info returns the primary URL itself as a peer (misconfiguration)
        let json = #"{"version":"0.2.0","peers":["https://node-a.example.com","https://node-b.example.com"]}"#
        let useCase = RefreshSpacePeersUseCaseImpl(
            spaceRepository: repo,
            httpClient: MockHTTPClient.responding(statusCode: 200, body: json)
        )

        await useCase.execute()

        #expect(repo.updatedSpace?.urls == ["https://node-a.example.com", "https://node-b.example.com"])
    }
}
