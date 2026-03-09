//
//  CreateProposeView.swift
//  Wevo
//
//  Created by hidemune on 3/6/26.
//

import SwiftUI
import CryptoKit

struct CreateProposeView: View {
    let space: Space
    let identity: Identity
    let onSuccess: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @State private var message: String = ""
    @State private var isSaving: Bool = false
    @State private var errorMessage: String?
    
    private var canSave: Bool {
        !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isSaving
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Space")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(space.name)
                            .font(.body)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Identity")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        HStack {
                            Image(systemName: "key.fill")
                                .foregroundStyle(.blue)
                            Text(identity.nickname)
                                .font(.body)
                        }
                    }
                } header: {
                    Text("Information")
                }
                
                Section {
                    TextField("Message", text: $message, axis: .vertical)
                        .autocorrectionDisabled()
                        .lineLimit(3...10)
                } header: {
                    Text("Propose Message")
                } footer: {
                    Text("Enter the message you want to propose. This will be hashed and signed with your identity.")
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
        }
    }
    
    private func createPropose() async {
        await MainActor.run {
            isSaving = true
            errorMessage = nil
        }

        let createProposeUseCaseImpl = CreateProposeUseCaseImpl(
            keychainRepository: KeychainRepositoryImpl(),
            spaceRepository: SpaceRepositoryImpl(modelContext: modelContext),
            proposeRepository: ProposeRepositoryImpl(modelContext: modelContext)
        )

        do {
            try await createProposeUseCaseImpl.execute(identityID: identity.id, spaceID: space.id, message: message)

            // 結果に関わらず画面を閉じる
            await MainActor.run {
                isSaving = false
                onSuccess()
                dismiss()
            }
            
        } catch {
            print("❌ Error creating propose: \(error)")
            await MainActor.run {
                errorMessage = "Failed to create propose: \(error.localizedDescription)"
                isSaving = false
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
        identity: Identity(
            id: UUID(),
            nickname: "My Key",
            publicKey: "SOME PUBLIC KEY"
        ),
        onSuccess: {}
    )
}
