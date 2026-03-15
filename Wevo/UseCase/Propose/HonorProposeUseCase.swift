//
//  HonorProposeUseCase.swift
//  Wevo
//
//  Created on 3/15/26.
//

import Foundation

protocol HonorProposeUseCase {
    func execute(propose: Propose, identityID: UUID, serverURL: String) async throws
}

enum HonorProposeUseCaseError: Error {
    case invalidServerURL
}

struct HonorProposeUseCaseImpl {
    let keychainRepository: KeychainRepository
    let apiClient: ProposeAPIClientProtocol?

    init(keychainRepository: KeychainRepository, apiClient: ProposeAPIClientProtocol? = nil) {
        self.keychainRepository = keychainRepository
        self.apiClient = apiClient
    }
}

extension HonorProposeUseCaseImpl: HonorProposeUseCase {
    func execute(propose: Propose, identityID: UUID, serverURL: String) async throws {
        guard let baseURL = URL(string: serverURL),
              baseURL.scheme == "https" || baseURL.scheme == "http" else {
            throw HonorProposeUseCaseError.invalidServerURL
        }

        let identity = try keychainRepository.getIdentity(id: identityID)
        let timestamp = ProposeAPIClient.iso8601Formatter.string(from: Date())

        // Signature message: "honored." + proposeId + contentHash + timestamp
        let message = "honored." + propose.id.uuidString + propose.payloadHash + timestamp
        let signature = try keychainRepository.signMessage(message, withIdentityId: identity.id)

        let input = ProposeAPIClient.TransitionInput(
            publicKey: identity.publicKey,
            signature: signature,
            timestamp: timestamp
        )

        let client = apiClient ?? ProposeAPIClient(baseURL: baseURL)
        try await client.honorPropose(proposeID: propose.id, input: input)
        print("✅ Sent Honor to server: \(propose.id)")
    }
}
