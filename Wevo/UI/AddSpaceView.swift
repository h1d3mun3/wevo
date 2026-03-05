//
//  AddSpaceView.swift
//  Wevo
//
//  Created by hidemune on 3/5/26.
//

import SwiftUI

struct AddSpaceView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var serverURL: String = ""
    @State private var identities: [Identity] = []
    @State private var selectedIdentityID: UUID?

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && 
        !serverURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
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

                Section("Server URL") {
                    TextField("Server URL", text: $serverURL)
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
        do {
            let items = try KeychainRepository.shared.getAllIdentityKeys()
            let loadedIdentities = items.map { item in
                Identity(id: item.id, nickname: item.nickname)
            }
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
        // TODO: Spaceの保存処理を実装
    }
}

#Preview {
    AddSpaceView()
}
