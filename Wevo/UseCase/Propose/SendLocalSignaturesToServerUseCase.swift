//
//  SendLocalSignaturesToServerUseCase.swift
//  Wevo
//
//  Created on 3/11/26.
//

import Foundation

protocol SendLocalSignaturesToServerUseCase {
    func execute(propose: Propose, serverURL: String) async throws
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
    func execute(propose: Propose, serverURL: String) async throws {
        guard let baseURL = URL(string: serverURL) else {
            throw SendLocalSignaturesToServerUseCaseError.invalidServerURL
        }

        guard let firstSignature = propose.signatures.first else {
            throw SendLocalSignaturesToServerUseCaseError.noSignatureFound
        }

        // 全ての署名をSignInputに変換
        let allSignInputs = propose.signatures.map { signature in
            ProposeAPIClient.SignInput(
                publicKey: signature.publicKey,
                signature: signature.signature
            )
        }

        let input = ProposeAPIClient.ProposeInput(
            id: propose.id,
            payloadHash: propose.payloadHash,
            publicKey: firstSignature.publicKey,
            signatures: allSignInputs
        )

        let client = apiClient ?? ProposeAPIClient(baseURL: baseURL)
        try await client.updatePropose(proposeID: input.id, input: input)

        print("✅ Sent local signature(s) to server (total: \(allSignInputs.count)): \(propose.id)")
    }
}
