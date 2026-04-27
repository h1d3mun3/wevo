//
//  EditSpaceViewModel.swift
//  Wevo
//

import SwiftUI
import os

@Observable
@MainActor
final class EditSpaceViewModel {
    var name: String
    var url: String
    var isSaving: Bool = false
    var errorMessage: String?
    var identities: [Identity] = []
    var selectedIdentity: Identity?
    var showIdentityPicker = false
    var shouldDismiss = false

    var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !url.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !isSaving &&
        (name != space.name || url != space.url || selectedIdentity?.id != space.defaultIdentityID)
    }

    let space: Space
    let onUpdate: () -> Void
    private let deps: any DependencyContainer

    init(space: Space, onUpdate: @escaping () -> Void, deps: any DependencyContainer) {
        self.space = space
        self.onUpdate = onUpdate
        self.deps = deps
        self.name = space.name
        self.url = space.url
    }

    func loadIdentities() {
        let useCase = GetAllIdentitiesUseCaseImpl(keychainRepository: deps.keychainRepository)
        do {
            let all = try useCase.execute()
            identities = all
            selectedIdentity = all.first { $0.id == space.defaultIdentityID }
        } catch {
            Logger.identity.error("Error loading identities: \(error, privacy: .public)")
        }
    }

    func saveChanges() async {
        isSaving = true
        errorMessage = nil
        let useCase = EditSpaceUseCaseImpl(
            spaceRepository: deps.spaceRepository,
            getSpaceUseCase: GetSpaceUseCaseImpl(spaceRepository: deps.spaceRepository)
        )
        do {
            try await useCase.execute(
                id: space.id,
                name: name,
                primaryURL: url,
                defaultIdentityID: selectedIdentity?.id
            )
            isSaving = false
            onUpdate()
            shouldDismiss = true
        } catch {
            Logger.space.error("Failed to update space: \(error, privacy: .public)")
            errorMessage = "Failed to save: \(error.localizedDescription)"
            isSaving = false
        }
    }
}
