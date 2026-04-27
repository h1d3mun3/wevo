//
//  AddSpaceViewModel.swift
//  Wevo
//

import SwiftUI
import os

@Observable
@MainActor
final class AddSpaceViewModel {
    var name: String = ""
    var urlString: String = ""
    var identities: [Identity] = []
    var selectedIdentityID: UUID?
    var isSaving: Bool = false
    var saveError: String?
    var shouldDismiss = false

    var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !urlString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        selectedIdentityID != nil &&
        !isSaving
    }

    private let deps: any DependencyContainer

    init(deps: any DependencyContainer) {
        self.deps = deps
    }

    func loadIdentities() async {
        let useCase = LoadIdentitiesWithDefaultSelectionUseCaseImpl(keychainRepository: deps.keychainRepository)
        do {
            let (loadedIdentities, defaultSelectedID) = try useCase.execute()
            identities = loadedIdentities
            if selectedIdentityID == nil {
                selectedIdentityID = defaultSelectedID
            }
        } catch {
            Logger.identity.error("Error loading identities: \(error, privacy: .public)")
            identities = []
        }
    }

    func add() async {
        guard canSave else { return }
        isSaving = true
        let useCase = AddSpaceUseCaseImpl(spaceRepository: deps.spaceRepository)
        do {
            try await useCase.execute(name: name, primaryURL: urlString, defaultIdentityID: selectedIdentityID)
            isSaving = false
            shouldDismiss = true
        } catch {
            Logger.space.error("Error saving space: \(error, privacy: .public)")
            isSaving = false
            saveError = error.localizedDescription
        }
    }
}
