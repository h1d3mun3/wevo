//
//  EditSpaceUseCase.swift
//  Wevo
//
//  Created by hidemune on 3/9/26.
//

import Foundation

protocol EditSpaceUseCase {
    func execute(id: UUID, name: String, urlString: String) throws
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
    func execute(id: UUID, name: String, urlString: String) throws {
        let space = try getSpaceUseCase.execute(id: id)

        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedURL = urlString.trimmingCharacters(in: .whitespacesAndNewlines)

        // Create updated Space
        let updatedSpace = Space(
            id: space.id,
            name: trimmedName,
            url: trimmedURL,
            defaultIdentityID: space.defaultIdentityID,
            orderIndex: space.orderIndex,
            createdAt: space.createdAt,
            updatedAt: .now
        )

        // Update in repository
        try spaceRepository.update(updatedSpace)
        print("✅ Space updated successfully: \(updatedSpace.name)")
    }
}
