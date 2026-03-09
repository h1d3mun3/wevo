//
//  AddSpaceView.swift
//  Wevo
//
//  Created by hidemune on 3/5/26.
//

import SwiftUI

struct AddSpaceView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

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

    var body: some View {
        NavigationStack {
            Form {
                Section("Space Name") {
                    TextField("Space Name", text: $name)
                }

                Section("Space URL") {
                    TextField("Space URL", text: $urlString)
                }

                Section {
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
                } header: {
                    Text("Default Identity")
                } footer: {
                    if !identities.isEmpty {
                        Text("Select which identity to use for this space.")
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
    }

    private func loadIdentities() async {
        let getAllIdentitiesUseCase = GetAllIdentitiesUseCaseImpl(keychainRepository: KeychainRepositoryImpl())
        do {
            let loadedIdentities = try getAllIdentitiesUseCase.execute()
            await MainActor.run {
                identities = loadedIdentities
                // 最初のIdentityをデフォルトで選択
                if selectedIdentityID == nil, let first = loadedIdentities.first {
                    selectedIdentityID = first.id
                }
            }
        } catch {
            print("❌ Error loading identities: \(error)")
            await MainActor.run {
                identities = []
            }
        }
    }

    private func add() {
        guard canSave else { return }
        
        isSaving = true

        let addSpaceUseCase = AddSpaceUseCaseImpl(spaceRepository: SpaceRepositoryImpl(modelContext: modelContext))

        do {
            try addSpaceUseCase.execute(name: name, urlString: urlString, defaultIdentityID: selectedIdentityID)

            isSaving = false
            dismiss()
        } catch {
            print("❌ Error saving space: \(error)")
            isSaving = false
            // TODO: エラーアラートを表示
        }
    }
}

#Preview {
    AddSpaceView()
}
