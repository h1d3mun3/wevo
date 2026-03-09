//
//  DeleteProposeUseCase.swift
//  Wevo
//
//  Created by hidemune on 3/9/26.
//

import Foundation

protocol DeleteProposeUseCase {
    func execute(id: UUID) throws
}

struct DeleteProposeUseCaseImpl {
    let proposeRepository: ProposeRepository

    init(proposeRepository: ProposeRepository) {
        self.proposeRepository = proposeRepository
    }
}

extension DeleteProposeUseCaseImpl: DeleteProposeUseCase {
    func execute(id: UUID) throws {
        try proposeRepository.delete(by: id)
    }
}
