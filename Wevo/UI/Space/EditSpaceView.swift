//
//  EditSpaceView.swift
//  Wevo
//
//  Created by hidemune on 3/7/26.
//

import SwiftUI
import SwiftData

struct EditSpaceView: View {
    let space: Space
    let onUpdate: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @State private var name: String
    @State private var url: String
    @State private var isSaving: Bool = false
    @State private var errorMessage: String?
    
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
        (name != space.name || url != space.url)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Space Name", text: $name)
                } header: {
                    Text("Name")
                } footer: {
                    Text("Enter a friendly name for this space")
                }
                
                Section {
                    TextField("Server URL", text: $url)
                        .autocorrectionDisabled()
                        #if os(iOS)
                        .keyboardType(.URL)
                        #endif
                } header: {
                    Text("Server URL")
                } footer: {
                    Text("Enter the base URL of the WevoSpace server (e.g., https://api.example.com)")
                }
                
                Section {
                    HStack {
                        Text("Default Key")
                            .foregroundStyle(.secondary)
                        Spacer()
                        if let defaultIdentityID = space.defaultIdentityID {
                            Text(getIdentityNickname(for: defaultIdentityID))
                                .foregroundStyle(.primary)
                        } else {
                            Text("None")
                                .foregroundStyle(.tertiary)
                        }
                    }
                } footer: {
                    Text("The default key is set when creating the space and cannot be changed here")
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
        }
    }
    
    private func saveChanges() async {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedURL = url.trimmingCharacters(in: .whitespacesAndNewlines)
        
        await MainActor.run {
            isSaving = true
            errorMessage = nil
        }

        // URLの妥当性を確認
        guard URL(string: trimmedURL) != nil else {
            await MainActor.run {
                errorMessage = "Invalid URL format"
                isSaving = false
            }
            return
        }

        // 更新されたSpaceを作成
        let updatedSpace = Space(
            id: space.id,
            name: trimmedName,
            url: trimmedURL,
            defaultIdentityID: space.defaultIdentityID,
            orderIndex: space.orderIndex,
            createdAt: space.createdAt,
            updatedAt: .now
        )

        // リポジトリで更新
        await MainActor.run {
            let repository = SpaceRepositoryImpl(modelContext: modelContext)
            do {
                try repository.update(updatedSpace)
                print("✅ Space updated successfully: \(updatedSpace.name)")

                isSaving = false
                onUpdate()
                dismiss()
            } catch {
                print("❌ Failed to update space: \(error)")
                errorMessage = "Failed to save: \(error.localizedDescription)"
                isSaving = false
            }
        }
    }

    private func getIdentityNickname(for id: UUID) -> String {
        do {
            let identities = try KeychainRepositoryImpl().getAllIdentities()
            if let identity = identities.first(where: { $0.id == id }) {
                return identity.nickname
            }
        } catch {
            print("❌ Error loading identities: \(error)")
        }
        return "Unknown"
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
