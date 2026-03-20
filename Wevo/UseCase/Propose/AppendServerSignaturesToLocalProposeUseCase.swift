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
            finalStatus: localPropose.finalStatus,
            signatureVersion: localPropose.signatureVersion,
            createdAt: localPropose.createdAt,
            updatedAt: Date()
        )

        // Save locally
        try proposeRepository.update(updatedPropose)
        Logger.propose.info("Reflected server signatures locally: \(localPropose.id, privacy: .private)")
    }
}
