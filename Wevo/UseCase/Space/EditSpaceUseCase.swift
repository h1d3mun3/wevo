//
//  EditSpaceUseCase.swift
//  Wevo
//
//  Created by hidemune on 3/9/26.
//

import Foundation
import os

protocol EditSpaceUseCase {
    func execute(id: UUID, name: String, primaryURL: String, defaultIdentityID: UUID?) async throws
}

struct EditSpaceUseCaseImpl {
    let spaceRepository: SpaceRepository
    let getSpaceUseCase: GetSpaceUseCase
    let fetchServerInfoUseCase: FetchServerInfoUseCase

    init(
        spaceRepository: SpaceRepository,
        getSpaceUseCase: GetSpaceUseCase,
        fetchServerInfoUseCase: FetchServerInfoUseCase = FetchServerInfoUseCaseImpl()
    ) {
        self.spaceRepository = spaceRepository
        self.getSpaceUseCase = getSpaceUseCase
        self.fetchServerInfoUseCase = fetchServerInfoUseCase
    }
}

extension EditSpaceUseCaseImpl: EditSpaceUseCase {
    func execute(id: UUID, name: String, primaryURL: String, defaultIdentityID: UUID?) async throws {
        let space = try getSpaceUseCase.execute(id: id)

        let trimmedURL = primaryURL.trimmingCharacters(in: .whitespacesAndNewlines)
        var allURLs = [trimmedURL]
        if let info = try? await fetchServerInfoUseCase.execute(urlString: trimmedURL) {
            let peers = info.peers.filter { $0 != trimmedURL }
            allURLs.append(contentsOf: peers)
        } else if space.urls.count > 1 {
            allURLs = space.urls.map { $0 == space.url ? trimmedURL : $0 }
        }

        let updatedSpace = Space(
            id: space.id,
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            urls: allURLs,
            defaultIdentityID: defaultIdentityID,
            orderIndex: space.orderIndex,
            createdAt: space.createdAt,
            updatedAt: .now
        )

        try spaceRepository.update(updatedSpace)
        Logger.space.info("Space updated successfully: \(updatedSpace.name, privacy: .private)")
    }
}
