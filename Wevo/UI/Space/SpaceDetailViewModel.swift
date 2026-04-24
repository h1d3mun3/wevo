//
//  SpaceDetailViewModel.swift
//  Wevo
//

import SwiftUI
import os

enum SpaceDetailTab: String, CaseIterable {
    case active = "Active"
    case completed = "Completed"
}

@Observable
@MainActor
final class SpaceDetailViewModel {
    var proposes: [Propose] = []
    var isLoading = false
    var errorMessage: String?
    var defaultIdentity: Identity?
    var selectedTab: SpaceDetailTab = .active
    var serverCheckTrigger = UUID()
    var currentSpace: Space
    var shouldShowCreatePropose = false
    var shouldShowEditSpace = false
    var shouldDismiss = false

    var activeProposes: [Propose] {
        proposes.filter { $0.localStatus.isActive }
    }

    var completedProposes: [Propose] {
        proposes.filter { !$0.localStatus.isActive }
    }

    private let space: Space
    private let deps: any DependencyContainer

    init(space: Space, deps: any DependencyContainer) {
        self.space = space
        self.currentSpace = space
        self.deps = deps
    }

    func loadDefaultIdentity() async {
        let useCase = GetDefaultIdentityForSpaceUseCaseImpl(keychainRepository: deps.keychainRepository)
        do {
            defaultIdentity = try useCase.execute(space: currentSpace)
        } catch {
            Logger.identity.error("Error loading default Identity: \(error, privacy: .public)")
            defaultIdentity = nil
        }
    }

    func loadProposesFromLocal() {
        isLoading = true
        errorMessage = nil
        do {
            let useCase = LoadAllProposesUseCaseImpl(proposeRepository: deps.proposeRepository)
            let loaded = try useCase.execute(id: currentSpace.id)
            proposes = loaded
            isLoading = false
            if loaded.isEmpty {
                Logger.propose.info("No proposes found locally: \(currentSpace.name, privacy: .private)")
            } else {
                Logger.propose.info("Loaded \(loaded.count) propose(s) from local storage")
            }
        } catch {
            Logger.propose.error("Error loading proposes from local storage: \(error, privacy: .public)")
            isLoading = false
            errorMessage = "Failed to load proposes: \(error.localizedDescription)"
            proposes = []
        }
    }

    func reloadSpace() async {
        let useCase = GetSpaceUseCaseImpl(spaceRepository: deps.spaceRepository)
        do {
            let updated = try useCase.execute(id: space.id)
            currentSpace = updated
            Logger.space.info("Space reload complete: \(updated.name, privacy: .private)")
        } catch SpaceRepositoryError.spaceNotFound {
            shouldDismiss = true
        } catch {
            Logger.space.error("Failed to reload Space: \(error, privacy: .public)")
        }
        await loadDefaultIdentity()
    }

    func refresh() {
        loadProposesFromLocal()
        serverCheckTrigger = UUID()
    }
}
