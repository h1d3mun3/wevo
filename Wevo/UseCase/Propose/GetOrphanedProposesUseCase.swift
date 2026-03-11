//
//  GetOrphanedProposesUseCase.swift
//  Wevo
//
//  Created by hidemune on 3/10/26.
//

import Foundation

struct OrphanedProposeGroup {
    let spaceID: UUID
    let proposes: [Propose]
}

protocol GetOrphanedProposesUseCase {
    func execute(validSpaceIDs: Set<UUID>) throws -> [OrphanedProposeGroup]
}

struct GetOrphanedProposesUseCaseImpl {
    let proposeRepository: ProposeRepository

    init(proposeRepository: ProposeRepository) {
        self.proposeRepository = proposeRepository
    }
}

extension GetOrphanedProposesUseCaseImpl: GetOrphanedProposesUseCase {
    func execute(validSpaceIDs: Set<UUID>) throws -> [OrphanedProposeGroup] {
        let orphaned = try proposeRepository.fetchAllOrphaned(validSpaceIDs: validSpaceIDs)

        // spaceIDでグループ化
        let grouped = Dictionary(grouping: orphaned, by: { $0.spaceID })

        // 各グループの最新createdAtで降順ソート
        let sortedGroups = grouped.sorted { group1, group2 in
            let date1 = group1.value.max { $0.createdAt < $1.createdAt }?.createdAt ?? .distantPast
            let date2 = group2.value.max { $0.createdAt < $1.createdAt }?.createdAt ?? .distantPast
            return date1 > date2
        }

        return sortedGroups.map { OrphanedProposeGroup(spaceID: $0.key, proposes: $0.value) }
    }
}
