//
//  ProposeAPIClient.swift
//  WevoSpace
//
//  Created on 3/6/26.
//

import Foundation
import CryptoKit

/// Protocol for ProposeAPIClient (conforms to the new backend API specification)
protocol ProposeAPIClientProtocol {
    func createPropose(input: ProposeAPIClient.CreateProposeInput) async throws
    func signPropose(proposeID: UUID, input: ProposeAPIClient.SignInput) async throws
    func dissolvePropose(proposeID: UUID, input: ProposeAPIClient.TransitionInput) async throws
    func honorPropose(proposeID: UUID, input: ProposeAPIClient.TransitionInput) async throws
    func partPropose(proposeID: UUID, input: ProposeAPIClient.TransitionInput) async throws
    func getPropose(proposeID: UUID) async throws -> HashedPropose
}

/// API client for ProposeController (new backend API specification)
actor ProposeAPIClient: ProposeAPIClientProtocol {
    private let baseURL: URL
    private let session: URLSession

    /// ISO8601 formatter (shared as a static let because instantiation is expensive)
    static let iso8601Formatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    /// ISO8601 formatter without fractional seconds (fallback)
    static let iso8601FormatterBasic: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    /// Initializer
    /// - Parameters:
    ///   - baseURL: The server's base URL (e.g. "https://api.example.com")
    ///   - session: Custom URLSession (defaults to .shared)
    init(baseURL: URL, session: URLSession = .shared) {
        self.baseURL = baseURL.appendingPathComponent("v1")
        self.session = session
    }

    // MARK: - DTOs (Data Transfer Objects)

    /// Input data for creating a propose (POST /v1/proposes)
    struct CreateProposeInput: Codable {
        /// UUID string of the Propose
        let proposeId: String
        /// SHA256 hash (Base64)
        let contentHash: String
        /// Creator's public key in JWK format
        let creatorPublicKey: String
        /// Creator's signature (Base64 DER)
        let creatorSignature: String
        /// List of counterparty public keys
        let counterpartyPublicKeys: [String]
        /// Creation timestamp (ISO8601)
        let createdAt: String
    }

    /// Input data when the Counterparty signs (PATCH /v1/proposes/:id/sign)
    struct SignInput: Codable {
        /// Signer's public key (JWK format)
        let signerPublicKey: String
        /// Signature data (Base64 DER)
        let signature: String
        /// Sign operation timestamp (ISO8601, client-generated and included in the signed message)
        let timestamp: String
    }

    /// Common input data for dissolve / honor / part
    struct TransitionInput: Codable {
        /// Operator's public key (JWK format)
        let publicKey: String
        /// Signature data (Base64 DER)
        let signature: String
        /// Timestamp (ISO8601)
        let timestamp: String
    }

    // MARK: - API Methods

    /// Create a new propose (POST /v1/proposes)
    /// - Parameter input: Input data for the propose
    /// - Throws: APIError
    func createPropose(input: CreateProposeInput) async throws {
        var request = URLRequest(url: baseURL.appendingPathComponent("proposes"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let encoder = JSONEncoder()
        request.httpBody = try encoder.encode(input)

        let (_, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        guard httpResponse.statusCode == 201 else {
            throw APIError.httpError(statusCode: httpResponse.statusCode)
        }
    }

    /// Counterparty signs (PATCH /v1/proposes/:id/sign)
    /// - Parameters:
    ///   - proposeID: UUID of the target Propose
    ///   - input: Signature input data
    /// - Throws: APIError
    func signPropose(proposeID: UUID, input: SignInput) async throws {
        let url = baseURL
            .appendingPathComponent("proposes")
            .appendingPathComponent(proposeID.uuidString)
            .appendingPathComponent("sign")

        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let encoder = JSONEncoder()
        request.httpBody = try encoder.encode(input)

        let (_, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            throw APIError.httpError(statusCode: httpResponse.statusCode)
        }
    }

    /// Dissolve a Propose (DELETE /v1/proposes/:id)
    /// - Parameters:
    ///   - proposeID: UUID of the target Propose
    ///   - input: Transition input data (signature required)
    /// - Throws: APIError
    func dissolvePropose(proposeID: UUID, input: TransitionInput) async throws {
        let url = baseURL
            .appendingPathComponent("proposes")
            .appendingPathComponent(proposeID.uuidString)

        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let encoder = JSONEncoder()
        request.httpBody = try encoder.encode(input)

        let (_, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            throw APIError.httpError(statusCode: httpResponse.statusCode)
        }
    }

    /// Honor a Propose (PATCH /v1/proposes/:id/honor)
    /// - Parameters:
    ///   - proposeID: UUID of the target Propose
    ///   - input: Transition input data (signature required)
    /// - Throws: APIError
    func honorPropose(proposeID: UUID, input: TransitionInput) async throws {
        let url = baseURL
            .appendingPathComponent("proposes")
            .appendingPathComponent(proposeID.uuidString)
            .appendingPathComponent("honor")

        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let encoder = JSONEncoder()
        request.httpBody = try encoder.encode(input)

        let (_, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            throw APIError.httpError(statusCode: httpResponse.statusCode)
        }
    }

    /// Part a Propose (PATCH /v1/proposes/:id/part)
    /// - Parameters:
    ///   - proposeID: UUID of the target Propose
    ///   - input: Transition input data (signature required)
    /// - Throws: APIError
    func partPropose(proposeID: UUID, input: TransitionInput) async throws {
        let url = baseURL
            .appendingPathComponent("proposes")
            .appendingPathComponent(proposeID.uuidString)
            .appendingPathComponent("part")

        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let encoder = JSONEncoder()
        request.httpBody = try encoder.encode(input)

        let (_, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            throw APIError.httpError(statusCode: httpResponse.statusCode)
        }
    }

    /// Retrieve propose details by UUID (GET /v1/proposes/:id)
    /// - Parameter proposeID: UUID of the propose
    /// - Returns: Server's Propose response
    /// - Throws: APIError
    func getPropose(proposeID: UUID) async throws -> HashedPropose {
        let url = baseURL
            .appendingPathComponent("proposes")
            .appendingPathComponent(proposeID.uuidString)

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            throw APIError.httpError(statusCode: httpResponse.statusCode)
        }

        let decoder = JSONDecoder()
        // Custom decoding for ISO8601 (supports both with and without fractional seconds)
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let dateString = try container.decode(String.self)
            if let date = ProposeAPIClient.iso8601Formatter.date(from: dateString) {
                return date
            }
            if let date = ProposeAPIClient.iso8601FormatterBasic.date(from: dateString) {
                return date
            }
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Failed to parse ISO8601 date: \(dateString)"
            )
        }

        return try decoder.decode(HashedPropose.self, from: data)
    }

    // MARK: - Error Handling

    enum APIError: LocalizedError {
        case invalidURL
        case invalidResponse
        case httpError(statusCode: Int)
        case decodingError(Error)

        var errorDescription: String? {
            switch self {
            case .invalidURL:
                return "Invalid URL"
            case .invalidResponse:
                return "Invalid response from server"
            case .httpError(let statusCode):
                return "HTTP error: \(statusCode)"
            case .decodingError(let error):
                return "Decoding error: \(error.localizedDescription)"
            }
        }
    }
}
