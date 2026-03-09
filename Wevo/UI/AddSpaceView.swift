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
        do {
            let loadedIdentities = try KeychainRepositoryImpl.shared.getAllIdentities()
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
        
        // URLの妥当性チェック（オプショナル）
        let trimmedURL = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 既存のSpaceの数を取得してorderIndexを決定
        let repository = SpaceRepositoryImpl(modelContext: modelContext)
        let orderIndex: Int
        do {
            let existingSpaces = try repository.fetchAll()
            orderIndex = existingSpaces.count
        } catch {
            print("❌ Error fetching spaces: \(error)")
            orderIndex = 0
        }
        
        // Spaceエンティティの作成
        let space = Space(
            id: UUID(),
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            url: trimmedURL,
            defaultIdentityID: selectedIdentityID,
            orderIndex: orderIndex,
            createdAt: .now,
            updatedAt: .now
        )
        
        // SwiftDataに保存
        do {
            try repository.create(space)
            print("✅ Space saved: \(space.name)")
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
