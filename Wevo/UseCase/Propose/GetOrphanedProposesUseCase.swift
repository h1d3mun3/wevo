//
//  GetOrphanedProposesUseCase.swift
//  Wevo
//
//  Created by hidemune on 3/10/26.
//

import Foundation

protocol GetOrphanedProposesUseCase {
    func execute(validSpaceIDs: Set<UUID>) throws -> [Propose]
}

struct GetOrphanedProposesUseCaseImpl {
    let proposeRepository: ProposeRepository

    init(proposeRepository: ProposeRepository) {
        self.proposeRepository = proposeRepository
    }
}

extension GetOrphanedProposesUseCaseImpl: GetOrphanedProposesUseCase {
    func execute(validSpaceIDs: Set<UUID>) throws -> [Propose] {
        return try proposeRepository.fetchAllOrphaned(validSpaceIDs: validSpaceIDs)
    }
}
