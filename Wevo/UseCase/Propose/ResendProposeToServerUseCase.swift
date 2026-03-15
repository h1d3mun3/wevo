//
//  ResendProposeToServerUseCase.swift
//  Wevo
//
//  Created on 3/11/26.
//

import Foundation

protocol ResendProposeToServerUseCase {
    func execute(propose: Propose, serverURL: String) async throws
}

enum ResendProposeToServerUseCaseError: Error {
    case invalidServerURL
    case noSignatureFound
}

struct ResendProposeToServerUseCaseImpl {
    let apiClient: ProposeAPIClientProtocol?

    init(apiClient: ProposeAPIClientProtocol? = nil) {
        self.apiClient = apiClient
    }
}

extension ResendProposeToServerUseCaseImpl: ResendProposeToServerUseCase {
    func execute(propose: Propose, serverURL: String) async throws {
        guard let baseURL = URL(string: serverURL) else {
            throw ResendProposeToServerUseCaseError.invalidServerURL
        }

        // CreatorSignatureが存在することを確認
        guard !propose.creatorSignature.isEmpty else {
            throw ResendProposeToServerUseCaseError.noSignatureFound
        }

        // 作成日時のISO8601文字列
        let iso8601String = ProposeAPIClient.iso8601Formatter.string(from: propose.createdAt)

        // CreateProposeInputを使ってPOST /proposesに再送信
        let input = ProposeAPIClient.CreateProposeInput(
            proposeId: propose.id.uuidString,
            contentHash: propose.payloadHash,
            creatorPublicKey: propose.creatorPublicKey,
            creatorSignature: propose.creatorSignature,
            counterpartyPublicKeys: [propose.counterpartyPublicKey],
            createdAt: iso8601String
        )

        let client = apiClient ?? ProposeAPIClient(baseURL: baseURL)
        try await client.createPropose(input: input)

        print("✅ Proposeをサーバーに再送信しました: \(propose.id)")
    }
}
