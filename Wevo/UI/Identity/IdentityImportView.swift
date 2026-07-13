import SwiftUI

struct IdentityImportView: View {
    let exportData: IdentityEncryptedExport
    let onComplete: () -> Void
    let onCancel: () -> Void

    @State private var passphrase = ""
    @State private var loadError: String?
    @State private var isImporting = false
    @State private var showOverwriteConfirm = false
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dependencies) private var deps

    init(exportData: IdentityEncryptedExport, onComplete: @escaping () -> Void, onCancel: @escaping () -> Void) {
        self.exportData = exportData
        self.onComplete = onComplete
        self.onCancel = onCancel
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Information") {
                    LabeledContent("Nickname", value: exportData.nickname)
                    LabeledContent("ID", value: exportData.id.uuidString)
                        .font(.system(.caption, design: .monospaced))
                    LabeledContent("Exported At") { Text(exportData.exportedAt, format: .dateTime) }
                }
                Section("Public Key") {
                    Text(exportData.publicKey)
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                }
                Section("Private Key") {
                    Text(String(repeating: "•", count: 32))
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                Section {
                    SecureField("Passphrase", text: $passphrase)
                } header: {
                    Text("Passphrase")
                } footer: {
                    Text("Enter the passphrase this identity was exported with.")
                }
                if let loadError = loadError {
                    Section {
                        Text(loadError)
                            .foregroundStyle(.red)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle("Import Identity")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onCancel(); dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Import") { Task { await performImport(overwriteConfirmed: false) } }
                        .disabled(passphrase.isEmpty || isImporting)
                }
            }
            .alert("Replace existing identity?", isPresented: $showOverwriteConfirm) {
                Button("Replace", role: .destructive) {
                    Task { await performImport(overwriteConfirmed: true) }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("An identity with this ID already exists on this device. Importing will replace its private key. This cannot be undone.")
            }
        }
#if os(macOS)
        .frame(minWidth: 400, minHeight: 400)
#endif
    }

    private func performImport(overwriteConfirmed: Bool) async {
        isImporting = true
        let useCase = ImportIdentityFromExportUseCaseImpl(keychainRepository: deps.keychainRepository)
        do {
            try useCase.execute(exportData: exportData, passphrase: passphrase, overwriteConfirmed: overwriteConfirmed)
            isImporting = false
            onComplete()
            dismiss()
        } catch ImportIdentityFromExportUseCaseError.identityAlreadyExists {
            isImporting = false
            showOverwriteConfirm = true
        } catch {
            isImporting = false
            loadError = error.localizedDescription
        }
    }
}

#Preview("Identity Import") {
    let exportData = IdentityEncryptedExport(
        version: IdentityEncryptedExport.currentVersion,
        id: UUID(),
        nickname: "Preview Key",
        publicKey: "PreviewPublicKey",
        exportedAt: .now,
        kdf: IdentityEncryptedExport.kdfName,
        iterations: IdentityExportCrypto.iterations,
        salt: "cHJldmlld3NhbHQ=",
        sealed: "cHJldmlld3NlYWxlZA=="
    )

    IdentityImportView(
        exportData: exportData,
        onComplete: {},
        onCancel: {}
    )
}
