//
//  PartProposeUseCase.swift
//  Wevo
//
//  Created on 3/15/26.
//

import Foundation
import os

protocol PartProposeUseCase {
    func execute(propose: Propose, identityID: UUID, serverURL: String) async throws
}

enum PartProposeUseCaseError: Error {
    case invalidServerURL
}

struct PartProposeUseCaseImpl {
    let keychainRepository: KeychainRepository
    let proposeRepository: ProposeRepository
    let apiClient: ProposeAPIClientProtocol?

    init(keychainRepository: KeychainRepository, proposeRepository: ProposeRepository, apiClient: ProposeAPIClientProtocol? = nil) {
        self.keychainRepository = keychainRepository
        self.proposeRepository = proposeRepository
        self.apiClient = apiClient
    }
}

extension PartProposeUseCaseImpl: PartProposeUseCase {
    func execute(propose: Propose, identityID: UUID, serverURL: String) async throws {
        guard let baseURL = URL(string: serverURL),
              baseURL.scheme == "https" || baseURL.scheme == "http" else {
            throw PartProposeUseCaseError.invalidServerURL
        }

        let identity = try keychainRepository.getIdentity(id: identityID)
        let timestamp = ProposeAPIClient.iso8601Formatter.string(from: Date())

        // Signature message (v1): "parted." + proposeId + contentHash + signerPublicKey + timestamp
        let message = "parted." + propose.id.uuidString + propose.payloadHash + identity.publicKey + timestamp
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
            counterpartyHonorSignature: propose.counterpartyHonorSignature,
            counterpartyHonorTimestamp: propose.counterpartyHonorTimestamp,
            counterpartyPartSignature: isCreator ? propose.counterpartyPartSignature : signature,
            counterpartyPartTimestamp: isCreator ? propose.counterpartyPartTimestamp : timestamp,
            creatorHonorSignature: propose.creatorHonorSignature,
            creatorHonorTimestamp: propose.creatorHonorTimestamp,
            creatorPartSignature: isCreator ? signature : propose.creatorPartSignature,
            creatorPartTimestamp: isCreator ? timestamp : propose.creatorPartTimestamp,
            dissolvedAt: propose.dissolvedAt,
            finalStatus: propose.finalStatus,
            signatureVersion: propose.signatureVersion,
            createdAt: propose.createdAt,
            updatedAt: Date()
        )
        try proposeRepository.update(updatedPropose)
        Logger.propose.info("Saved Part signature locally: \(propose.id, privacy: .private)")

        // Send to server
        let input = ProposeAPIClient.TransitionInput(
            publicKey: identity.publicKey,
            signature: signature,
            timestamp: timestamp
        )

        let client = apiClient ?? ProposeAPIClient(baseURL: baseURL)
        try await client.partPropose(proposeID: propose.id, input: input)
        Logger.propose.info("Sent Part to server: \(propose.id, privacy: .private)")
    }
}
