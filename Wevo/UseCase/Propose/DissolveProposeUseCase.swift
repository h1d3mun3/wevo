//
//  DissolveProposeUseCase.swift
//  Wevo
//
//  Created on 3/15/26.
//

import Foundation
import os

protocol DissolveProposeUseCase {
    func execute(propose: Propose, identityID: UUID, serverURLs: [String]) async throws
}

enum DissolveProposeUseCaseError: Error {
    case invalidServerURL
    /// The identity is not a participant (neither creator nor counterparty)
    case notParticipant
    case proposeStatusIsNotProposed
}

struct DissolveProposeUseCaseImpl {
    let keychainRepository: KeychainRepository
    let proposeRepository: ProposeRepository
    let apiClient: ProposeAPIClientProtocol?

    init(keychainRepository: KeychainRepository, proposeRepository: ProposeRepository, apiClient: ProposeAPIClientProtocol? = nil) {
        self.keychainRepository = keychainRepository
        self.proposeRepository = proposeRepository
        self.apiClient = apiClient
    }
}

extension DissolveProposeUseCaseImpl: DissolveProposeUseCase {
    func execute(propose: Propose, identityID: UUID, serverURLs: [String]) async throws {
        guard serverURLs.contains(where: { URL(string: $0)?.scheme == "https" || URL(string: $0)?.scheme == "http" }) else {
            throw DissolveProposeUseCaseError.invalidServerURL
        }

        guard propose.localStatus == .proposed else {
            throw DissolveProposeUseCaseError.proposeStatusIsNotProposed
        }

        let identity = try keychainRepository.getIdentity(id: identityID)

        // Only creator or counterparty can dissolve
        let isCreator = identity.publicKey == propose.creatorPublicKey
        let isParticipant = isCreator || identity.publicKey == propose.counterpartyPublicKey
        guard isParticipant else {
            throw DissolveProposeUseCaseError.notParticipant
        }

        let timestamp = ProposeAPIClient.iso8601Formatter.string(from: Date())

        // Signature message (v1): "dissolved." + proposeId + contentHash + signerPublicKey + timestamp
        let message = "dissolved." + propose.id.uuidString + propose.payloadHash + identity.publicKey + timestamp
        let signature = try keychainRepository.signMessage(message, withIdentityId: identity.id)

        // Save locally first
        let updatedPropose = Propose(
            id: propose.id,
            spaceID: propose.spaceID,
            message: propose.message,
            creatorPublicKey: propose.creatorPublicKey,
            creatorSignature: propose.creatorSignature,
            counterpartyPublicKey: propose.counterpartyPublicKey,
            counterpartySignSignature: propose.counterpartySignSignature,
            counterpartySignTimestamp: propose.counterpartySignTimestamp,
            counterpartyHonorSignature: propose.counterpartyHonorSignature,
            counterpartyHonorTimestamp: propose.counterpartyHonorTimestamp,
            counterpartyPartSignature: propose.counterpartyPartSignature,
            counterpartyPartTimestamp: propose.counterpartyPartTimestamp,
            creatorHonorSignature: propose.creatorHonorSignature,
            creatorHonorTimestamp: propose.creatorHonorTimestamp,
            creatorPartSignature: propose.creatorPartSignature,
            creatorPartTimestamp: propose.creatorPartTimestamp,
            creatorDissolveSignature: isCreator ? signature : propose.creatorDissolveSignature,
            creatorDissolveTimestamp: isCreator ? timestamp : propose.creatorDissolveTimestamp,
            counterpartyDissolveSignature: isCreator ? propose.counterpartyDissolveSignature : signature,
            counterpartyDissolveTimestamp: isCreator ? propose.counterpartyDissolveTimestamp : timestamp,
            signatureVersion: propose.signatureVersion,
            createdAt: propose.createdAt,
            updatedAt: Date()
        )
        try proposeRepository.update(updatedPropose)
        Logger.propose.info("Saved Dissolve signature locally: \(propose.id, privacy: .private)")

        // Send to server
        let input = ProposeAPIClient.TransitionInput(
            publicKey: identity.publicKey,
            signature: signature,
            timestamp: timestamp
        )

        let client = apiClient ?? ResilientProposeAPIClient(urls: serverURLs)
        try await client.dissolvePropose(proposeID: propose.id, input: input)
        Logger.propose.info("Sent Dissolve to server: \(propose.id, privacy: .private)")
    }
}
