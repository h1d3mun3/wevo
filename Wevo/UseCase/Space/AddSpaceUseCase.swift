//
//  AddSpaceUseCase.swift
//  Wevo
//
//  Created by hidemune on 3/9/26.
//

import Foundation
import os

protocol AddSpaceUseCase {
    func execute(name: String, urls: [String], defaultIdentityID: UUID?) throws
}

struct AddSpaceUseCaseImpl {
    let spaceRepository: SpaceRepository

    init(spaceRepository: SpaceRepository) {
        self.spaceRepository = spaceRepository
    }
}

extension AddSpaceUseCaseImpl: AddSpaceUseCase {
    func execute(name: String, urls: [String], defaultIdentityID: UUID?) throws {
        let trimmedURLs = urls
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        // Fetch existing Spaces count to determine orderIndex
        let orderIndex: Int
        do {
            let existingSpaces = try spaceRepository.fetchAll()
            orderIndex = existingSpaces.count
        } catch {
            Logger.space.error("Error fetching spaces: \(error, privacy: .public)")
            orderIndex = 0
        }

        // Create Space entity
        let space = Space(
            id: UUID(),
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            urls: trimmedURLs,
            defaultIdentityID: defaultIdentityID,
            orderIndex: orderIndex,
            createdAt: .now,
            updatedAt: .now
        )

        // Save to SwiftData
        try spaceRepository.create(space)
        Logger.space.info("Space saved: \(space.name, privacy: .private)")
    }
}
