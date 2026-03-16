//
//  AppendServerSignaturesToLocalProposeUseCase.swift
//  Wevo
//
//  Created by hidemune on 3/9/26.
//

import Foundation

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
            counterpartyHonorSignature: counterparty?.honorSignature,
            counterpartyHonorTimestamp: counterparty?.honorTimestamp,
            counterpartyPartSignature: counterparty?.partSignature,
            counterpartyPartTimestamp: counterparty?.partTimestamp,
            creatorHonorSignature: serverPropose.honorCreatorSignature,
            creatorHonorTimestamp: serverPropose.honorCreatorTimestamp,
            creatorPartSignature: serverPropose.partCreatorSignature,
            creatorPartTimestamp: serverPropose.partCreatorTimestamp,
            dissolvedAt: serverPropose.dissolvedAt,
            finalStatus: localPropose.finalStatus,
            createdAt: localPropose.createdAt,
            updatedAt: Date()
        )

        // Save locally
        try proposeRepository.update(updatedPropose)
        print("✅ Reflected server signatures locally: \(localPropose.id)")
    }
}
