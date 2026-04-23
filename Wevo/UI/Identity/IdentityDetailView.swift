//
//  IdentityDetailView.swift
//  Wevo
//
//  Created by hidemune on 3/6/26.
//

import SwiftUI

struct IdentityDetailView: View {
    let identity: Identity

    @Environment(\.dependencies) private var deps

    private var authenticateAndExportUseCase: any AuthenticateAndExportIdentityUseCase {
        AuthenticateAndExportIdentityUseCaseImpl(keychainRepository: deps.keychainRepository)
    }
    private var exportIdentityAsContactUseCase: any ExportIdentityAsContactUseCase {
        ExportIdentityAsContactUseCaseImpl()
    }
    private var cleanupExportFileUseCase: any CleanupExportFileUseCase {
        CleanupExportFileUseCaseImpl()
    }

    @State private var errorMessage: String?
    @State private var exportError: String?
    @State private var showingEditSheet = false
    @State private var shareURL: URL?
    @State private var isAuthenticating = false
    @State private var contactShareURL: URL?
    @State private var contactExportError: String?

    var body: some View {
        List {
            Section("Information") {
                LabeledContent("Nickname", value: identity.nickname)
                LabeledContent("ID", value: identity.id.uuidString)
                    .font(.system(.caption, design: .monospaced))
            }
            
            Section("Fingerprint") {
                Text(identity.fingerprintDisplay)
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)

                if let errorMessage = errorMessage {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                        .font(.caption)
                }
            }
            
            if let base64 = identity.publicKeyBase64 {
                Section("Public Key (base64)") {
                    Text(base64)
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                }
            }

            Section {
                Button(action: {
                    showingEditSheet = true
                }) {
                    Label("Edit Nickname", systemImage: "pencil")
                }
            }

            Section("Share") {
                Button {
                    Task { await authenticateAndExport() }
                } label: {
                    Label("Share Identity (Plain)", systemImage: "square.and.arrow.up")
                }
                .disabled(isAuthenticating)
                .alert("Export Error", isPresented: .constant(exportError != nil)) {
                    Button("OK", role: .cancel) { exportError = nil }
                } message: {
                    Text(exportError ?? "")
                }
                if let shareURL = shareURL {
                    ShareLink(item: shareURL) {
                        Label("Open Share Sheet", systemImage: "square.and.arrow.up.on.square")
                    }
                }

                Button {
                    prepareContactExport()
                } label: {
                    Label("Share Public Key as Contact", systemImage: "person.badge.plus")
                }
                .alert("Export Error", isPresented: .constant(contactExportError != nil)) {
                    Button("OK", role: .cancel) { contactExportError = nil }
                } message: {
                    Text(contactExportError ?? "")
                }
                if let contactShareURL {
                    ShareLink(item: contactShareURL) {
                        Label("Open Share Sheet", systemImage: "square.and.arrow.up.on.square")
                    }
                }
            }
        }
        .navigationTitle("Identity Detail")
#if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
#endif
        .sheet(isPresented: $showingEditSheet) {
            EditIdentityView(identity: identity)
        }
        .onDisappear {
            cleanupExportFile()
        }
    }
    
    private func authenticateAndExport() async {
        isAuthenticating = true
        defer { isAuthenticating = false }
        do {
            let url = try await authenticateAndExportUseCase.execute(identity: identity)
            await MainActor.run { shareURL = url }
        } catch {
            await MainActor.run {
                exportError = "Failed to export identity: \(error.localizedDescription)"
            }
        }
    }

    private func prepareContactExport() {
        guard contactShareURL == nil else { return }
        do {
            contactShareURL = try exportIdentityAsContactUseCase.execute(identity: identity)
        } catch {
            contactExportError = "Failed to export: \(error.localizedDescription)"
        }
    }

    private func cleanupExportFile() {
        cleanupExportFileUseCase.execute(urls: [shareURL, contactShareURL])
        shareURL = nil
        contactShareURL = nil
    }

}

#Preview("Identity Detail") {
    NavigationStack {
        IdentityDetailView(identity: Identity(
            id: UUID(),
            nickname: "My Identity",
            publicKey: "SOME PUBLIC KEY"
        ))
    }
}
