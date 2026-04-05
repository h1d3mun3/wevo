//
//  FetchServerInfoUseCase.swift
//  Wevo
//

import Foundation
import os

enum FetchServerInfoUseCaseError: Error {
    case invalidURL
    case serverError(statusCode: Int)
    case decodingError(Error)
}

/// Result of a successful /info call.
struct WevoServerInfo {
    let peers: [String]
}

protocol FetchServerInfoUseCase {
    func execute(urlString: String) async throws -> WevoServerInfo
}

struct FetchServerInfoUseCaseImpl: FetchServerInfoUseCase {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func execute(urlString: String) async throws -> WevoServerInfo {
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let base = URL(string: trimmed) else {
            throw FetchServerInfoUseCaseError.invalidURL
        }
        let url = base.appendingPathComponent("info")

        let (data, response) = try await session.data(from: url)

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
