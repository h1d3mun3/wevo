//
//  ProposeAPIClient.swift
//  WevoSpace
//
//  Created on 3/6/26.
//

import Foundation
import CryptoKit

/// ProposeAPIClientのプロトコル（新バックエンドAPI仕様に対応）
protocol ProposeAPIClientProtocol {
    func createPropose(input: ProposeAPIClient.CreateProposeInput) async throws
    func signPropose(proposeID: UUID, input: ProposeAPIClient.SignInput) async throws
    func dissolvePropose(proposeID: UUID, input: ProposeAPIClient.TransitionInput) async throws
    func honorPropose(proposeID: UUID, input: ProposeAPIClient.TransitionInput) async throws
    func partPropose(proposeID: UUID, input: ProposeAPIClient.TransitionInput) async throws
    func getPropose(proposeID: UUID) async throws -> HashedPropose
    func listProposes(publicKey: String, status: String?, page: Int, per: Int) async throws -> ProposeAPIClient.Page<HashedPropose>
}

/// ProposeController用のAPIクライアント（新バックエンドAPI仕様対応）
actor ProposeAPIClient: ProposeAPIClientProtocol {
    private let baseURL: URL
    private let session: URLSession

    /// ISO8601フォーマッター（インスタンス生成が重いためstatic letで共有）
    static let iso8601Formatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    /// ISO8601フォーマッター（マイクロ秒なしのフォールバック用）
    static let iso8601FormatterBasic: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    /// イニシャライザ
    /// - Parameters:
    ///   - baseURL: サーバーのベースURL（例: "https://api.example.com"）
    ///   - session: カスタムURLSession（デフォルトは.shared）
    init(baseURL: URL, session: URLSession = .shared) {
        self.baseURL = baseURL.appendingPathComponent("v1")
        self.session = session
    }

    // MARK: - DTOs (Data Transfer Objects)

    /// 提案作成時の入力データ（POST /v1/proposes）
    struct CreateProposeInput: Codable {
        /// ProposeのUUID文字列
        let proposeId: String
        /// SHA256ハッシュ（Base64）
        let contentHash: String
        /// CreatorのBase64 x963形式の公開鍵
        let creatorPublicKey: String
        /// Creatorの署名（Base64 DER）
        let creatorSignature: String
        /// Counterpartyの公開鍵リスト
        let counterpartyPublicKeys: [String]
        /// 作成日時（ISO8601）
        let createdAt: String
    }

    /// Counterpartyが署名するときの入力データ（PATCH /v1/proposes/:id/sign）
    struct SignInput: Codable {
        /// 署名者の公開鍵（Base64 x963）
        let signerPublicKey: String
        /// 署名データ（Base64 DER）
        let signature: String
        /// Proposeの作成日時（ISO8601、ProposeのcreatedAtと完全一致が必要）
        let createdAt: String
    }

    /// dissolve / honor / part 共通の入力データ
    struct TransitionInput: Codable {
        /// 操作者の公開鍵（Base64 x963）
        let publicKey: String
        /// 署名データ（Base64 DER）
        let signature: String
        /// タイムスタンプ（ISO8601）
        let timestamp: String
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

    /// 新しい提案を作成（POST /v1/proposes）
    /// - Parameter input: 提案の入力データ
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

    /// Counterpartyが署名（PATCH /v1/proposes/:id/sign）
    /// - Parameters:
    ///   - proposeID: 対象ProposeのUUID
    ///   - input: 署名入力データ
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

    /// Proposeをdissolve（DELETE /v1/proposes/:id）
    /// - Parameters:
    ///   - proposeID: 対象ProposeのUUID
    ///   - input: トランジション入力データ（署名必須）
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

    /// Proposeをhonor（PATCH /v1/proposes/:id/honor）
    /// - Parameters:
    ///   - proposeID: 対象ProposeのUUID
    ///   - input: トランジション入力データ（署名必須）
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

    /// Proposeをpart（PATCH /v1/proposes/:id/part）
    /// - Parameters:
    ///   - proposeID: 対象ProposeのUUID
    ///   - input: トランジション入力データ（署名必須）
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

    /// 指定したUUIDの提案詳細を取得（GET /v1/proposes/:id）
    /// - Parameter proposeID: 提案のUUID
    /// - Returns: サーバーのProposeレスポンス
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
        // ISO8601（マイクロ秒あり・なし両対応）のカスタムデコード
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
                debugDescription: "ISO8601日付のパースに失敗: \(dateString)"
            )
        }

        return try decoder.decode(HashedPropose.self, from: data)
    }

    /// 公開鍵・ステータスで提案一覧を取得（GET /v1/proposes）
    /// - Parameters:
    ///   - publicKey: 署名者の公開鍵
    ///   - status: フィルタするステータス（nil = フィルタなし）
    ///   - page: ページ番号（デフォルト: 1）
    ///   - per: 1ページあたりの件数（デフォルト: 10）
    /// - Returns: ページネーション結果
    /// - Throws: APIError
    func listProposes(publicKey: String, status: String? = nil, page: Int = 1, per: Int = 10) async throws -> Page<HashedPropose> {
        var components = URLComponents(url: baseURL.appendingPathComponent("proposes"), resolvingAgainstBaseURL: true)

        // percentEncodedQueryItems で手動エンコード
        let encodedPublicKey = publicKey
            .addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? publicKey

        var queryItems = [
            URLQueryItem(name: "publicKey", value: encodedPublicKey),
            URLQueryItem(name: "page", value: String(page)),
            URLQueryItem(name: "per", value: String(per))
        ]

        // statusフィルタが指定されている場合のみ追加
        if let status = status {
            queryItems.append(URLQueryItem(name: "status", value: status))
        }

        components?.percentEncodedQueryItems = queryItems

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
        // ISO8601（マイクロ秒あり・なし両対応）のカスタムデコード
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
                debugDescription: "ISO8601日付のパースに失敗: \(dateString)"
            )
        }

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
