//
//  SendLocalSignaturesToServerUseCase.swift
//  Wevo
//
//  Created on 3/11/26.
//

import Foundation
import os

protocol SendLocalSignaturesToServerUseCase {
    /// Send the local Counterparty signature to the server
    /// - Parameters:
    ///   - propose: The target Propose
    ///   - identityPublicKey: Operator's public key (only Counterparty can send)
    ///   - serverURL: Server URL
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

        // Only Counterparty can send Sign
        guard identityPublicKey == propose.counterpartyPublicKey else {
            Logger.propose.info("Not the Counterparty; skipping signature send")
            return
        }

        // Only send when counterpartySignSignature exists
        guard let counterpartySignSignature = propose.counterpartySignSignature else {
            throw SendLocalSignaturesToServerUseCaseError.noSignatureFound
        }

        guard let signTimestamp = propose.counterpartySignTimestamp else {
            throw SendLocalSignaturesToServerUseCaseError.noSignatureFound
        }

        let input = ProposeAPIClient.SignInput(
            signerPublicKey: identityPublicKey,
            signature: counterpartySignSignature,
            timestamp: signTimestamp
        )

        let client = apiClient ?? ProposeAPIClient(baseURL: baseURL)
        try await client.signPropose(proposeID: propose.id, input: input)

        Logger.propose.info("Sent Counterparty signature to server: \(propose.id, privacy: .private)")
    }
}
