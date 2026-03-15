//
//  SignProposeServerOnlyUseCase.swift
//  Wevo
//
//  Created on 3/15/26.
//

import Foundation

protocol SignProposeServerOnlyUseCase {
    /// Sign a Propose and send the signature to the server only (does not save locally)
    /// - Returns: The counterparty signature string (to be reflected locally after user confirmation)
    func execute(propose: Propose, identityID: UUID, serverURL: String) async throws -> String
}

enum SignProposeServerOnlyUseCaseError: Error {
    case invalidServerURL
    case notCounterparty
}

struct SignProposeServerOnlyUseCaseImpl {
    let keychainRepository: KeychainRepository
    let apiClient: ProposeAPIClientProtocol?

    init(keychainRepository: KeychainRepository, apiClient: ProposeAPIClientProtocol? = nil) {
        self.keychainRepository = keychainRepository
        self.apiClient = apiClient
    }
}

extension SignProposeServerOnlyUseCaseImpl: SignProposeServerOnlyUseCase {
    func execute(propose: Propose, identityID: UUID, serverURL: String) async throws -> String {
        guard let baseURL = URL(string: serverURL),
              baseURL.scheme == "https" || baseURL.scheme == "http" else {
            throw SignProposeServerOnlyUseCaseError.invalidServerURL
        }

        let identity = try keychainRepository.getIdentity(id: identityID)

        guard identity.publicKey == propose.counterpartyPublicKey else {
            throw SignProposeServerOnlyUseCaseError.notCounterparty
        }

        let iso8601String = ProposeAPIClient.iso8601Formatter.string(from: propose.createdAt)
        let message = propose.id.uuidString + propose.payloadHash + identity.publicKey + iso8601String
        let signature = try keychainRepository.signMessage(message, withIdentityId: identity.id)

        let input = ProposeAPIClient.SignInput(
            signerPublicKey: identity.publicKey,
            signature: signature,
            createdAt: iso8601String
        )

        let client = apiClient ?? ProposeAPIClient(baseURL: baseURL)
        try await client.signPropose(proposeID: propose.id, input: input)

        print("✅ Sent Counterparty signature to server (pending local confirmation): \(propose.id)")
        return signature
    }
}
