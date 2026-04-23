//
//  AddSpaceUseCase.swift
//  Wevo
//
//  Created by hidemune on 3/9/26.
//

import Foundation
import os

protocol AddSpaceUseCase {
    func execute(name: String, primaryURL: String, defaultIdentityID: UUID?) async throws
}

struct AddSpaceUseCaseImpl {
    let spaceRepository: SpaceRepository
    let fetchServerInfoUseCase: FetchServerInfoUseCase

    init(
        spaceRepository: SpaceRepository,
        fetchServerInfoUseCase: FetchServerInfoUseCase = FetchServerInfoUseCaseImpl()
    ) {
        self.spaceRepository = spaceRepository
        self.fetchServerInfoUseCase = fetchServerInfoUseCase
    }
}

extension AddSpaceUseCaseImpl: AddSpaceUseCase {
    func execute(name: String, primaryURL: String, defaultIdentityID: UUID?) async throws {
        let trimmedURL = primaryURL.trimmingCharacters(in: .whitespacesAndNewlines)

        var allURLs = [trimmedURL]
        if let info = try? await fetchServerInfoUseCase.execute(urlString: trimmedURL) {
            let peers = info.peers.filter { $0 != trimmedURL }
            allURLs.append(contentsOf: peers)
        }

        let orderIndex: Int
        do {
            let existingSpaces = try spaceRepository.fetchAll()
            orderIndex = existingSpaces.count
        } catch {
            Logger.space.error("Error fetching spaces: \(error, privacy: .public)")
            orderIndex = 0
        }

        let space = Space(
            id: UUID(),
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            urls: allURLs,
            defaultIdentityID: defaultIdentityID,
            orderIndex: orderIndex,
            createdAt: .now,
            updatedAt: .now
        )

        try spaceRepository.create(space)
        Logger.space.info("Space saved: \(space.name, privacy: .private)")
    }
}
