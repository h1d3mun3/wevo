//
//  ApplyServerStatusToLocalProposeUseCase.swift
//  Wevo
//
//  Created on 3/15/26.
//

import Foundation

protocol ApplyServerStatusToLocalProposeUseCase {
    /// Reflect a terminal server status (honored/parted/dissolved) in the local Propose
    /// - Parameters:
    ///   - proposeID: ID of the target Propose
    ///   - status: The terminal status to apply
    func execute(proposeID: UUID, status: ProposeStatus) throws
}

struct ApplyServerStatusToLocalProposeUseCaseImpl {
    let proposeRepository: ProposeRepository

    init(proposeRepository: ProposeRepository) {
        self.proposeRepository = proposeRepository
    }
}

extension ApplyServerStatusToLocalProposeUseCaseImpl: ApplyServerStatusToLocalProposeUseCase {
    func execute(proposeID: UUID, status: ProposeStatus) throws {
        let local = try proposeRepository.fetch(by: proposeID)

        let updated = Propose(
            id: local.id,
            spaceID: local.spaceID,
            message: local.message,
            creatorPublicKey: local.creatorPublicKey,
            creatorSignature: local.creatorSignature,
            counterpartyPublicKey: local.counterpartyPublicKey,
            counterpartySignSignature: local.counterpartySignSignature,
            counterpartySignTimestamp: local.counterpartySignTimestamp,
            counterpartyHonorSignature: local.counterpartyHonorSignature,
            counterpartyHonorTimestamp: local.counterpartyHonorTimestamp,
            counterpartyPartSignature: local.counterpartyPartSignature,
            counterpartyPartTimestamp: local.counterpartyPartTimestamp,
            creatorHonorSignature: local.creatorHonorSignature,
            creatorHonorTimestamp: local.creatorHonorTimestamp,
            creatorPartSignature: local.creatorPartSignature,
            creatorPartTimestamp: local.creatorPartTimestamp,
            dissolvedAt: local.dissolvedAt,
            finalStatus: status,
            createdAt: local.createdAt,
            updatedAt: Date()
        )

        try proposeRepository.update(updated)
        print("✅ Applied server status locally: \(status.rawValue) for \(proposeID)")
    }
}
