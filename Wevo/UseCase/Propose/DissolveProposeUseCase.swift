//
//  DissolveProposeUseCase.swift
//  Wevo
//
//  Created on 3/15/26.
//

import Foundation
import os

protocol DissolveProposeUseCase {
    func execute(propose: Propose, identityID: UUID, serverURL: String) async throws
}

enum DissolveProposeUseCaseError: Error {
    case invalidServerURL
    /// The identity is not a participant (neither creator nor counterparty)
    case notParticipant
}

struct DissolveProposeUseCaseImpl {
    let keychainRepository: KeychainRepository
    let apiClient: ProposeAPIClientProtocol?

    init(keychainRepository: KeychainRepository, apiClient: ProposeAPIClientProtocol? = nil) {
        self.keychainRepository = keychainRepository
        self.apiClient = apiClient
    }
}

extension DissolveProposeUseCaseImpl: DissolveProposeUseCase {
    func execute(propose: Propose, identityID: UUID, serverURL: String) async throws {
        guard let baseURL = URL(string: serverURL),
              baseURL.scheme == "https" || baseURL.scheme == "http" else {
            throw DissolveProposeUseCaseError.invalidServerURL
        }

        let identity = try keychainRepository.getIdentity(id: identityID)

        // Only creator or counterparty can dissolve
        let isParticipant = identity.publicKey == propose.creatorPublicKey
            || identity.publicKey == propose.counterpartyPublicKey
        guard isParticipant else {
            throw DissolveProposeUseCaseError.notParticipant
        }

        let timestamp = ProposeAPIClient.iso8601Formatter.string(from: Date())

        // Signature message: "dissolved." + proposeId + contentHash + timestamp
        let message = "dissolved." + propose.id.uuidString + propose.payloadHash + timestamp
        let signature = try keychainRepository.signMessage(message, withIdentityId: identity.id)

        let input = ProposeAPIClient.TransitionInput(
            publicKey: identity.publicKey,
            signature: signature,
            timestamp: timestamp
        )

        let client = apiClient ?? ProposeAPIClient(baseURL: baseURL)
        try await client.dissolvePropose(proposeID: propose.id, input: input)
        Logger.propose.info("Sent Dissolve to server: \(propose.id, privacy: .private)")
    }
}
