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

        // Update Propose with counterpartySignSignature and signTimestamp set (preserve existing fields)
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
            dissolvedAt: propose.dissolvedAt,
            finalStatus: propose.finalStatus,
            createdAt: propose.createdAt,
            updatedAt: Date()
        )

        // Save locally
        do {
            try proposeRepository.update(updatedPropose)
            Logger.propose.info("Saved Counterparty signature locally: \(propose.id, privacy: .private)")
        } catch {
            Logger.propose.error("Failed to update Propose: \(error, privacy: .public)")
            throw SignProposeUseCaseError.failedToSavePropose
        }

        // API submission is handled by SendLocalSignaturesToServerUseCase
        Logger.propose.debug("Use SendLocalSignaturesToServerUseCase to submit to the API")
    }
}
