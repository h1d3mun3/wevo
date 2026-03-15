//
//  AddSpaceUseCase.swift
//  Wevo
//
//  Created by hidemune on 3/9/26.
//

import Foundation

protocol AddSpaceUseCase {
    func execute(name: String, urlString: String, defaultIdentityID: UUID?) throws
}

struct AddSpaceUseCaseImpl {
    let spaceRepository: SpaceRepository

    init(spaceRepository: SpaceRepository) {
        self.spaceRepository = spaceRepository
    }
}

extension AddSpaceUseCaseImpl: AddSpaceUseCase {
    func execute(name: String, urlString: String, defaultIdentityID: UUID?) throws {
        // Validate URL (optional)
        let trimmedURL = urlString.trimmingCharacters(in: .whitespacesAndNewlines)

        // Fetch existing Spaces count to determine orderIndex
        let orderIndex: Int
        do {
            let existingSpaces = try spaceRepository.fetchAll()
            orderIndex = existingSpaces.count
        } catch {
            print("❌ Error fetching spaces: \(error)")
            orderIndex = 0
        }

        // Create Space entity
        let space = Space(
            id: UUID(),
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            url: trimmedURL,
            defaultIdentityID: defaultIdentityID,
            orderIndex: orderIndex,
            createdAt: .now,
            updatedAt: .now
        )

        // Save to SwiftData
        try spaceRepository.create(space)
        print("✅ Space saved: \(space.name)")
    }
}
