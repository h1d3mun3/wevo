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

    /// Upper bound on auto-discovered peers persisted from a single /info response.
    static let maxPeers = 16

    init(httpClient: any HTTPDataFetching = URLSession.shared) {
        self.httpClient = httpClient
    }

    /// Constrains peer URLs advertised by a server before they are stored and later used for API
    /// calls: keep only well-formed absolute http/https URLs with a host, de-duplicate, and cap the
    /// count. Prevents a malicious/compromised primary from injecting malformed or odd-scheme
    /// endpoints. (http is intentionally still allowed; ATS is disabled by product decision.)
    static func sanitizePeers(_ peers: [String]) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        for raw in peers {
            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard let url = URL(string: trimmed),
                  let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https",
                  let host = url.host, !host.isEmpty else { continue }
            guard seen.insert(trimmed).inserted else { continue }
            result.append(trimmed)
            if result.count >= maxPeers { break }
        }
        return result
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
            return WevoServerInfo(peers: Self.sanitizePeers(decoded.peers))
        } catch {
            throw FetchServerInfoUseCaseError.decodingError(error)
        }
    }
}

// MARK: - Response DTO

private struct InfoResponse: Decodable {
    let peers: [String]
}
