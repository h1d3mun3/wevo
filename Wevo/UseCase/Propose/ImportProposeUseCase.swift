//
//  ImportProposeUseCase.swift
//  Wevo
//

import Foundation

enum ImportProposeUseCaseError: Error {
    case failedToSave
}

protocol ImportProposeUseCase {
    func execute(propose: Propose, spaceID: UUID) throws
}

struct ImportProposeUseCaseImpl {
    let proposeRepository: ProposeRepository

    init(proposeRepository: ProposeRepository) {
        self.proposeRepository = proposeRepository
    }
}

extension ImportProposeUseCaseImpl: ImportProposeUseCase {
    /// Imports a Propose received via AirDrop or file sharing.
    ///
    /// - If no local Propose with the same ID exists, creates a new one in the given space.
    /// - If a local Propose already exists (e.g. the creator receiving back a signed copy),
    ///   merges the incoming signatures into the existing record.
    ///   Local `spaceID` and `message` are always preserved; incoming non-nil fields win for
    ///   all signature fields so that signatures are never lost in either direction.
    func execute(propose: Propose, spaceID: UUID) throws {
        if let existing = try? proposeRepository.fetch(by: propose.id) {
            let merged = Propose(
                id: existing.id,
                spaceID: existing.spaceID,
                message: existing.message,
                creatorPublicKey: existing.creatorPublicKey,
                creatorSignature: existing.creatorSignature,
                counterpartyPublicKey: existing.counterpartyPublicKey,
                counterpartySignSignature: propose.counterpartySignSignature ?? existing.counterpartySignSignature,
                counterpartySignTimestamp: propose.counterpartySignTimestamp ?? existing.counterpartySignTimestamp,
                counterpartyHonorSignature: propose.counterpartyHonorSignature ?? existing.counterpartyHonorSignature,
                counterpartyHonorTimestamp: propose.counterpartyHonorTimestamp ?? existing.counterpartyHonorTimestamp,
                counterpartyPartSignature: propose.counterpartyPartSignature ?? existing.counterpartyPartSignature,
                counterpartyPartTimestamp: propose.counterpartyPartTimestamp ?? existing.counterpartyPartTimestamp,
                creatorHonorSignature: propose.creatorHonorSignature ?? existing.creatorHonorSignature,
                creatorHonorTimestamp: propose.creatorHonorTimestamp ?? existing.creatorHonorTimestamp,
                creatorPartSignature: propose.creatorPartSignature ?? existing.creatorPartSignature,
                creatorPartTimestamp: propose.creatorPartTimestamp ?? existing.creatorPartTimestamp,
                dissolvedAt: propose.dissolvedAt ?? existing.dissolvedAt,
                finalStatus: propose.finalStatus ?? existing.finalStatus,
                createdAt: existing.createdAt,
                updatedAt: Date()
            )
            do {
                try proposeRepository.update(merged)
            } catch {
                throw ImportProposeUseCaseError.failedToSave
            }
        } else {
            do {
                try proposeRepository.create(propose, spaceID: spaceID)
            } catch {
                throw ImportProposeUseCaseError.failedToSave
            }
        }
    }
}
