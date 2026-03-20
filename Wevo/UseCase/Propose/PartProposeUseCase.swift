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
    let apiClient: ProposeAPIClientProtocol?

    init(keychainRepository: KeychainRepository, apiClient: ProposeAPIClientProtocol? = nil) {
        self.keychainRepository = keychainRepository
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
