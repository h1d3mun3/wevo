//
//  SignProposeUseCase.swift
//  Wevo
//
//  Created by hidemune on 3/9/26.
//

import Foundation
import os

enum SignProposeUseCaseError: Error {
    case failedToSavePropose
    /// The identity attempting to sign is not the Counterparty
    case notCounterparty
    case statusIsNotProposed
}

protocol SignProposeUseCase {
    func execute(propose: Propose, identityID: UUID, serverURLs: [String]) async throws
}

struct SignProposeUseCaseImpl {
    let keychainRepository: KeychainRepository
    let proposeRepository: ProposeRepository
    let apiClient: ProposeAPIClientProtocol?

    init(keychainRepository: KeychainRepository, proposeRepository: ProposeRepository, apiClient: ProposeAPIClientProtocol? = nil) {
        self.keychainRepository = keychainRepository
        self.proposeRepository = proposeRepository
        self.apiClient = apiClient
    }
}

extension SignProposeUseCaseImpl: SignProposeUseCase {
    func execute(propose input: Propose, identityID: UUID, serverURLs: [String]) async throws {
        // Re-fetch the latest persisted copy so a stale in-memory snapshot can never silently
        // overwrite newer signatures recorded after this row was seeded.
        let propose = (try? proposeRepository.fetch(by: input.id)) ?? input

        guard propose.localStatus == .proposed else {
            throw SignProposeUseCaseError.statusIsNotProposed
        }

        let identity = try keychainRepository.getIdentity(id: identityID)

        // Only Counterparty can sign
        guard identity.publicKey == propose.counterpartyPublicKey else {
            Logger.propose.warning("Signer is not the Counterparty")
            throw SignProposeUseCaseError.notCounterparty
        }

        // Build signature message (sign: "signed." + proposeId + contentHash + signerPublicKey + timestamp)
        let signTimestamp = ProposeAPIClient.iso8601Formatter.string(from: Date())
        let signatureMessage = "signed." + propose.id.uuidString + propose.payloadHash + identity.publicKey + signTimestamp

        // Sign
        let signatureData = try keychainRepository.signMessage(
            signatureMessage,
            withIdentityId: identity.id
        )

        // Save locally first
        let updatedPropose = Propose(
            id: propose.id,
            spaceID: propose.spaceID,
            message: propose.message,
            creatorPublicKey: propose.creatorPublicKey,
            creatorSignature: propose.creatorSignature,
            counterpartyPublicKey: propose.counterpartyPublicKey,
            counterpartySignSignature: signatureData,
            counterpartySignTimestamp: signTimestamp,
            counterpartyHonorSignature: propose.counterpartyHonorSignature,
            counterpartyHonorTimestamp: propose.counterpartyHonorTimestamp,
            counterpartyPartSignature: propose.counterpartyPartSignature,
            counterpartyPartTimestamp: propose.counterpartyPartTimestamp,
            creatorHonorSignature: propose.creatorHonorSignature,
            creatorHonorTimestamp: propose.creatorHonorTimestamp,
            creatorPartSignature: propose.creatorPartSignature,
            creatorPartTimestamp: propose.creatorPartTimestamp,
            creatorDissolveSignature: propose.creatorDissolveSignature,
            creatorDissolveTimestamp: propose.creatorDissolveTimestamp,
            counterpartyDissolveSignature: propose.counterpartyDissolveSignature,
            counterpartyDissolveTimestamp: propose.counterpartyDissolveTimestamp,
            signatureVersion: propose.signatureVersion,
            createdAt: propose.createdAt,
            updatedAt: Date()
        )

        do {
            try proposeRepository.update(updatedPropose)
            Logger.propose.info("Saved Counterparty signature locally: \(propose.id, privacy: .private)")
        } catch {
            Logger.propose.error("Failed to update Propose: \(error, privacy: .public)")
            throw SignProposeUseCaseError.failedToSavePropose
        }

        // Send to server if server URLs are configured
        guard serverURLs.hasUsableServerURL else {
            Logger.propose.info("Local-only mode: signed locally without server sync: \(propose.id, privacy: .private)")
            return
        }

        let input = ProposeAPIClient.SignInput(
            signerPublicKey: identity.publicKey,
            signature: signatureData,
            timestamp: signTimestamp
        )

        let client = apiClient ?? ResilientProposeAPIClient(urls: serverURLs)
        try await client.signPropose(proposeID: propose.id, input: input)
        Logger.propose.info("Sent Counterparty signature to server: \(propose.id, privacy: .private)")
    }
}
