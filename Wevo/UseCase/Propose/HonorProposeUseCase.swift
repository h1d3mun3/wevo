//
//  HonorProposeUseCase.swift
//  Wevo
//
//  Created on 3/15/26.
//

import Foundation
import os

protocol HonorProposeUseCase {
    func execute(propose: Propose, identityID: UUID, serverURLs: [String]) async throws
}

enum HonorProposeUseCaseError: Error {
    case invalidServerURL
    case proposeStatusIsNotSigned
}

struct HonorProposeUseCaseImpl {
    let keychainRepository: KeychainRepository
    let proposeRepository: ProposeRepository
    let apiClient: ProposeAPIClientProtocol?

    init(keychainRepository: KeychainRepository, proposeRepository: ProposeRepository, apiClient: ProposeAPIClientProtocol? = nil) {
        self.keychainRepository = keychainRepository
        self.proposeRepository = proposeRepository
        self.apiClient = apiClient
    }
}

extension HonorProposeUseCaseImpl: HonorProposeUseCase {
    func execute(propose: Propose, identityID: UUID, serverURLs: [String]) async throws {
        guard serverURLs.contains(where: { URL(string: $0)?.scheme == "https" || URL(string: $0)?.scheme == "http" }) else {
            throw HonorProposeUseCaseError.invalidServerURL
        }

        guard propose.localStatus == .signed else {
            throw HonorProposeUseCaseError.proposeStatusIsNotSigned
        }

        let identity = try keychainRepository.getIdentity(id: identityID)
        let timestamp = ProposeAPIClient.iso8601Formatter.string(from: Date())

        // Signature message (v1): "honored." + proposeId + contentHash + signerPublicKey + timestamp
        let message = "honored." + propose.id.uuidString + propose.payloadHash + identity.publicKey + timestamp
        let signature = try keychainRepository.signMessage(message, withIdentityId: identity.id)

        // Save locally first
        let isCreator = identity.publicKey == propose.creatorPublicKey
        let updatedPropose = Propose(
            id: propose.id,
            spaceID: propose.spaceID,
            message: propose.message,
            creatorPublicKey: propose.creatorPublicKey,
            creatorSignature: propose.creatorSignature,
            counterpartyPublicKey: propose.counterpartyPublicKey,
            counterpartySignSignature: propose.counterpartySignSignature,
            counterpartySignTimestamp: propose.counterpartySignTimestamp,
            counterpartyHonorSignature: isCreator ? propose.counterpartyHonorSignature : signature,
            counterpartyHonorTimestamp: isCreator ? propose.counterpartyHonorTimestamp : timestamp,
            counterpartyPartSignature: propose.counterpartyPartSignature,
            counterpartyPartTimestamp: propose.counterpartyPartTimestamp,
            creatorHonorSignature: isCreator ? signature : propose.creatorHonorSignature,
            creatorHonorTimestamp: isCreator ? timestamp : propose.creatorHonorTimestamp,
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
        try proposeRepository.update(updatedPropose)
        Logger.propose.info("Saved Honor signature locally: \(propose.id, privacy: .private)")

        // Send to server
        let input = ProposeAPIClient.TransitionInput(
            publicKey: identity.publicKey,
            signature: signature,
            timestamp: timestamp
        )

        let client = apiClient ?? ResilientProposeAPIClient(urls: serverURLs)
        try await client.honorPropose(proposeID: propose.id, input: input)
        Logger.propose.info("Sent Honor to server: \(propose.id, privacy: .private)")
    }
}
