//
//  GetSpaceUseCase.swift
//  Wevo
//
//  Created by hidemune on 3/9/26.
//

import Foundation

protocol GetSpaceUseCase {
    func execute(id: UUID) throws -> Space
}

struct GetSpaceUseCaseImpl {
    let spaceRepository: SpaceRepository

    init(spaceRepository: SpaceRepository) {
        self.spaceRepository = spaceRepository
    }
}

extension GetSpaceUseCaseImpl: GetSpaceUseCase {
    func execute(id: UUID) throws -> Space {
        try spaceRepository.fetch(by: id)
    }
}
