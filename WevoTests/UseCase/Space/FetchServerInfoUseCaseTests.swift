//
//  FetchServerInfoUseCaseTests.swift
//  WevoTests
//

import Testing
import Foundation
@testable import Wevo

// MARK: - Mock HTTP Client

struct MockHTTPClient: HTTPDataFetching {
    let handler: @Sendable (URL) async throws -> (Data, URLResponse)

    func data(from url: URL) async throws -> (Data, URLResponse) {
        try await handler(url)
    }

    static func responding(statusCode: Int, body: String) -> MockHTTPClient {
        MockHTTPClient { url in
            let response = HTTPURLResponse(url: url, statusCode: statusCode, httpVersion: nil, headerFields: nil)!
            return (body.data(using: .utf8)!, response)
        }
    }

    static func throwing(_ error: Error) -> MockHTTPClient {
        MockHTTPClient { _ in throw error }
    }
}

// MARK: - Tests

struct FetchServerInfoUseCaseTests {

    @Test func testReturnsInfoWithPeers() async throws {
        let json = #"{"version":"0.2.0","peers":["https://node-b.example.com","https://node-c.example.com"]}"#
        let useCase = FetchServerInfoUseCaseImpl(httpClient: MockHTTPClient.responding(statusCode: 200, body: json))

        let info = try await useCase.execute(urlString: "https://node-a.example.com")

        #expect(info.peers == ["https://node-b.example.com", "https://node-c.example.com"])
    }

    @Test func testReturnsEmptyPeersWhenNoneConfigured() async throws {
        let json = #"{"version":"0.2.0","peers":[]}"#
        let useCase = FetchServerInfoUseCaseImpl(httpClient: MockHTTPClient.responding(statusCode: 200, body: json))

        let info = try await useCase.execute(urlString: "https://node-a.example.com")

        #expect(info.peers.isEmpty)
    }

    @Test func testAppendsInfoPathToBaseURL() async throws {
        var capturedURL: URL?
        let useCase = FetchServerInfoUseCaseImpl(httpClient: MockHTTPClient { url in
            capturedURL = url
            let json = #"{"version":"0.2.0","peers":[]}"#
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (json.data(using: .utf8)!, response)
        })

        _ = try await useCase.execute(urlString: "https://example.com")

        #expect(capturedURL?.absoluteString == "https://example.com/info")
    }

    @Test func testTrimsWhitespaceFromURL() async throws {
        var capturedURL: URL?
        let useCase = FetchServerInfoUseCaseImpl(httpClient: MockHTTPClient { url in
            capturedURL = url
            let json = #"{"version":"0.2.0","peers":[]}"#
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (json.data(using: .utf8)!, response)
        })

        _ = try await useCase.execute(urlString: "  https://example.com  ")

        #expect(capturedURL?.host == "example.com")
    }

    @Test func testThrowsInvalidURLForEmptyString() async throws {
        // httpClient is not called but required for type conformance
        let useCase = FetchServerInfoUseCaseImpl(httpClient: MockHTTPClient.throwing(URLError(.badURL)))

        await #expect(throws: FetchServerInfoUseCaseError.invalidURL) {
            try await useCase.execute(urlString: "")
        }
    }

@Test func testThrowsServerErrorOn404() async throws {
        let useCase = FetchServerInfoUseCaseImpl(httpClient: MockHTTPClient.responding(statusCode: 404, body: ""))

        await #expect(throws: FetchServerInfoUseCaseError.serverError(statusCode: 404)) {
            try await useCase.execute(urlString: "https://example.com")
        }
    }

    @Test func testThrowsServerErrorOn500() async throws {
        let useCase = FetchServerInfoUseCaseImpl(httpClient: MockHTTPClient.responding(statusCode: 500, body: ""))

        await #expect(throws: FetchServerInfoUseCaseError.serverError(statusCode: 500)) {
            try await useCase.execute(urlString: "https://example.com")
        }
    }

    @Test func testThrowsDecodingErrorForInvalidJSON() async throws {
        let useCase = FetchServerInfoUseCaseImpl(httpClient: MockHTTPClient.responding(statusCode: 200, body: "not json"))

        // decodingError has an associated value, so check by type instead of by value
        await #expect(throws: FetchServerInfoUseCaseError.self) {
            try await useCase.execute(urlString: "https://example.com")
        }
    }

    @Test func testThrowsDecodingErrorWhenPeersFieldMissing() async throws {
        let json = #"{"version":"0.2.0"}"#  // no peers field
        let useCase = FetchServerInfoUseCaseImpl(httpClient: MockHTTPClient.responding(statusCode: 200, body: json))

        await #expect(throws: FetchServerInfoUseCaseError.self) {
            try await useCase.execute(urlString: "https://example.com")
        }
    }

    @Test func testThrowsOnNetworkError() async throws {
        let useCase = FetchServerInfoUseCaseImpl(httpClient: MockHTTPClient.throwing(URLError(.notConnectedToInternet)))

        await #expect(throws: URLError.self) {
            try await useCase.execute(urlString: "https://example.com")
        }
    }
}
