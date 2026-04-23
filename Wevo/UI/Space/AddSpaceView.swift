//
//  AddSpaceView.swift
//  Wevo
//
//  Created by hidemune on 3/5/26.
//

import SwiftUI
import os

struct AddSpaceView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dependencies) private var deps

    @State private var name: String = ""
    @State private var urlString: String = ""
    @State private var identities: [Identity] = []
    @State private var selectedIdentityID: UUID?

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !urlString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        selectedIdentityID != nil &&
        !isSaving
    }
    @State private var isSaving: Bool = false
    @State private var saveError: String?

    private var addSpaceUseCase: any AddSpaceUseCase {
        AddSpaceUseCaseImpl(spaceRepository: deps.spaceRepository)
    }
    private var loadIdentitiesUseCase: any LoadIdentitiesWithDefaultSelectionUseCase {
        LoadIdentitiesWithDefaultSelectionUseCaseImpl(keychainRepository: deps.keychainRepository)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Space Name") {
                    TextField("Space Name", text: $name)
                }

                Section("Space URL") {
                    TextField("Space URL", text: $urlString)
                }

                Section("Default Identity") {
                    if identities.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("No identities available")
                                .foregroundStyle(.secondary)
                            Text("Create an identity first to add a space.")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.vertical, 4)
                    } else {
                        Picker("Default Identity", selection: $selectedIdentityID) {
                            Text("None").tag(nil as UUID?)
                            ForEach(identities) { identity in
                                Text(identity.nickname).tag(identity.id as UUID?)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Add Space")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .disabled(isSaving)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add Space") {
                        Task { await add() }
                    }
                    .disabled(!canSave)
                }
            }
            .task {
                await loadIdentities()
            }
        }
        .alert("Error", isPresented: .init(
            get: { saveError != nil },
            set: { if !$0 { saveError = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(saveError ?? "")
        }
#if os(macOS)
        .frame(minWidth: 400, minHeight: 450)
#endif
    }

    private func loadIdentities() async {
        do {
            let (loadedIdentities, defaultSelectedID) = try loadIdentitiesUseCase.execute()
            await MainActor.run {
                identities = loadedIdentities
                if selectedIdentityID == nil {
                    selectedIdentityID = defaultSelectedID
                }
            }
        } catch {
            Logger.identity.error("Error loading identities: \(error, privacy: .public)")
            await MainActor.run { identities = [] }
        }
    }

    private func add() async {
        guard canSave else { return }
        isSaving = true
        do {
            try await addSpaceUseCase.execute(name: name, primaryURL: urlString, defaultIdentityID: selectedIdentityID)
            await MainActor.run { isSaving = false; dismiss() }
        } catch {
            Logger.space.error("Error saving space: \(error, privacy: .public)")
            await MainActor.run { isSaving = false; saveError = error.localizedDescription }
        }
    }
}

#Preview {
    AddSpaceView()
}
