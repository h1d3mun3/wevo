//
//  FetchServerInfoUseCase.swift
//  Wevo
//

import Foundation
import Network
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

    /// Constrains peer URLs advertised by a server before they are stored and later used as API
    /// failover endpoints: keep only well-formed absolute **https** URLs whose host is publicly
    /// routable, de-duplicate, and cap the count.
    ///
    /// These peers are chosen by the server, not the user, so they are held to a higher bar than a
    /// user-entered primary URL (which may still be http per the ATS product decision, and is
    /// normalized separately by `String.normalizedServerURL`):
    /// - **https only** — a compromised/hostile primary cannot inject a plaintext peer to silently
    ///   downgrade failover traffic.
    /// - **no loopback/private/link-local hosts** — cannot point failover at the user's local
    ///   network or device (SSRF / internal-endpoint pivot).
    static func sanitizePeers(_ peers: [String]) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        for raw in peers {
            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard let url = URL(string: trimmed),
                  url.scheme?.lowercased() == "https",
                  let host = url.host, !host.isEmpty,
                  !isNonRoutablePeerHost(host) else { continue }
            guard seen.insert(trimmed).inserted else { continue }
            result.append(trimmed)
            if result.count >= maxPeers { break }
        }
        return result
    }

    /// True for hosts a server-advertised peer must never resolve to: localhost, `.local`/mDNS
    /// names, and loopback / private / link-local IP literals. Hostnames that are not IP literals
    /// (ordinary public DNS names) pass — only literals are range-checked here.
    static func isNonRoutablePeerHost(_ host: String) -> Bool {
        let h = host.lowercased()
        if h == "localhost" || h.hasSuffix(".local") || h.hasSuffix(".localhost") { return true }

        if let v4 = IPv4Address(h) {
            let b = [UInt8](v4.rawValue)
            guard b.count == 4 else { return true }
            if b[0] == 0 { return true }                                // 0.0.0.0/8   "this network"
            if b[0] == 10 { return true }                               // 10.0.0.0/8  private
            if b[0] == 127 { return true }                              // 127.0.0.0/8 loopback
            if b[0] == 169 && b[1] == 254 { return true }               // 169.254.0.0/16 link-local
            if b[0] == 172 && (16...31).contains(b[1]) { return true }  // 172.16.0.0/12 private
            if b[0] == 192 && b[1] == 168 { return true }               // 192.168.0.0/16 private
            return false
        }
        if let v6 = IPv6Address(h) {
            let b = [UInt8](v6.rawValue)
            guard b.count == 16 else { return true }
            if b.prefix(15).allSatisfy({ $0 == 0 }) && b[15] == 1 { return true } // ::1 loopback
            if b[0] == 0xfe && (b[1] & 0xc0) == 0x80 { return true }    // fe80::/10 link-local
            if (b[0] & 0xfe) == 0xfc { return true }                    // fc00::/7  unique-local
            return false
        }
        return false
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
