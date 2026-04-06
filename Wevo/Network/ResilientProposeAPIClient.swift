//
//  ResilientProposeAPIClient.swift
//  Wevo
//

import Foundation

/// Wraps ProposeAPIClient with automatic failover across multiple node URLs.
/// Tries each URL in order; skips to the next on network errors or 5xx responses.
/// 4xx responses (client errors) are thrown immediately without retrying.
actor ResilientProposeAPIClient: ProposeAPIClientProtocol {
    private let baseURLs: [URL]
    private let session: URLSession

    init(urls: [String], session: URLSession = .shared) {
        self.baseURLs = urls.compactMap { URL(string: $0) }
            .filter { $0.scheme == "https" || $0.scheme == "http" }
        self.session = session
    }

    func createPropose(input: ProposeAPIClient.CreateProposeInput) async throws {
        try await tryEachNode { try await $0.createPropose(input: input) }
    }

    func signPropose(proposeID: UUID, input: ProposeAPIClient.SignInput) async throws {
        try await tryEachNode { try await $0.signPropose(proposeID: proposeID, input: input) }
    }

    func dissolvePropose(proposeID: UUID, input: ProposeAPIClient.TransitionInput) async throws {
        try await tryEachNode { try await $0.dissolvePropose(proposeID: proposeID, input: input) }
    }

    func honorPropose(proposeID: UUID, input: ProposeAPIClient.TransitionInput) async throws {
        try await tryEachNode { try await $0.honorPropose(proposeID: proposeID, input: input) }
    }

    func partPropose(proposeID: UUID, input: ProposeAPIClient.TransitionInput) async throws {
        try await tryEachNode { try await $0.partPropose(proposeID: proposeID, input: input) }
    }

    func getPropose(proposeID: UUID) async throws -> HashedPropose {
        try await tryEachNode { try await $0.getPropose(proposeID: proposeID) }
    }

    // MARK: - Private

    private func tryEachNode<T>(_ operation: (ProposeAPIClient) async throws -> T) async throws -> T {
        guard !baseURLs.isEmpty else {
            throw ProposeAPIClient.APIError.invalidURL
        }
        var lastError: Error = ProposeAPIClient.APIError.invalidURL
        for baseURL in baseURLs {
            let client = ProposeAPIClient(baseURL: baseURL, session: session)
            do {
                return try await operation(client)
            } catch ProposeAPIClient.APIError.httpError(let code) where (400..<500).contains(code) {
                // Client errors are definitive — don't retry on other nodes
                throw ProposeAPIClient.APIError.httpError(statusCode: code)
            } catch {
                lastError = error
            }
        }
        throw lastError
    }
}
