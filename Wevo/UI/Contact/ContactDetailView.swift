//
//  ContactDetailView.swift
//  Wevo
//
//  Created by hidemune on 3/12/26.
//

import SwiftUI
import os

struct ContactDetailView: View {
    let contact: Contact

    @Environment(\.dependencies) private var deps
    @Environment(\.dismiss) private var dismiss
    @State private var currentContact: Contact
    @State private var showingEditSheet = false

    init(contact: Contact) {
        self.contact = contact
        _currentContact = State(initialValue: contact)
    }

    var body: some View {
        List {
            Section("Information") {
                LabeledContent("Nickname", value: currentContact.nickname)
                LabeledContent("Added", value: currentContact.createdAt, format: .dateTime.year().month().day())
            }

            Section("Fingerprint") {
                Text(currentContact.fingerprintDisplay)
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
            }

            if let base64 = currentContact.publicKeyBase64 {
                Section("Public Key (base64)") {
                    Text(base64)
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                }
            }

            Section {
                Button {
                    showingEditSheet = true
                } label: {
                    Label("Edit Contact", systemImage: "pencil")
                }
            }
        }
        .navigationTitle("Contact Detail")
#if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
#endif
        .onCloudKitImport {
            reloadContact()
        }
        .sheet(isPresented: $showingEditSheet) {
            EditContactView(contact: currentContact)
        }
    }
    private func reloadContact() {
        let useCase = GetContactUseCaseImpl(contactRepository: deps.contactRepository)
        do {
            currentContact = try useCase.execute(id: contact.id)
        } catch ContactRepositoryError.contactNotFound {
            dismiss()
        } catch {
            Logger.contact.error("Failed to reload contact: \(error, privacy: .public)")
        }
    }
}

#Preview("Contact Detail") {
    NavigationStack {
        ContactDetailView(contact: Contact(
            id: UUID(),
            nickname: "Alice",
            publicKey: "SOME PUBLIC KEY",
            createdAt: .now
        ))
    }
}
