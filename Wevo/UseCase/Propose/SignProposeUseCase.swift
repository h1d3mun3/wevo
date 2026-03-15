//
//  SignProposeUseCase.swift
//  Wevo
//
//  Created by hidemune on 3/9/26.
//

import Foundation

enum SignProposeUseCaseError: Error {
    case failedToSavePropose
    /// The identity attempting to sign is not the Counterparty
    case notCounterparty
}

protocol SignProposeUseCase {
    func execute(to proposeID: UUID, signIdentityID: UUID) async throws
}

struct SignProposeUseCaseImpl {
    let keychainRepository: KeychainRepository
    let proposeRepository: ProposeRepository

    init(keychainRepository: KeychainRepository, proposeRepository: ProposeRepository) {
        self.keychainRepository = keychainRepository
        self.proposeRepository = proposeRepository
    }
}

extension SignProposeUseCaseImpl: SignProposeUseCase {
    func execute(to proposeID: UUID, signIdentityID: UUID) async throws {
        let identity = try keychainRepository.getIdentity(id: signIdentityID)
        let propose = try proposeRepository.fetch(by: proposeID)

        // Only Counterparty can sign
        guard identity.publicKey == propose.counterpartyPublicKey else {
            print("⚠️ Signer is not the Counterparty: \(identity.publicKey)")
            throw SignProposeUseCaseError.notCounterparty
        }

        // Build signature message (sign: proposeId + contentHash + signerPublicKey + ISO8601(propose.createdAt))
        let iso8601String = ProposeAPIClient.iso8601Formatter.string(from: propose.createdAt)
        let signatureMessage = propose.id.uuidString + propose.payloadHash + identity.publicKey + iso8601String

        // Sign
        let signatureData = try keychainRepository.signMessage(
            signatureMessage,
            withIdentityId: identity.id
        )

        // Update Propose with counterpartySignSignature set
        let updatedPropose = Propose(
            id: propose.id,
            spaceID: propose.spaceID,
            message: propose.message,
            creatorPublicKey: propose.creatorPublicKey,
            creatorSignature: propose.creatorSignature,
            counterpartyPublicKey: propose.counterpartyPublicKey,
            counterpartySignSignature: signatureData,
            createdAt: propose.createdAt,
            updatedAt: Date()
        )

        // Save locally
        do {
            try proposeRepository.update(updatedPropose)
            print("✅ Saved Counterparty signature locally: \(propose.id)")
        } catch {
            print("❌ Failed to update Propose: \(error)")
            throw SignProposeUseCaseError.failedToSavePropose
        }

        // API submission (only a warning if it fails since already saved locally)
        // API submission is handled by SendLocalSignaturesToServerUseCase
        print("ℹ️ Please use SendLocalSignaturesToServerUseCase to submit to the API")
    }
}
