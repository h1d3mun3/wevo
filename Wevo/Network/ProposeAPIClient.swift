//
//  ProposeAPIClient.swift
//  WevoSpace
//
//  Created on 3/6/26.
//

import Foundation
import CryptoKit

/// ProposeController用のAPIクライアント
actor ProposeAPIClient {
    private let baseURL: URL
    private let session: URLSession

    /// イニシャライザ
    /// - Parameters:
    ///   - baseURL: サーバーのベースURL（例: "https://api.example.com"）
    ///   - session: カスタムURLSession（デフォルトは.shared）
    init(baseURL: URL, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
    }

    // MARK: - DTOs (Data Transfer Objects)

    /// 提案作成時の入力データ
    struct ProposeInput: Codable {
        let id: UUID
        let payloadHash: String
        let publicKey: String
        let signature: String
    }

    /// 署名追加時の入力データ
    struct SignInput: Codable {
        let publicKey: String
        let signature: String
    }

    /// ページネーション結果
    struct Page<T: Codable>: Codable {
        let items: [T]
        let metadata: Metadata

        struct Metadata: Codable {
            let page: Int
            let per: Int
            let total: Int
        }
    }

    // MARK: - API Methods

    /// 新しい提案を作成
    /// - Parameter input: 提案の入力データ
    /// - Throws: APIError
    func createPropose(input: ProposeInput) async throws {
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

    /// 提案に署名を追加
    /// - Parameters:
    ///   - proposeID: 提案のUUID
    ///   - input: 署名の入力データ
    /// - Throws: APIError
    func signPropose(proposeID: UUID, input: SignInput) async throws {
        var request = URLRequest(
            url: baseURL
                .appendingPathComponent("proposes")
                .appendingPathComponent(proposeID.uuidString)
                .appendingPathComponent("sign")
        )
        request.httpMethod = "POST"
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

    /// 指定したUUIDの提案詳細を取得
    /// - Parameter proposeID: 提案のUUID
    /// - Returns: ハッシュ化された提案データ
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
        decoder.dateDecodingStrategy = .iso8601

        return try decoder.decode(HashedPropose.self, from: data)
    }

    /// 公開鍵で提案一覧を取得（ページネーション対応）
    /// - Parameters:
    ///   - publicKey: 署名者の公開鍵
    ///   - page: ページ番号（デフォルト: 1）
    ///   - per: 1ページあたりの件数（デフォルト: 20）
    /// - Returns: ページネーション結果
    /// - Throws: APIError
    func listProposes(publicKey: String, page: Int = 1, per: Int = 20) async throws -> Page<HashedPropose> {
        var components = URLComponents(url: baseURL.appendingPathComponent("proposes"), resolvingAgainstBaseURL: true)

        // percentEncodedQueryItems で手動エンコード
        let encodedPublicKey = publicKey
            .addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? publicKey

        components?.percentEncodedQueryItems = [
            URLQueryItem(name: "publicKey", value: encodedPublicKey),
            URLQueryItem(name: "page", value: String(page)),
            URLQueryItem(name: "per", value: String(per))
        ]

        guard let url = components?.url else {
            throw APIError.invalidURL
        }

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
        decoder.dateDecodingStrategy = .iso8601

        return try decoder.decode(Page<HashedPropose>.self, from: data)
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
                return "無効なURLです"
            case .invalidResponse:
                return "サーバーからの応答が無効です"
            case .httpError(let statusCode):
                return "HTTPエラー: \(statusCode)"
            case .decodingError(let error):
                return "デコードエラー: \(error.localizedDescription)"
            }
        }
    }
}

// MARK: - 使用例

/*
// 使用例1: 新しい提案を作成
let client = ProposeAPIClient(baseURL: URL(string: "https://api.example.com")!)

// 秘密鍵を生成または読み込む
let privateKey = P256.Signing.PrivateKey()
let publicKey = privateKey.publicKey

// メッセージのハッシュを作成
let payloadHash = "some-payload-hash"
let signature = try ProposeAPIClient.createSignature(for: payloadHash, using: privateKey)
let publicKeyString = ProposeAPIClient.encodePublicKey(publicKey)

// 提案を作成
let input = ProposeAPIClient.ProposeInput(
    id: UUID(),
    payloadHash: payloadHash,
    publicKey: publicKeyString,
    signature: signature
)

try await client.createPropose(input: input)

// 使用例2: 提案一覧を取得
let page = try await client.listProposes(publicKey: publicKeyString, page: 1, per: 20)
print("取得した提案: \(page.items.count)件")
print("全体: \(page.metadata.total)件")

// 使用例3: 提案詳細を取得
let propose = try await client.getPropose(proposeID: someUUID)
print("署名数: \(propose.signatures.count)")

// 使用例4: 提案に署名を追加
let signInput = ProposeAPIClient.SignInput(
    publicKey: publicKeyString,
    signature: signature
)
try await client.signPropose(proposeID: someUUID, input: signInput)
*/
