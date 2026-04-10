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
                        add()
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
        let useCase = LoadIdentitiesWithDefaultSelectionUseCaseImpl(keychainRepository: deps.keychainRepository)
        do {
            let (loadedIdentities, defaultSelectedID) = try useCase.execute()
            await MainActor.run {
                identities = loadedIdentities
                if selectedIdentityID == nil {
                    selectedIdentityID = defaultSelectedID
                }
            }
        } catch {
            Logger.identity.error("Error loading identities: \(error, privacy: .public)")
            await MainActor.run {
                identities = []
            }
        }
    }

    private func add() {
        guard canSave else { return }

        isSaving = true

        Task {
            // Discover peers from the entered URL's /info endpoint.
            // If unreachable, proceed with only the entered URL (graceful degradation).
            let primaryURL = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
            var allURLs = [primaryURL]
            let fetchInfo = FetchServerInfoUseCaseImpl()
            if let info = try? await fetchInfo.execute(urlString: primaryURL) {
                let peers = info.peers.filter { $0 != primaryURL }
                allURLs.append(contentsOf: peers)
            }

            let addSpaceUseCase = AddSpaceUseCaseImpl(spaceRepository: deps.spaceRepository)
            do {
                try addSpaceUseCase.execute(name: name, urls: allURLs, defaultIdentityID: selectedIdentityID)
                await MainActor.run { isSaving = false; dismiss() }
            } catch {
                Logger.space.error("Error saving space: \(error, privacy: .public)")
                await MainActor.run { isSaving = false; saveError = error.localizedDescription }
            }
        }
    }
}

#Preview {
    AddSpaceView()
}
