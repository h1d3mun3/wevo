//
//  EditIdentityView.swift
//  Wevo
//
//  Created by hidemune on 3/9/26.
//

import SwiftUI

struct EditIdentityView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dependencies) private var deps

    let identity: Identity
    @State private var nickname: String
    @State private var isSaving = false
    @State private var errorMessage: String?
    
    init(identity: Identity) {
        self.identity = identity
        _nickname = State(initialValue: identity.nickname)
    }
    
    private var canSave: Bool {
        !nickname.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        nickname != identity.nickname &&
        !isSaving
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Nickname") {
                    TextField("Nickname", text: $nickname)
                }
                
                if let errorMessage = errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle("Edit Identity")
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
                            await save()
                        }
                    }
                    .disabled(!canSave)
                }
            }
        }
#if os(macOS)
        .frame(minWidth: 360, minHeight: 240)
#endif
    }
    
    private func save() async {
        isSaving = true
        errorMessage = nil
        
        let useCase = EditIdentityUseCaseImpl(keychainRepository: deps.keychainRepository)
        
        do {
            try useCase.execute(id: identity.id, newNickname: nickname)
            
            await MainActor.run {
                isSaving = false
                dismiss()
            }
        } catch {
            await MainActor.run {
                errorMessage = "Failed to update: \(error.localizedDescription)"
                isSaving = false
            }
        }
    }
}

#Preview("Edit Identity") {
    EditIdentityView(identity: Identity(
        id: UUID(),
        nickname: "My Identity",
        publicKey: "SOME PUBLIC KEY"
    ))
}
