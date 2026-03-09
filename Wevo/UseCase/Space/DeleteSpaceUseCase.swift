//
//  DeleteSpaceUseCase.swift
//  Wevo
//
//  Created by hidemune on 3/9/26.
//

import Foundation

protocol DeleteSpaceUseCase {
    func execute(id: UUID) throws
}

struct DeleteSpaceUseCaseImpl {
    let spaceRepository: SpaceRepository

    init(spaceRepository: SpaceRepository) {
        self.spaceRepository = spaceRepository
    }
}

extension DeleteSpaceUseCaseImpl: DeleteSpaceUseCase {
    func execute(id: UUID) throws {
        try spaceRepository.delete(by: id)
    }
}
