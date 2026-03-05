//
//  CreateIdentityKeyView.swift
//  Wevo
//
//  Created by hidemune on 3/5/26.
//

import SwiftUI

struct CreateIdentityKeyView: View {
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
            .navigationTitle("Create IdentityKey")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .disabled(isSaving)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create Key") {
                        create()
                    }
                    .disabled(!canSave)
                }
            }
        }
    }

    private func create() {

    }
}

#Preview {
    CreateIdentityKeyView()
}
