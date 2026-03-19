//
//  EditSpaceUseCase.swift
//  Wevo
//
//  Created by hidemune on 3/9/26.
//

import Foundation
import os

protocol EditSpaceUseCase {
    func execute(id: UUID, name: String, urlString: String, defaultIdentityID: UUID?) throws
}

struct EditSpaceUseCaseImpl {
    let spaceRepository: SpaceRepository
    let getSpaceUseCase: GetSpaceUseCase

    init(spaceRepository: SpaceRepository, getSpaceUseCase: GetSpaceUseCase) {
        self.spaceRepository = spaceRepository
        self.getSpaceUseCase = getSpaceUseCase
    }
}

extension EditSpaceUseCaseImpl: EditSpaceUseCase {
    func execute(id: UUID, name: String, urlString: String, defaultIdentityID: UUID?) throws {
        let space = try getSpaceUseCase.execute(id: id)

        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedURL = urlString.trimmingCharacters(in: .whitespacesAndNewlines)

        let updatedSpace = Space(
            id: space.id,
            name: trimmedName,
            url: trimmedURL,
            defaultIdentityID: defaultIdentityID,
            orderIndex: space.orderIndex,
            createdAt: space.createdAt,
            updatedAt: .now
        )

        try spaceRepository.update(updatedSpace)
        Logger.space.info("Space updated successfully: \(updatedSpace.name, privacy: .private)")
    }
}
