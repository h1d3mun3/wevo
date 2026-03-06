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
    
    @State private var payloadHash: String = ""
    @State private var isSaving: Bool = false
    @State private var errorMessage: String?
    
    private var canSave: Bool {
        !payloadHash.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isSaving
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
                    TextField("Payload Hash", text: $payloadHash)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        #if os(iOS)
                        .keyboardType(.asciiCapable)
                        #endif
                } header: {
                    Text("Propose Data")
                } footer: {
                    Text("Enter the hash of the payload you want to propose. This will be signed with your identity.")
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
        let trimmedHash = payloadHash.trimmingCharacters(in: .whitespacesAndNewlines)
        
        await MainActor.run {
            isSaving = true
            errorMessage = nil
        }
        
        do {
            // URLを作成
            guard let baseURL = URL(string: space.url) else {
                await MainActor.run {
                    errorMessage = "Invalid server URL: \(space.url)"
                    isSaving = false
                }
                return
            }
            
            // 署名を作成（生体認証が必要）
            let signature = try KeychainRepository.shared.signMessage(
                trimmedHash,
                withIdentityId: identity.id
            )
            
            // 公開鍵をBase64エンコード
            let publicKeyString = identity.publicKey.base64EncodedString()
            
            // ProposeInputを作成
            let proposeID = UUID()
            let input = ProposeAPIClient.ProposeInput(
                id: proposeID,
                payloadHash: trimmedHash,
                publicKey: publicKeyString,
                signature: signature
            )
            
            // APIクライアントで送信
            let client = ProposeAPIClient(baseURL: baseURL)
            try await client.createPropose(input: input)
            
            print("✅ Propose created successfully: \(proposeID)")
            
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
            orderIndex: 0
        ),
        identity: Identity(
            id: UUID(),
            nickname: "My Key",
            publicKey: Data()
        ),
        onSuccess: {}
    )
}
