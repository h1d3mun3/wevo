//
//  CreateProposeView.swift
//  Wevo
//
//  Created by hidemune on 3/6/26.
//

import SwiftUI
import CryptoKit
import os

struct CreateProposeView: View {
    let space: Space
    let onSuccess: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.dependencies) private var deps

    @State private var message: String = ""
    @State private var isSaving: Bool = false
    @State private var errorMessage: String?
    @State private var selectedContact: Contact?
    @State private var showContactPicker = false
    @State private var identities: [Identity] = []
    @State private var selectedIdentity: Identity?
    @State private var showIdentityPicker = false

    private var canSave: Bool {
        !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !isSaving
            && selectedContact != nil
            && selectedIdentity != nil
    }

    var body: some View {
        NavigationStack {
            Form {
                // MARK: - Basic Information Section
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Space")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(space.name)
                            .font(.body)
                    }

                    if let identity = selectedIdentity {
                        HStack {
                            Image(systemName: "key.fill")
                                .foregroundStyle(.blue)
                            Text(identity.nickname)
                                .font(.body)
                            Spacer()
                            if identities.count > 1 {
                                Button("Change") { showIdentityPicker = true }
                                    .buttonStyle(.borderless)
                                    .foregroundStyle(.blue)
                            }
                        }
                    } else {
                        Button {
                            showIdentityPicker = true
                        } label: {
                            HStack {
                                Image(systemName: "key.fill")
                                    .foregroundStyle(.blue)
                                Text("Select an Identity...")
                                    .foregroundStyle(.blue)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                } header: {
                    Text("Information")
                }

                // MARK: - To (Counterparty) Section
                Section {
                    if let contact = selectedContact {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(contact.nickname)
                                    .font(.body)
                                Text(contact.publicKey.prefix(16) + "...")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .fontDesign(.monospaced)
                            }

                            Spacer()

                            Button("Change") {
                                showContactPicker = true
                            }
                            .buttonStyle(.borderless)
                            .foregroundStyle(.blue)
                        }
                    } else {
                        Button {
                            showContactPicker = true
                        } label: {
                            HStack {
                                Image(systemName: "person.crop.circle.badge.plus")
                                    .foregroundStyle(.blue)
                                Text("Select a Contact...")
                                    .foregroundStyle(.blue)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                } header: {
                    Text("To（Counterparty）")
                } footer: {
                    Text("Select the counterparty who will sign the Propose.")
                }

                // MARK: - Message Section
                Section {
                    TextField("Message", text: $message, axis: .vertical)
                        .autocorrectionDisabled()
                        .lineLimit(3...10)
                } header: {
                    Text("Propose Message")
                } footer: {
                    Text("Enter the message for the propose. It will be SHA256-hashed and signed with your identity.")
                }

                // MARK: - Error Message
                if let errorMessage = errorMessage {
                    Section {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.red)
                            Text(errorMessage)
                                .foregroundStyle(.red)
                                .font(.caption)
                        }
                    }
                }
            }
            .navigationTitle("Create Propose")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .disabled(isSaving)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        Task {
                            await createPropose()
                        }
                    }
                    .disabled(!canSave)
                }
            }
            .disabled(isSaving)
            .sheet(isPresented: $showContactPicker) {
                ContactPickerSheet(selectedContact: $selectedContact)
            }
            .sheet(isPresented: $showIdentityPicker) {
                IdentityPickerSheet(
                    identities: identities,
                    selectedIdentity: $selectedIdentity
                )
            }
            .task {
                loadIdentities()
            }
        }
#if os(macOS)
        .frame(minWidth: 400, minHeight: 500)
#endif
    }

    private func loadIdentities() {
        let useCase = GetAllIdentitiesUseCaseImpl(keychainRepository: deps.keychainRepository)
        do {
            let all = try useCase.execute()
            identities = all
            // Default to the space's default identity, fall back to the first available
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

    private func createPropose() async {
        await MainActor.run {
            isSaving = true
            errorMessage = nil
        }

        guard let contact = selectedContact, let identity = selectedIdentity else {
            await MainActor.run {
                errorMessage = "No Counterparty or Identity selected"
                isSaving = false
            }
            return
        }

        let createProposeUseCaseImpl = CreateProposeUseCaseImpl(
            keychainRepository: deps.keychainRepository,
            spaceRepository: deps.spaceRepository,
            proposeRepository: deps.proposeRepository
        )

        do {
            try await createProposeUseCaseImpl.execute(
                identityID: identity.id,
                spaceID: space.id,
                message: message,
                counterpartyPublicKey: contact.publicKey
            )

            // Close the screen regardless of result
            await MainActor.run {
                isSaving = false
                onSuccess()
                dismiss()
            }

        } catch {
            Logger.propose.error("Error creating propose: \(error, privacy: .public)")
            await MainActor.run {
                errorMessage = "Failed to create propose: \(error.localizedDescription)"
                isSaving = false
            }
        }
    }
}

// MARK: - ContactPickerSheet

/// Sheet for selecting a Contact
struct ContactPickerSheet: View {
    @Binding var selectedContact: Contact?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dependencies) private var deps

    @State private var contacts: [Contact] = []
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Group {
                if contacts.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "person.crop.circle.badge.xmark")
                            .font(.largeTitle)
                            .foregroundStyle(.secondary)
                        Text("No contacts found")
                            .foregroundStyle(.secondary)
                        Text("Please add a contact first.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                } else {
                    List(contacts) { contact in
                        Button {
                            selectedContact = contact
                            dismiss()
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(contact.nickname)
                                    .font(.body)
                                Text(contact.publicKey.prefix(24) + "...")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .fontDesign(.monospaced)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .navigationTitle("Select Counterparty")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .task {
                loadContacts()
            }
        }
    }

    private func loadContacts() {
        let useCase = GetAllContactsUseCaseImpl(contactRepository: deps.contactRepository)
        do {
            contacts = try useCase.execute()
        } catch {
            Logger.contact.error("Error loading contacts: \(error, privacy: .public)")
            errorMessage = "Failed to load contacts"
        }
    }
}

// MARK: - IdentityPickerSheet

struct IdentityPickerSheet: View {
    let identities: [Identity]
    @Binding var selectedIdentity: Identity?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if identities.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "key.slash")
                            .font(.largeTitle)
                            .foregroundStyle(.secondary)
                        Text("No identities found")
                            .foregroundStyle(.secondary)
                        Text("Please create an identity first.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                } else {
                    List(identities) { identity in
                        Button {
                            selectedIdentity = identity
                            dismiss()
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(identity.nickname)
                                        .font(.body)
                                    Text(identity.fingerprintDisplay)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .fontDesign(.monospaced)
                                }
                                Spacer()
                                if identity.id == selectedIdentity?.id {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.blue)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .navigationTitle("Select Identity")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    CreateProposeView(
        space: Space(
            id: UUID(),
            name: "Example Space",
            url: "https://api.example.com",
            defaultIdentityID: UUID(),
            orderIndex: 0,
            createdAt: .now,
            updatedAt: .now
        ),
        onSuccess: {}
    )
}
