//
//  RefreshSpacePeersUseCase.swift
//  Wevo
//

import Foundation
import os

protocol RefreshSpacePeersUseCase {
    func execute() async
}

/// Refreshes peer node URLs for all Spaces by calling /info on each Space's primary URL.
/// Called once at app startup. Failures are logged and silently ignored per Space.
struct RefreshSpacePeersUseCaseImpl {
    let spaceRepository: SpaceRepository
    let httpClient: any HTTPDataFetching

    init(spaceRepository: SpaceRepository, httpClient: any HTTPDataFetching = URLSession.shared) {
        self.spaceRepository = spaceRepository
        self.httpClient = httpClient
    }

}

extension RefreshSpacePeersUseCaseImpl: RefreshSpacePeersUseCase {
    func execute() async {
        let spaces: [Space]
        do {
            spaces = try spaceRepository.fetchAll()
        } catch {
            Logger.space.error("RefreshSpacePeers: failed to fetch spaces: \(error, privacy: .public)")
            return
        }

        await withTaskGroup(of: Void.self) { group in
            for space in spaces {
                group.addTask { await refresh(space) }
            }
        }
    }

    // MARK: - Private

    private func refresh(_ space: Space) async {
        guard !space.url.isEmpty else { return }

        let info: WevoServerInfo
        do {
            info = try await FetchServerInfoUseCaseImpl(httpClient: httpClient).execute(urlString: space.url)
        } catch {
            Logger.space.warning("RefreshSpacePeers: /info unreachable for '\(space.name, privacy: .private)': \(error, privacy: .public)")
            return
        }

        let updatedURLs = [space.url] + info.peers.filter { $0 != space.url }
        guard updatedURLs != space.urls else { return }

        let updatedSpace = Space(
            id: space.id,
            name: space.name,
            urls: updatedURLs,
            defaultIdentityID: space.defaultIdentityID,
            orderIndex: space.orderIndex,
            createdAt: space.createdAt,
            updatedAt: space.updatedAt
        )

        do {
            try spaceRepository.update(updatedSpace)
            Logger.space.info("RefreshSpacePeers: updated peers for '\(space.name, privacy: .private)': \(updatedURLs, privacy: .private)")
        } catch {
            Logger.space.error("RefreshSpacePeers: failed to save '\(space.name, privacy: .private)': \(error, privacy: .public)")
        }
    }
}
