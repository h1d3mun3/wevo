//
//  ContactListView.swift
//  Wevo
//
//  Created by hidemune on 3/12/26.
//

import SwiftUI

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
        }
        .sheet(isPresented: $shouldShowCreateContact, onDismiss: loadContacts) {
            CreateContactView()
        }
    }

    private func loadContacts() {
        let useCase = GetAllContactsUseCaseImpl(contactRepository: deps.contactRepository)
        do {
            contacts = try useCase.execute()
        } catch {
            print("❌ Error loading contacts: \(error)")
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
            print("❌ Error deleting contact: \(error)")
        }
    }
}

#Preview {
    ContactListView()
}
