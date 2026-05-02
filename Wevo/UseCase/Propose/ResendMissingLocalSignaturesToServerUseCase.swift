//
//  ResendMissingLocalSignaturesToServerUseCase.swift
//  Wevo
//
//  Created on 3/11/26.
//

import Foundation
import os

protocol ResendMissingLocalSignaturesToServerUseCase {
    /// Compares local signatures against the current server state and sends all missing ones.
    /// Covers all operations: sign, honor, part, dissolve (creator and counterparty).
    /// - Parameters:
    ///   - propose: The target Propose
    ///   - identityPublicKey: Public key of the acting identity
    ///   - serverURLs: Server node URLs
    func execute(propose: Propose, identityPublicKey: String, serverURLs: [String]) async throws
}

enum ResendMissingLocalSignaturesToServerUseCaseError: Error {
    case invalidServerURL
    case noSignatureFound
}

struct ResendMissingLocalSignaturesToServerUseCaseImpl {
    let apiClient: ProposeAPIClientProtocol?

    init(apiClient: ProposeAPIClientProtocol? = nil) {
        self.apiClient = apiClient
    }
}

extension ResendMissingLocalSignaturesToServerUseCaseImpl: ResendMissingLocalSignaturesToServerUseCase {
    func execute(propose: Propose, identityPublicKey: String, serverURLs: [String]) async throws {
        guard !serverURLs.isEmpty else {
            throw ResendMissingLocalSignaturesToServerUseCaseError.invalidServerURL
        }

        let client = apiClient ?? ResilientProposeAPIClient(urls: serverURLs)
        let isCreator = identityPublicKey == propose.creatorPublicKey
        let isCounterparty = identityPublicKey == propose.counterpartyPublicKey

        // Fetch current server state to determine which signatures are actually missing
        let serverPropose = try await client.getPropose(proposeID: propose.id)

        var sent = false

        if isCreator {
            // Order: Dissolve -> Part -> Honor
            if let sig = propose.creatorDissolveSignature, let ts = propose.creatorDissolveTimestamp,
               serverPropose.creatorDissolveSignature == nil {
                let input = ProposeAPIClient.TransitionInput(publicKey: identityPublicKey, signature: sig, timestamp: ts)
                try await client.dissolvePropose(proposeID: propose.id, input: input)
                Logger.propose.info("Resent creator dissolve signature to server: \(propose.id, privacy: .private)")
                sent = true
            }
            if let sig = propose.creatorPartSignature, let ts = propose.creatorPartTimestamp,
               serverPropose.partCreatorSignature == nil {
                let input = ProposeAPIClient.TransitionInput(publicKey: identityPublicKey, signature: sig, timestamp: ts)
                try await client.partPropose(proposeID: propose.id, input: input)
                Logger.propose.info("Resent creator part signature to server: \(propose.id, privacy: .private)")
                sent = true
            }
            if let sig = propose.creatorHonorSignature, let ts = propose.creatorHonorTimestamp,
               serverPropose.honorCreatorSignature == nil {
                let input = ProposeAPIClient.TransitionInput(publicKey: identityPublicKey, signature: sig, timestamp: ts)
                try await client.honorPropose(proposeID: propose.id, input: input)
                Logger.propose.info("Resent creator honor signature to server: \(propose.id, privacy: .private)")
                sent = true
            }
        } else if isCounterparty {
            let serverCounterparty = serverPropose.counterparties.first(where: { $0.publicKey == identityPublicKey })

            // Order: Dissolve -> Sign -> Part -> Honor
            if let sig = propose.counterpartyDissolveSignature, let ts = propose.counterpartyDissolveTimestamp,
               serverCounterparty?.dissolveSignature == nil {
                let input = ProposeAPIClient.TransitionInput(publicKey: identityPublicKey, signature: sig, timestamp: ts)
                try await client.dissolvePropose(proposeID: propose.id, input: input)
                Logger.propose.info("Resent counterparty dissolve signature to server: \(propose.id, privacy: .private)")
                sent = true
            }
            if let sig = propose.counterpartySignSignature, let ts = propose.counterpartySignTimestamp,
               serverCounterparty?.signSignature == nil {
                let input = ProposeAPIClient.SignInput(signerPublicKey: identityPublicKey, signature: sig, timestamp: ts)
                try await client.signPropose(proposeID: propose.id, input: input)
                Logger.propose.info("Resent counterparty sign signature to server: \(propose.id, privacy: .private)")
                sent = true
            }
            if let sig = propose.counterpartyPartSignature, let ts = propose.counterpartyPartTimestamp,
               serverCounterparty?.partSignature == nil {
                let input = ProposeAPIClient.TransitionInput(publicKey: identityPublicKey, signature: sig, timestamp: ts)
                try await client.partPropose(proposeID: propose.id, input: input)
                Logger.propose.info("Resent counterparty part signature to server: \(propose.id, privacy: .private)")
                sent = true
            }
            if let sig = propose.counterpartyHonorSignature, let ts = propose.counterpartyHonorTimestamp,
               serverCounterparty?.honorSignature == nil {
                let input = ProposeAPIClient.TransitionInput(publicKey: identityPublicKey, signature: sig, timestamp: ts)
                try await client.honorPropose(proposeID: propose.id, input: input)
                Logger.propose.info("Resent counterparty honor signature to server: \(propose.id, privacy: .private)")
                sent = true
            }
        } else {
            Logger.propose.info("Not a participant; skipping signature send")
            return
        }

        if !sent {
            throw ResendMissingLocalSignaturesToServerUseCaseError.noSignatureFound
        }
    }
}
