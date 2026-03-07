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
                        .textInputAutocapitalization(.never)
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
        let trimmedMessage = message.trimmingCharacters(in: .whitespacesAndNewlines)
        
        await MainActor.run {
            isSaving = true
            errorMessage = nil
        }
        
        do {
            // ProposeIDを生成
            let proposeID = UUID()
            
            // メッセージからPropose作成（自動的にハッシュ化される）
            let propose = Propose(
                id: proposeID,
                message: message,
                signatures: [],
                createdAt: Date(),
                updatedAt: Date()
            )

            // 署名を作成（ハッシュ化されたメッセージに対して署名）
            let signature = try KeychainRepository.shared.signMessage(
                propose.payloadHash,
                withIdentityId: identity.id
            )

            // Signatureエンティティを作成
            let signatureEntity = Signature(
                id: UUID(),
                publicKey: identity.publicKey,
                signature: signature,
                createdAt: Date()
            )
            
            // Proposeに署名を追加
            let signedPropose = Propose(
                id: propose.id,
                message: propose.message,
                signatures: [signatureEntity],
                createdAt: Date(),
                updatedAt: Date()
            )
            
            // 1. 先にローカル（SwiftData）に保存（元のメッセージを含む）
            await MainActor.run {
                let repository = ProposeRepository(modelContext: modelContext)
                do {
                    try repository.create(signedPropose, spaceID: space.id)
                    print("✅ Propose saved to SwiftData: \(proposeID)")
                    print("   Message: \(trimmedMessage)")
                    print("   Hash: \(propose.payloadHash)")
                } catch {
                    print("❌ Failed to save propose to SwiftData: \(error)")
                    // ローカル保存失敗時はエラーを表示
                    errorMessage = "Failed to save locally: \(error.localizedDescription)"
                    isSaving = false
                    return
                }
            }
            
            // 2. その後、APIに送信（ハッシュのみ、失敗しても画面は閉じる）
            guard let baseURL = URL(string: space.url) else {
                print("⚠️ Invalid server URL: \(space.url)")
                await MainActor.run {
                    isSaving = false
                    onSuccess()
                    dismiss()
                }
                return
            }

            // ProposeInputを作成（ハッシュのみ送信）
            let input = ProposeAPIClient.ProposeInput(
                id: proposeID,
                payloadHash: signedPropose.payloadHash,
                publicKey: identity.publicKey,
                signatures: [.init(publicKey: identity.publicKey, signature: signature)]
            )
            
            do {
                // APIクライアントで送信
                let client = ProposeAPIClient(baseURL: baseURL)
                try await client.createPropose(input: input)
                
                print("✅ Propose sent to API successfully: \(proposeID)")
                print("   Only hash sent: \(signedPropose.payloadHash)")
            } catch {
                // API送信に失敗してもローカルには保存済みなので警告のみ
                print("⚠️ Failed to send propose to API: \(error)")
                print("ℹ️ Propose is saved locally and can be synced later")
            }
            
            // API送信の成否に関わらず画面を閉じる
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
