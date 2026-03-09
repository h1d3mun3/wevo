//
//  CreateIdentityView.swift
//  Wevo
//
//  Created by hidemune on 3/5/26.
//

import SwiftUI

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
        
        let useCase = CreateIdentityUseCaseImpl(keychainRepository: KeychainRepositoryImpl())
        
        Task {
            do {
                try useCase.execute(nickname: nickname)
                
                await MainActor.run {
                    isSaving = false
                    dismiss()
                }
            } catch {
                print("❌ Error saving identity key: \(error)")
                await MainActor.run {
                    isSaving = false
                }
            }
        }
    }
}

#Preview {
    CreateIdentityView()
}
