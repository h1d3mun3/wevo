//
//  CreateIdentityView.swift
//  Wevo
//
//  Created by hidemune on 3/5/26.
//

import SwiftUI
import CryptoKit

struct CreateIdentityView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var nickname: String = ""

    private var canSave: Bool {
        !nickname.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isSaving
    }
    @State private var isSaving: Bool = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Nickname") {
                    TextField("Specify Key Nickname", text: $nickname)
                }
            }
            .navigationTitle("Create Identity")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .disabled(isSaving)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create Identity") {
                        create()
                    }
                    .disabled(!canSave)
                }
            }
        }
    }

    private func create() {
        isSaving = true
        
        Task {
            do {
                // P256鍵ペアの生成（SecureEnclave対応のため）
                let privateKey = P256.Signing.PrivateKey()
                let privateKeyData = privateKey.rawRepresentation
                
                // Keychainに保存
                let id = UUID()
                let trimmedNickname = nickname.trimmingCharacters(in: .whitespacesAndNewlines)
                try KeychainRepositoryImpl.shared.createIdentity(
                    id: id,
                    nickname: trimmedNickname,
                    privateKey: privateKeyData
                )
                
                // 公開鍵をログ出力（デバッグ用）
                let publicKeyData = privateKey.publicKey.rawRepresentation
                
                print("✅ Identity Key saved successfully")
                print("ID: \(id)")
                print("Nickname: \(trimmedNickname)")
                print("Public Key: \(publicKeyData.base64EncodedString())")
                
                await MainActor.run {
                    isSaving = false
                    dismiss()
                }
            } catch {
                print("❌ Error saving identity key: \(error)")
                await MainActor.run {
                    isSaving = false
                }
                // TODO: エラーをユーザーに表示
            }
        }
    }
}

#Preview {
    CreateIdentityView()
}
