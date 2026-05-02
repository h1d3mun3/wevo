//
//  GetAllSpacesUseCase.swift
//  Wevo
//
//  Created by hidemune on 3/9/26.
//

import Foundation

protocol GetAllSpacesUseCase {
    func execute() throws -> [Space]
}

struct GetAllSpacesUseCaseImpl {
    let spaceRepository: SpaceRepository

    init(spaceRepository: SpaceRepository) {
        self.spaceRepository = spaceRepository
    }
}

extension GetAllSpacesUseCaseImpl: GetAllSpacesUseCase {
    func execute() throws -> [Space] {
        try spaceRepository.fetchAll()
    }
}
