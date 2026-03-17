//
//  EditContactView.swift
//  Wevo
//
//  Created by hidemune on 3/12/26.
//

import SwiftUI
import os

struct EditContactView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dependencies) private var deps

    let contact: Contact
    @State private var nickname: String
    @State private var publicKey: String
    @State private var isSaving = false
    @State private var errorMessage: String?

    init(contact: Contact) {
        self.contact = contact
        _nickname = State(initialValue: contact.nickname)
        _publicKey = State(initialValue: contact.publicKey)
    }

    private var canSave: Bool {
        let trimmedNickname = nickname.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedPublicKey = publicKey.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmedNickname.isEmpty &&
               !trimmedPublicKey.isEmpty &&
               (trimmedNickname != contact.nickname || trimmedPublicKey != contact.publicKey) &&
               !isSaving
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Nickname") {
                    TextField("Nickname", text: $nickname)
                }

                Section("Public Key") {
                    TextField("Public key", text: $publicKey, axis: .vertical)
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
            .navigationTitle("Edit Contact")
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .disabled(isSaving)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(!canSave)
                }
            }
        }
    }

    private func save() {
        isSaving = true
        errorMessage = nil

        let useCase = EditContactUseCaseImpl(
            contactRepository: deps.contactRepository,
            getContactUseCase: GetContactUseCaseImpl(contactRepository: deps.contactRepository)
        )

        do {
            try useCase.execute(id: contact.id, nickname: nickname, publicKey: publicKey)
            dismiss()
        } catch {
            Logger.contact.error("Error editing contact: \(error, privacy: .public)")
            errorMessage = "Failed to update: \(error.localizedDescription)"
            isSaving = false
        }
    }
}

#Preview("Edit Contact") {
    EditContactView(contact: Contact(
        id: UUID(),
        nickname: "Alice",
        publicKey: "SOME PUBLIC KEY",
        createdAt: .now
    ))
}
