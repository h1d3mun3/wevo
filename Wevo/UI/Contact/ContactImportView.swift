//
//  ContactImportView.swift
//  Wevo
//
//  Created by hidemune on 3/12/26.
//

import SwiftUI

struct ContactImportView: View {
    let exportData: ContactExportData
    let onComplete: () -> Void
    let onCancel: () -> Void

    @State private var nickname: String
    @State private var errorMessage: String?
    @State private var isImporting = false
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dependencies) private var deps

    init(exportData: ContactExportData, onComplete: @escaping () -> Void, onCancel: @escaping () -> Void) {
        self.exportData = exportData
        self.onComplete = onComplete
        self.onCancel = onCancel
        _nickname = State(initialValue: "")
    }

    private var canImport: Bool {
        !nickname.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isImporting
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Nickname") {
                    TextField("Nickname", text: $nickname)
                }

                Section("Information") {
                    LabeledContent("Exported At") {
                        Text(exportData.exportedAt, format: .dateTime)
                    }
                }

                Section("Public Key") {
                    Text(exportData.publicKey)
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle("Import Contact")
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onCancel()
                        dismiss()
                    }
                    .disabled(isImporting)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Import") { importNow() }
                        .disabled(!canImport)
                }
            }
        }
    }

    private func importNow() {
        isImporting = true
        let useCase = ImportContactFromExportUseCaseImpl(contactRepository: deps.contactRepository)
        do {
            try useCase.execute(exportData: exportData, nickname: nickname)
            isImporting = false
            onComplete()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            isImporting = false
        }
    }
}

#Preview("Contact Import") {
    ContactImportView(
        exportData: ContactExportData(
            version: 1,
            publicKey: "SOME_PUBLIC_KEY",
            exportedAt: .now
        ),
        onComplete: {},
        onCancel: {}
    )
}
