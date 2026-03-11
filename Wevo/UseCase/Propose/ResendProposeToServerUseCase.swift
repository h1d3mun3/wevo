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

        guard let firstSignature = propose.signatures.first else {
            throw ResendProposeToServerUseCaseError.noSignatureFound
        }

        let input = ProposeAPIClient.ProposeInput(
            id: propose.id,
            payloadHash: propose.payloadHash,
            publicKey: firstSignature.publicKey,
            signatures: propose.signatures.map {
                ProposeAPIClient.SignInput(publicKey: $0.publicKey, signature: $0.signature)
            }
        )

        let client = apiClient ?? ProposeAPIClient(baseURL: baseURL)
        try await client.createPropose(input: input)

        print("✅ Propose resent to server successfully: \(propose.id)")
    }
}
