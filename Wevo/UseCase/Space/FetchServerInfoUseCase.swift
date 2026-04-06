//
//  FetchServerInfoUseCase.swift
//  Wevo
//

import Foundation
import os

enum FetchServerInfoUseCaseError: Error, Equatable {
    case invalidURL
    case serverError(statusCode: Int)
    case decodingError(Error)

    static func == (lhs: Self, rhs: Self) -> Bool {
        switch (lhs, rhs) {
        case (.invalidURL, .invalidURL): return true
        case (.serverError(let a), .serverError(let b)): return a == b
        case (.decodingError, .decodingError): return true
        default: return false
        }
    }
}

/// Result of a successful /info call.
struct WevoServerInfo {
    let peers: [String]
}

protocol FetchServerInfoUseCase {
    func execute(urlString: String) async throws -> WevoServerInfo
}

// MARK: - HTTP abstraction (enables test injection without URLProtocol)

protocol HTTPDataFetching: Sendable {
    func data(from url: URL) async throws -> (Data, URLResponse)
}

extension URLSession: HTTPDataFetching {}

// MARK: - Implementation

struct FetchServerInfoUseCaseImpl: FetchServerInfoUseCase {
    private let httpClient: any HTTPDataFetching

    init(httpClient: any HTTPDataFetching = URLSession.shared) {
        self.httpClient = httpClient
    }

    func execute(urlString: String) async throws -> WevoServerInfo {
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let base = URL(string: trimmed) else {
            throw FetchServerInfoUseCaseError.invalidURL
        }
        let url = base.appendingPathComponent("info")

        let (data, response) = try await httpClient.data(from: url)

        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            throw FetchServerInfoUseCaseError.serverError(statusCode: http.statusCode)
        }

        do {
            let decoded = try JSONDecoder().decode(InfoResponse.self, from: data)
            return WevoServerInfo(peers: decoded.peers)
        } catch {
            throw FetchServerInfoUseCaseError.decodingError(error)
        }
    }
}

// MARK: - Response DTO

private struct InfoResponse: Decodable {
    let peers: [String]
}
