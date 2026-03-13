//
//  GetProposeUseCase.swift
//  Wevo
//

import Foundation

protocol GetProposeUseCase {
    func execute(id: UUID) throws -> Propose
}

struct GetProposeUseCaseImpl {
    let proposeRepository: ProposeRepository

    init(proposeRepository: ProposeRepository) {
        self.proposeRepository = proposeRepository
    }
}

extension GetProposeUseCaseImpl: GetProposeUseCase {
    func execute(id: UUID) throws -> Propose {
        try proposeRepository.fetch(by: id)
    }
}
