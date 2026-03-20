//
//  CreateProposeUseCase.swift
//  Wevo
//
//  Created by hidemune on 3/9/26.
//

import Foundation
import CryptoKit
import os

protocol CreateProposeUseCase {
    func execute(identityID: UUID, spaceID: UUID, message: String, counterpartyPublicKey: String) async throws
}

struct CreateProposeUseCaseImpl {
    let keychainRepository: KeychainRepository
    let spaceRepository: SpaceRepository
    let proposeRepository: ProposeRepository

    init(keychainRepository: KeychainRepository, spaceRepository: SpaceRepository, proposeRepository: ProposeRepository) {
        self.keychainRepository = keychainRepository
        self.spaceRepository = spaceRepository
        self.proposeRepository = proposeRepository
    }
}

extension CreateProposeUseCaseImpl: CreateProposeUseCase {
    func execute(identityID: UUID, spaceID: UUID, message: String, counterpartyPublicKey: String) async throws {
        let trimmedMessage = message.trimmingCharacters(in: .whitespacesAndNewlines)

        let identity = try keychainRepository.getIdentity(id: identityID)
        let space = try spaceRepository.fetch(by: spaceID)

        // Generate ProposeID and creation timestamp
        let proposeID = UUID()
        let createdAt = Date()

        // Calculate contentHash (SHA256)
        let contentHash = trimmedMessage.sha256HashedString

        // Build signature message (v1: "proposed." + proposeId + contentHash + creatorPublicKey + counterpartyPublicKeys(sorted & joined) + createdAt)
        let iso8601String = ProposeAPIClient.iso8601Formatter.string(from: createdAt)
        let sortedCounterpartyKeys = [counterpartyPublicKey].sorted().joined()
        let signatureMessage = "proposed." + proposeID.uuidString + contentHash + identity.publicKey + sortedCounterpartyKeys + iso8601String

        // Creator signs
        let creatorSignature = try keychainRepository.signMessage(
            signatureMessage,
            withIdentityId: identity.id
        )

        // Create Propose entity (counterpartySignSignature initialized to nil, signatureVersion fixed to 1)
        let propose = Propose(
            id: proposeID,
            spaceID: spaceID,
            message: trimmedMessage,
            creatorPublicKey: identity.publicKey,
            creatorSignature: creatorSignature,
            counterpartyPublicKey: counterpartyPublicKey,
            counterpartySignSignature: nil,
            signatureVersion: 1,
            createdAt: createdAt,
            updatedAt: createdAt
        )

        // Save locally
        try proposeRepository.create(propose, spaceID: space.id)
        Logger.propose.info("Saved Propose locally: \(proposeID, privacy: .private)")
        Logger.propose.debug("Message: \(trimmedMessage, privacy: .private), contentHash: \(contentHash, privacy: .private)")

        // Send to API (only warn if it fails since it's already saved locally)
        guard let baseURL = URL(string: space.url) else {
            Logger.propose.warning("Invalid server URL: \(space.url, privacy: .private)")
            return
        }

        let input = ProposeAPIClient.CreateProposeInput(
            proposeId: proposeID.uuidString,
            contentHash: contentHash,
            creatorPublicKey: identity.publicKey,
            creatorSignature: creatorSignature,
            counterpartyPublicKeys: [counterpartyPublicKey],
            createdAt: iso8601String
        )

        do {
            let client = ProposeAPIClient(baseURL: baseURL)
            try await client.createPropose(input: input)
            Logger.propose.info("Sent Propose to API: \(proposeID, privacy: .private)")
        } catch {
            Logger.propose.warning("Failed to send to API (already saved locally): \(error, privacy: .public)")
        }
    }
}
