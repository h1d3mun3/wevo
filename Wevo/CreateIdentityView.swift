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
                // Curve25519鍵ペアの生成
                let privateKey = Curve25519.KeyAgreement.PrivateKey()
                let privateKeyData = privateKey.rawRepresentation
                
                // IdentityKeyItemを作成（秘密鍵のみ保存）
                let item = IdentityKeyChainItem(
                    id: UUID(),
                    nickname: nickname.trimmingCharacters(in: .whitespacesAndNewlines),
                    privateKey: privateKeyData
                )
                
                // Keychainに保存
                try KeychainRepository.shared.saveIdentityKey(item)
                
                // 公開鍵は必要なときに導出
                let publicKeyData = try item.publicKey
                
                print("✅ Identity Key saved successfully")
                print("ID: \(item.id)")
                print("Nickname: \(item.nickname)")
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
