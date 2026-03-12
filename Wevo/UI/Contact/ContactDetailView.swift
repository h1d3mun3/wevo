//
//  ContactDetailView.swift
//  Wevo
//
//  Created by hidemune on 3/12/26.
//

import SwiftUI

struct ContactDetailView: View {
    let contact: Contact

    @State private var showingEditSheet = false

    var body: some View {
        List {
            Section("Information") {
                LabeledContent("Nickname", value: contact.nickname)
                LabeledContent("Added", value: contact.createdAt, format: .dateTime.year().month().day())
            }

            Section("Public Key") {
                VStack(alignment: .leading, spacing: 8) {
                    Text(contact.publicKey)
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)

                    Button {
                        #if os(iOS)
                        UIPasteboard.general.string = contact.publicKey
                        #elseif os(macOS)
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(contact.publicKey, forType: .string)
                        #endif
                    } label: {
                        Label("Copy to Clipboard", systemImage: "doc.on.doc")
                    }
                    .buttonStyle(.bordered)
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
        .sheet(isPresented: $showingEditSheet) {
            EditContactView(contact: contact)
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
