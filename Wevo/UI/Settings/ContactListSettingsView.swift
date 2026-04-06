//
//  ContactListSettingsView.swift
//  Wevo
//

import SwiftUI
import os

struct ContactListSettingsView: View {
    let contacts: [Contact]
    @Environment(\.dependencies) private var deps

    var onDelete: () -> Void = {}

    var body: some View {
        List {
            if contacts.isEmpty {
                Text("No contacts in database")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
            } else {
                ForEach(contacts) { contact in
                    NavigationLink {
                        ContactDetailView(contact: contact)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(contact.nickname)
                                .font(.headline)

                            Text(contact.fingerprintDisplay)
                                .font(.caption)
                                .fontDesign(.monospaced)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                }
                .onDelete { indexSet in
                    for index in indexSet {
                        deleteContact(contacts[index])
                    }
                }
            }
        }
        .listStyle(.plain)
    }

    private func deleteContact(_ contact: Contact) {
        let useCase = DeleteContactUseCaseImpl(contactRepository: deps.contactRepository)
        do {
            try useCase.execute(id: contact.id)
            Logger.contact.info("Contact deleted: \(contact.id, privacy: .private)")
            onDelete()
        } catch {
            Logger.contact.error("Error deleting contact: \(error, privacy: .public)")
        }
    }
}

#Preview("Contact List Settings") {
    ContactListSettingsView(contacts: [])
}
