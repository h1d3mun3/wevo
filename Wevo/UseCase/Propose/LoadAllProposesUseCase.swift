//
//  LoadAllProposesUseCase.swift
//  Wevo
//
//  Created by hidemune on 3/9/26.
//

import Foundation

protocol LoadAllProposesUseCase {
    func execute(id: UUID) throws -> [Propose]
}

struct LoadAllProposesUseCaseIpml {
    let proposeRepository: ProposeRepository

    init(proposeRepository: ProposeRepository) {
        self.proposeRepository = proposeRepository
    }
}

extension LoadAllProposesUseCaseIpml: LoadAllProposesUseCase {
    func execute(id: UUID) throws -> [Propose] {
        return try proposeRepository.fetchAll(for: id)
    }
}
