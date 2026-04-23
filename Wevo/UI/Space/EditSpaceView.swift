//
//  EditSpaceView.swift
//  Wevo
//
//  Created by hidemune on 3/7/26.
//

import SwiftUI
import os

struct EditSpaceView: View {
    let space: Space
    let onUpdate: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.dependencies) private var deps

    @State private var name: String
    @State private var url: String
    @State private var isSaving: Bool = false
    @State private var errorMessage: String?
    @State private var identities: [Identity] = []
    @State private var selectedIdentity: Identity?
    @State private var showIdentityPicker = false

    init(space: Space, onUpdate: @escaping () -> Void) {
        self.space = space
        self.onUpdate = onUpdate
        _name = State(initialValue: space.name)
        _url = State(initialValue: space.url)
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !url.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !isSaving &&
        (name != space.name || url != space.url || selectedIdentity?.id != space.defaultIdentityID)
    }

    private var editSpaceUseCase: any EditSpaceUseCase {
        EditSpaceUseCaseImpl(
            spaceRepository: deps.spaceRepository,
            getSpaceUseCase: GetSpaceUseCaseImpl(spaceRepository: deps.spaceRepository)
        )
    }
    private var getAllIdentitiesUseCase: any GetAllIdentitiesUseCase {
        GetAllIdentitiesUseCaseImpl(keychainRepository: deps.keychainRepository)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("Space Name", text: $name)
                }

                Section("Server URL") {
                    TextField("Server URL", text: $url)
                        .autocorrectionDisabled()
                        #if os(iOS)
                        .keyboardType(.URL)
                        #endif
                }

                Section("Default Key") {
                    HStack {
                        if let identity = selectedIdentity {
                            Text(identity.nickname)
                                .font(.body)
                        } else {
                            Text("None")
                                .foregroundStyle(.tertiary)
                        }
                        Spacer()
                        Button("Change") { showIdentityPicker = true }
                            .buttonStyle(.borderless)
                            .foregroundStyle(.blue)
                    }
                }

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
            .navigationTitle("Edit Space")
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
                    Button("Save") {
                        Task {
                            await saveChanges()
                        }
                    }
                    .disabled(!canSave)
                }
            }
            .disabled(isSaving)
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
        .frame(minWidth: 400, minHeight: 450)
#endif
    }

    private func loadIdentities() {
        do {
            let all = try getAllIdentitiesUseCase.execute()
            identities = all
            selectedIdentity = all.first { $0.id == space.defaultIdentityID }
        } catch {
            Logger.identity.error("Error loading identities: \(error, privacy: .public)")
        }
    }

    private func saveChanges() async {
        isSaving = true
        errorMessage = nil
        do {
            try await editSpaceUseCase.execute(
                id: space.id,
                name: name,
                primaryURL: url,
                defaultIdentityID: selectedIdentity?.id
            )
            isSaving = false
            onUpdate()
            dismiss()
        } catch {
            Logger.space.error("Failed to update space: \(error, privacy: .public)")
            errorMessage = "Failed to save: \(error.localizedDescription)"
            isSaving = false
        }
    }
}

// MARK: - Preview

#Preview {
    EditSpaceView(
        space: Space(
            id: UUID(),
            name: "Example Space",
            url: "https://api.example.com",
            defaultIdentityID: UUID(),
            orderIndex: 0,
            createdAt: .now,
            updatedAt: .now
        ),
        onUpdate: {}
    )
}
