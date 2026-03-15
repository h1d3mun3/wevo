//
//  AppendServerSignaturesToLocalProposeUseCase.swift
//  Wevo
//
//  Created by hidemune on 3/9/26.
//

import Foundation

protocol AppendServerSignaturesToLocalProposeUseCase {
    /// Reflect the Counterparty's sign signature in the local Propose
    /// - Parameters:
    ///   - proposeID: ID of the target Propose
    ///   - counterpartySignSignature: Counterparty's signature string (Base64 DER)
    func execute(proposeID: UUID, counterpartySignSignature: String) throws
}

struct AppendServerSignaturesToLocalProposeUseCaseImpl {
    let proposeRepository: ProposeRepository

    init(proposeRepository: ProposeRepository) {
        self.proposeRepository = proposeRepository
    }
}

extension AppendServerSignaturesToLocalProposeUseCaseImpl: AppendServerSignaturesToLocalProposeUseCase {
    func execute(proposeID: UUID, counterpartySignSignature: String) throws {
        let localPropose = try proposeRepository.fetch(by: proposeID)

        // Update Propose with the counterpartySignSignature set
        let updatedPropose = Propose(
            id: localPropose.id,
            spaceID: localPropose.spaceID,
            message: localPropose.message,
            creatorPublicKey: localPropose.creatorPublicKey,
            creatorSignature: localPropose.creatorSignature,
            counterpartyPublicKey: localPropose.counterpartyPublicKey,
            counterpartySignSignature: counterpartySignSignature,
            createdAt: localPropose.createdAt,
            updatedAt: Date()
        )

        // Save locally
        try proposeRepository.update(updatedPropose)
        print("✅ Reflected Counterparty signature locally: \(localPropose.id)")
    }
}
