//
//  CreateProposeView.swift
//  Wevo
//
//  Created by hidemune on 3/6/26.
//

import SwiftUI
import os

// MARK: - Container

struct CreateProposeView: View {
    let space: Space
    let onSuccess: () -> Void

    @Environment(\.dependencies) private var deps

    var body: some View {
        CreateProposeContent(
            viewModel: CreateProposeViewModel(space: space, onSuccess: onSuccess, deps: deps)
        )
    }
}

// MARK: - Content

private struct CreateProposeContent: View {
    @State var viewModel: CreateProposeViewModel

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Information") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Space")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(viewModel.space.name)
                            .font(.body)
                    }

                    if let identity = viewModel.selectedIdentity {
                        HStack {
                            Image(systemName: "key.fill")
                                .foregroundStyle(.blue)
                            Text(identity.nickname)
                                .font(.body)
                            Spacer()
                            if viewModel.identities.count > 1 {
                                Button("Change") { viewModel.showIdentityPicker = true }
                                    .buttonStyle(.borderless)
                                    .foregroundStyle(.blue)
                            }
                        }
                    } else {
                        Button {
                            viewModel.showIdentityPicker = true
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
                }

                Section("To（Counterparty）") {
                    if let contact = viewModel.selectedContact {
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
                            Button("Change") { viewModel.showContactPicker = true }
                                .buttonStyle(.borderless)
                                .foregroundStyle(.blue)
                        }
                    } else {
                        Button {
                            viewModel.showContactPicker = true
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
                }

                Section("Propose Message") {
                    TextField("Message", text: $viewModel.message, axis: .vertical)
                        .autocorrectionDisabled()
                        .lineLimit(3...10)
                }

                if let errorMessage = viewModel.errorMessage {
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
                    Button("Cancel") { dismiss() }
                        .disabled(viewModel.isSaving)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        Task { await viewModel.createPropose() }
                    }
                    .disabled(!viewModel.canSave)
                }
            }
            .disabled(viewModel.isSaving)
            .sheet(isPresented: $viewModel.showContactPicker) {
                ContactPickerSheet(selectedContact: $viewModel.selectedContact)
            }
            .sheet(isPresented: $viewModel.showIdentityPicker) {
                IdentityPickerSheet(
                    identities: viewModel.identities,
                    selectedIdentity: $viewModel.selectedIdentity
                )
            }
            .task {
                viewModel.loadIdentities()
            }
            .onChange(of: viewModel.shouldDismiss) { _, should in
                if should { dismiss() }
            }
        }
#if os(macOS)
        .frame(minWidth: 400, minHeight: 500)
#endif
    }
}

// MARK: - ContactPickerSheet

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
                    Button("Cancel") { dismiss() }
                }
            }
            .task {
                loadContacts()
            }
        }
#if os(macOS)
        .frame(minWidth: 360, minHeight: 300)
#endif
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
#if os(macOS)
        .frame(minWidth: 360, minHeight: 300)
#endif
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
