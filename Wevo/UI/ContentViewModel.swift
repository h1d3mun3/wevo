//
//  ContentViewModel.swift
//  Wevo
//

import SwiftUI
import os

@Observable
@MainActor
final class ContentViewModel {
    var shouldShowIdentityList = false
    var shouldShowContactList = false
    var shouldShowAddSpace = false
    var shouldShowSettings = false
    var spaces: [Space] = []
    var orphanedProposeGroups: [OrphanedProposeGroup] = []
    var deleteSpaceError: String?

    private let deps: any DependencyContainer

    init(deps: any DependencyContainer) {
        self.deps = deps
    }

    func loadSpaces() async {
        let getAllSpacesUseCase = GetAllSpacesUseCaseImpl(spaceRepository: deps.spaceRepository)
        let getOrphanedProposesUseCase = GetOrphanedProposesUseCaseImpl(proposeRepository: deps.proposeRepository)
        do {
            let loadedSpaces = try getAllSpacesUseCase.execute()
            let spaceIDs = Set(loadedSpaces.map { $0.id })
            let groups = try getOrphanedProposesUseCase.execute(validSpaceIDs: spaceIDs)
            spaces = loadedSpaces
            orphanedProposeGroups = groups
        } catch {
            Logger.space.error("Error loading spaces: \(error, privacy: .public)")
            spaces = []
            orphanedProposeGroups = []
        }
    }

    func deleteSpace(offsets: IndexSet) {
        let useCase = DeleteSpaceUseCaseImpl(spaceRepository: deps.spaceRepository)
        Task {
            do {
                for index in offsets {
                    try useCase.execute(id: spaces[index].id)
                }
                await loadSpaces()
            } catch {
                Logger.space.error("Error deleting space: \(error, privacy: .public)")
                deleteSpaceError = error.localizedDescription
            }
        }
    }
}
