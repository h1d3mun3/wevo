import SwiftUI

struct IdentityImportView: View {
    let exportData: IdentityPlainExport
    let onComplete: () -> Void
    let onCancel: () -> Void

    @State private var loadError: String?
    @State private var isImporting = false
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dependencies) private var deps

    init(exportData: IdentityPlainExport, onComplete: @escaping () -> Void, onCancel: @escaping () -> Void) {
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
                Section("Private Key (Base64)") {
                    Text(exportData.privateKey)
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
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
                    Button("Import") { Task { await importNow() } }
                }
            }
        }
    }

    private func importNow() async {
        isImporting = true
        let useCase = ImportIdentityFromExportUseCaseImpl(keychainRepository: deps.keychainRepository)
        do {
            try useCase.execute(exportData: exportData)
            isImporting = false
            onComplete()
            dismiss()
        } catch {
            isImporting = false
            loadError = error.localizedDescription
        }
    }
}

#Preview("Identity Import") {
    let exportData = IdentityPlainExport(
        id: UUID(),
        nickname: "Preview Key",
        publicKey: "PreviewPublicKey",
        privateKey: "PreviewPrivateKeyBase64",
        exportedAt: .now
    )

    IdentityImportView(
        exportData: exportData,
        onComplete: {},
        onCancel: {}
    )
}
