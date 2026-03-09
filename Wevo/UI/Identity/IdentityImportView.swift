import SwiftUI

struct IdentityImportView: View {
    let exportData: IdentityPlainExport
    let onComplete: () -> Void
    let onCancel: () -> Void

    @State private var loadError: String?
    @State private var isImporting = false
    @Environment(\.dismiss) private var dismiss

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
        let getIdentityUseCase = GetIdentityUseCaseImpl(keychainRepository: KeychainRepositoryImpl())
        let deleteIdentityUseCase = DeleteIdentityUseCaseImpl(keychainRepository: KeychainRepositoryImpl())
        do {
            // Overwrite existing identity if present: delete then create
            do {

                _ = try getIdentityUseCase.execute(id: exportData.id)
                try deleteIdentityUseCase.execute(id: exportData.id)
            } catch {
                // Not found or deletable; continue
            }
            // Convert base64 private key back to raw data
            guard let privateKeyData = Data(base64Encoded: exportData.privateKey) else {
                throw NSError(domain: "Wevo", code: -2, userInfo: [NSLocalizedDescriptionKey: "Invalid private key encoding."])
            }
            // TODO: ここはUseCase切り出しが難しいので直参照をOKにする
            try KeychainRepositoryImpl().createIdentity(id: exportData.id, nickname: exportData.nickname, privateKey: privateKeyData)
            isImporting = false
            onComplete()
            dismiss()
        } catch {
            isImporting = false
            loadError = error.localizedDescription
        }
    }
}
