//
//  SendLocalSignaturesToServerUseCase.swift
//  Wevo
//
//  Created on 3/11/26.
//

import Foundation

protocol SendLocalSignaturesToServerUseCase {
    /// ローカルのCounterparty署名をサーバーに送信する
    /// - Parameters:
    ///   - propose: 対象Propose
    ///   - identityPublicKey: 操作者の公開鍵（Counterpartyのみ送信可能）
    ///   - serverURL: サーバーのURL
    func execute(propose: Propose, identityPublicKey: String, serverURL: String) async throws
}

enum SendLocalSignaturesToServerUseCaseError: Error {
    case invalidServerURL
    case noSignatureFound
}

struct SendLocalSignaturesToServerUseCaseImpl {
    let apiClient: ProposeAPIClientProtocol?

    init(apiClient: ProposeAPIClientProtocol? = nil) {
        self.apiClient = apiClient
    }
}

extension SendLocalSignaturesToServerUseCaseImpl: SendLocalSignaturesToServerUseCase {
    func execute(propose: Propose, identityPublicKey: String, serverURL: String) async throws {
        guard let baseURL = URL(string: serverURL) else {
            throw SendLocalSignaturesToServerUseCaseError.invalidServerURL
        }

        // CounterpartyのみがSign送信できる
        guard identityPublicKey == propose.counterpartyPublicKey else {
            print("ℹ️ Counterpartyではないため、署名送信をスキップします")
            return
        }

        // counterpartySignSignatureがある場合のみ送信
        guard let counterpartySignSignature = propose.counterpartySignSignature else {
            throw SendLocalSignaturesToServerUseCaseError.noSignatureFound
        }

        // 署名メッセージを構築（sign: proposeId + contentHash + signerPublicKey + ISO8601(propose.createdAt)）
        let iso8601String = ProposeAPIClient.iso8601Formatter.string(from: propose.createdAt)

        let input = ProposeAPIClient.SignInput(
            signerPublicKey: identityPublicKey,
            signature: counterpartySignSignature,
            createdAt: iso8601String
        )

        let client = apiClient ?? ProposeAPIClient(baseURL: baseURL)
        try await client.signPropose(proposeID: propose.id, input: input)

        print("✅ Counterparty署名をサーバーに送信しました: \(propose.id)")
    }
}
