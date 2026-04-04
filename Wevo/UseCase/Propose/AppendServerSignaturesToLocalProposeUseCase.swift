//
//  AppendServerSignaturesToLocalProposeUseCase.swift
//  Wevo
//
//  Created by hidemune on 3/9/26.
//

import Foundation
import os

protocol AppendServerSignaturesToLocalProposeUseCase {
    /// Reflect server signatures and timestamps in the local Propose
    /// - Parameters:
    ///   - proposeID: ID of the target Propose
    ///   - serverPropose: Server's HashedPropose containing all signatures and timestamps
    func execute(proposeID: UUID, serverPropose: HashedPropose) throws
}

struct AppendServerSignaturesToLocalProposeUseCaseImpl {
    let proposeRepository: ProposeRepository

    init(proposeRepository: ProposeRepository) {
        self.proposeRepository = proposeRepository
    }
}

extension AppendServerSignaturesToLocalProposeUseCaseImpl: AppendServerSignaturesToLocalProposeUseCase {
    func execute(proposeID: UUID, serverPropose: HashedPropose) throws {
        let localPropose = try proposeRepository.fetch(by: proposeID)

        let counterparty = serverPropose.counterparties.first

        // Reflect all server-side signatures and timestamps into the local Propose
        let updatedPropose = Propose(
            id: localPropose.id,
            spaceID: localPropose.spaceID,
            message: localPropose.message,
            creatorPublicKey: localPropose.creatorPublicKey,
            creatorSignature: localPropose.creatorSignature,
            counterpartyPublicKey: localPropose.counterpartyPublicKey,
            counterpartySignSignature: counterparty?.signSignature ?? localPropose.counterpartySignSignature,
            counterpartySignTimestamp: counterparty?.signTimestamp ?? localPropose.counterpartySignTimestamp,
            counterpartyHonorSignature: counterparty?.honorSignature ?? localPropose.counterpartyHonorSignature,
            counterpartyHonorTimestamp: counterparty?.honorTimestamp ?? localPropose.counterpartyHonorTimestamp,
            counterpartyPartSignature: counterparty?.partSignature ?? localPropose.counterpartyPartSignature,
            counterpartyPartTimestamp: counterparty?.partTimestamp ?? localPropose.counterpartyPartTimestamp,
            creatorHonorSignature: serverPropose.honorCreatorSignature ?? localPropose.creatorHonorSignature,
            creatorHonorTimestamp: serverPropose.honorCreatorTimestamp ?? localPropose.creatorHonorTimestamp,
            creatorPartSignature: serverPropose.partCreatorSignature ?? localPropose.creatorPartSignature,
            creatorPartTimestamp: serverPropose.partCreatorTimestamp ?? localPropose.creatorPartTimestamp,
            dissolvedAt: serverPropose.dissolvedAt ?? localPropose.dissolvedAt,
            creatorDissolveSignature: serverDissolveSignature(serverPropose: serverPropose, localPropose: localPropose, isCreator: true),
            counterpartyDissolveSignature: serverDissolveSignature(serverPropose: serverPropose, localPropose: localPropose, isCreator: false),
            signatureVersion: localPropose.signatureVersion,
            createdAt: localPropose.createdAt,
            updatedAt: Date()
        )

        // Save locally
        try proposeRepository.update(updatedPropose)
        Logger.propose.info("Reflected server signatures locally: \(localPropose.id, privacy: .private)")
    }

    /// Returns the dissolve signature for creator or counterparty from server data,
    /// falling back to the existing local value if the server has no dissolve signature or the signer doesn't match.
    private func serverDissolveSignature(serverPropose: HashedPropose, localPropose: Propose, isCreator: Bool) -> String? {
        guard let sig = serverPropose.dissolveSignature,
              let publicKey = serverPropose.dissolvePublicKey else {
            return isCreator ? localPropose.creatorDissolveSignature : localPropose.counterpartyDissolveSignature
        }
        let signerIsCreator = publicKey == localPropose.creatorPublicKey
        if isCreator {
            return signerIsCreator ? sig : localPropose.creatorDissolveSignature
        } else {
            return signerIsCreator ? localPropose.counterpartyDissolveSignature : sig
        }
    }
}
