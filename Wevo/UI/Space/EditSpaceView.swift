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
    }

    private func loadIdentities() {
        let useCase = GetAllIdentitiesUseCaseImpl(keychainRepository: deps.keychainRepository)
        do {
            let all = try useCase.execute()
            identities = all
            selectedIdentity = all.first { $0.id == space.defaultIdentityID }
        } catch {
            Logger.identity.error("Error loading identities: \(error, privacy: .public)")
        }
    }

    private func saveChanges() async {
        let editSpaceUseCase = EditSpaceUseCaseImpl(
            spaceRepository: deps.spaceRepository,
            getSpaceUseCase: GetSpaceUseCaseImpl(
                spaceRepository: deps.spaceRepository
            )
        )

        await MainActor.run {
            isSaving = true
            errorMessage = nil
        }

        // Re-discover peers from the (possibly updated) primary URL.
        // If unreachable, preserve the existing peer list or fall back to the entered URL alone.
        let primaryURL = url.trimmingCharacters(in: .whitespacesAndNewlines)
        var allURLs = [primaryURL]
        let fetchInfo = FetchServerInfoUseCaseImpl()
        if let info = try? await fetchInfo.execute(urlString: primaryURL) {
            let peers = info.peers.filter { $0 != primaryURL }
            allURLs.append(contentsOf: peers)
        } else if space.urls.count > 1 {
            // Keep known peers if /info is temporarily unreachable
            allURLs = space.urls.map {
                $0 == space.url ? primaryURL : $0
            }
        }

        do {
            try editSpaceUseCase.execute(
                id: space.id,
                name: name,
                urls: allURLs,
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
