//
//  ContactListView.swift
//  Wevo
//
//  Created by hidemune on 3/12/26.
//

import SwiftUI
import os

struct ContactListView: View {
    @Environment(\.dependencies) private var deps

    @State private var contacts: [Contact] = []
    @State private var shouldShowCreateContact = false

    var body: some View {
        NavigationStack {
            List {
                ForEach(contacts) { contact in
                    NavigationLink {
                        ContactDetailView(contact: contact)
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(contact.nickname)
                            Text(contact.publicKey)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                    }
                }
                .onDelete(perform: deleteContacts)

                Button(action: { shouldShowCreateContact = true }) {
                    Text("Add Contact")
                }
            }
            .navigationTitle("Contacts")
            .toolbar {
#if os(iOS)
                ToolbarItem(placement: .navigationBarTrailing) {
                    EditButton()
                }
#endif
            }
            .task {
                loadContacts()
            }
            .onCloudKitImport {
                loadContacts()
            }
        }
        .sheet(isPresented: $shouldShowCreateContact, onDismiss: loadContacts) {
            CreateContactView()
        }
#if os(macOS)
        .frame(minWidth: 400, minHeight: 500)
#endif
    }

    private func loadContacts() {
        let useCase = GetAllContactsUseCaseImpl(contactRepository: deps.contactRepository)
        do {
            contacts = try useCase.execute()
        } catch {
            Logger.contact.error("Error loading contacts: \(error, privacy: .public)")
            contacts = []
        }
    }

    private func deleteContacts(offsets: IndexSet) {
        let useCase = DeleteContactUseCaseImpl(contactRepository: deps.contactRepository)
        do {
            for index in offsets {
                try useCase.execute(id: contacts[index].id)
            }
            loadContacts()
        } catch {
            Logger.contact.error("Error deleting contact: \(error, privacy: .public)")
        }
    }
}

#Preview {
    ContactListView()
}
