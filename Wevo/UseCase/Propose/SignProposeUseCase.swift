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
    case invalidServerURL
    case proposeStatusIsNotProposed
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
    func execute(propose: Propose, identityID: UUID, serverURLs: [String]) async throws {
        guard serverURLs.contains(where: { URL(string: $0)?.scheme == "https" || URL(string: $0)?.scheme == "http" }) else {
            throw SignProposeUseCaseError.invalidServerURL
        }

        guard propose.localStatus == .proposed else {
            throw SignProposeUseCaseError.proposeStatusIsNotProposed
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

        // Send to server
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
