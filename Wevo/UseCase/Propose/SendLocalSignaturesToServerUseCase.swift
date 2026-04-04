//
//  SendLocalSignaturesToServerUseCase.swift
//  Wevo
//
//  Created on 3/11/26.
//

import Foundation
import os

protocol SendLocalSignaturesToServerUseCase {
    /// Send the locally stored signature for the given identity to the server.
    /// Covers all operations: sign, honor, part, dissolve (creator and counterparty).
    /// - Parameters:
    ///   - propose: The target Propose
    ///   - identityPublicKey: Public key of the acting identity
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

        let client = apiClient ?? ProposeAPIClient(baseURL: baseURL)
        let isCreator = identityPublicKey == propose.creatorPublicKey
        let isCounterparty = identityPublicKey == propose.counterpartyPublicKey

        if isCreator {
            if let sig = propose.creatorHonorSignature, let ts = propose.creatorHonorTimestamp {
                let input = ProposeAPIClient.TransitionInput(publicKey: identityPublicKey, signature: sig, timestamp: ts)
                try await client.honorPropose(proposeID: propose.id, input: input)
                Logger.propose.info("Resent creator honor signature to server: \(propose.id, privacy: .private)")
            } else if let sig = propose.creatorPartSignature, let ts = propose.creatorPartTimestamp {
                let input = ProposeAPIClient.TransitionInput(publicKey: identityPublicKey, signature: sig, timestamp: ts)
                try await client.partPropose(proposeID: propose.id, input: input)
                Logger.propose.info("Resent creator part signature to server: \(propose.id, privacy: .private)")
<<<<<<< HEAD
            } else if let sig = propose.creatorDissolveSignature, let ts = propose.creatorDissolveTimestamp {
=======
            } else if let sig = propose.creatorDissolveSignature, let ts = propose.dissolvedAt {
>>>>>>> main
                let input = ProposeAPIClient.TransitionInput(publicKey: identityPublicKey, signature: sig, timestamp: ts)
                try await client.dissolvePropose(proposeID: propose.id, input: input)
                Logger.propose.info("Resent creator dissolve signature to server: \(propose.id, privacy: .private)")
            } else {
                throw SendLocalSignaturesToServerUseCaseError.noSignatureFound
            }
        } else if isCounterparty {
            if let sig = propose.counterpartySignSignature, let ts = propose.counterpartySignTimestamp {
                let input = ProposeAPIClient.SignInput(signerPublicKey: identityPublicKey, signature: sig, timestamp: ts)
                try await client.signPropose(proposeID: propose.id, input: input)
                Logger.propose.info("Resent counterparty sign signature to server: \(propose.id, privacy: .private)")
            } else if let sig = propose.counterpartyHonorSignature, let ts = propose.counterpartyHonorTimestamp {
                let input = ProposeAPIClient.TransitionInput(publicKey: identityPublicKey, signature: sig, timestamp: ts)
                try await client.honorPropose(proposeID: propose.id, input: input)
                Logger.propose.info("Resent counterparty honor signature to server: \(propose.id, privacy: .private)")
            } else if let sig = propose.counterpartyPartSignature, let ts = propose.counterpartyPartTimestamp {
                let input = ProposeAPIClient.TransitionInput(publicKey: identityPublicKey, signature: sig, timestamp: ts)
                try await client.partPropose(proposeID: propose.id, input: input)
                Logger.propose.info("Resent counterparty part signature to server: \(propose.id, privacy: .private)")
<<<<<<< HEAD
            } else if let sig = propose.counterpartyDissolveSignature, let ts = propose.counterpartyDissolveTimestamp {
=======
            } else if let sig = propose.counterpartyDissolveSignature, let ts = propose.dissolvedAt {
>>>>>>> main
                let input = ProposeAPIClient.TransitionInput(publicKey: identityPublicKey, signature: sig, timestamp: ts)
                try await client.dissolvePropose(proposeID: propose.id, input: input)
                Logger.propose.info("Resent counterparty dissolve signature to server: \(propose.id, privacy: .private)")
            } else {
                throw SendLocalSignaturesToServerUseCaseError.noSignatureFound
            }
        } else {
            Logger.propose.info("Not a participant; skipping signature send")
        }
    }
}
