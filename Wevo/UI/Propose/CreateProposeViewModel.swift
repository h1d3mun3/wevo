//
//  CreateProposeViewModel.swift
//  Wevo
//

import SwiftUI
import os

@Observable
@MainActor
final class CreateProposeViewModel {
    var message: String = ""
    var isSaving: Bool = false
    var errorMessage: String?
    var selectedContact: Contact?
    var showContactPicker = false
    var identities: [Identity] = []
    var selectedIdentity: Identity?
    var showIdentityPicker = false
    var shouldDismiss = false

    var canSave: Bool {
        !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !isSaving
            && selectedContact != nil
            && selectedIdentity != nil
    }

    let space: Space
    let onSuccess: () -> Void
    private let deps: any DependencyContainer

    init(space: Space, onSuccess: @escaping () -> Void, deps: any DependencyContainer) {
        self.space = space
        self.onSuccess = onSuccess
        self.deps = deps
    }

    func loadIdentities() {
        let useCase = GetAllIdentitiesUseCaseImpl(keychainRepository: deps.keychainRepository)
        do {
            let all = try useCase.execute()
            identities = all
            if let defaultID = space.defaultIdentityID,
               let defaultIdentity = all.first(where: { $0.id == defaultID }) {
                selectedIdentity = defaultIdentity
            } else {
                selectedIdentity = all.first
            }
        } catch {
            Logger.identity.error("Error loading identities: \(error, privacy: .public)")
        }
    }

    func createPropose() async {
        isSaving = true
        errorMessage = nil

        guard let contact = selectedContact, let identity = selectedIdentity else {
            errorMessage = "No Counterparty or Identity selected"
            isSaving = false
            return
        }

        let useCase = CreateProposeUseCaseImpl(
            keychainRepository: deps.keychainRepository,
            spaceRepository: deps.spaceRepository,
            proposeRepository: deps.proposeRepository
        )
        do {
            try await useCase.execute(
                identityID: identity.id,
                spaceID: space.id,
                message: message,
                counterpartyPublicKey: contact.publicKey
            )
            isSaving = false
            onSuccess()
            shouldDismiss = true
        } catch {
            Logger.propose.error("Error creating propose: \(error, privacy: .public)")
            errorMessage = "Failed to create propose: \(error.localizedDescription)"
            isSaving = false
        }
    }
}
