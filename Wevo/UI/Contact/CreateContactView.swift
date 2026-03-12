//
//  CreateContactView.swift
//  Wevo
//
//  Created by hidemune on 3/12/26.
//

import SwiftUI

struct CreateContactView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dependencies) private var deps

    @State private var nickname: String = ""
    @State private var publicKey: String = ""
    @State private var isSaving = false
    @State private var errorMessage: String?

    private var canSave: Bool {
        !nickname.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !publicKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !isSaving
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Nickname") {
                    TextField("e.g. Alice", text: $nickname)
                }

                Section("Public Key") {
                    TextField("Paste public key here", text: $publicKey, axis: .vertical)
                        .font(.system(.caption, design: .monospaced))
                        .lineLimit(3...6)
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle("Add Contact")
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .disabled(isSaving)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { save() }
                        .disabled(!canSave)
                }
            }
        }
    }

    private func save() {
        isSaving = true
        errorMessage = nil

        let useCase = CreateContactUseCaseImpl(contactRepository: deps.contactRepository)

        do {
            try useCase.execute(nickname: nickname, publicKey: publicKey)
            dismiss()
        } catch {
            print("❌ Error creating contact: \(error)")
            errorMessage = "Failed to save: \(error.localizedDescription)"
            isSaving = false
        }
    }
}

#Preview {
    CreateContactView()
}
