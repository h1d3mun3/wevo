//
//  IdentityDetailView.swift
//  Wevo
//
//  Created by hidemune on 3/6/26.
//

import SwiftUI
import UniformTypeIdentifiers

struct IdentityDetailView: View {
    let identity: Identity

    @Environment(\.dependencies) private var deps

    @State private var errorMessage: String?
    @State private var exportError: String?
    @State private var showingEditSheet = false
    @State private var shareURL: URL?
    @State private var showShareSheet = false
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
#if os(iOS)
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

                if let contactShareURL {
                    ShareLink(item: contactShareURL) {
                        Label("Share Public Key as Contact", systemImage: "person.badge.plus")
                    }
                } else {
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
                }
#else
                Button {
                    Task { await authenticateAndExport(); showShareSheet = true }
                } label: {
                    Label("Share Identity (Plain)", systemImage: "square.and.arrow.up")
                }
                .disabled(isAuthenticating)

                Button {
                    prepareContactExport()
                    showShareSheet = true
                } label: {
                    Label("Share Public Key as Contact", systemImage: "person.badge.plus")
                }
#endif
            }
        }
        .navigationTitle("Identity Detail")
#if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
#endif
        .sheet(isPresented: $showingEditSheet) {
            EditIdentityView(identity: identity)
        }
#if os(macOS)
        .sheet(isPresented: $showShareSheet) {
            if let shareURL = shareURL {
                ShareSheetView(items: [shareURL])
            }
        }
        .onChange(of: showShareSheet) { _, isPresented in
            if !isPresented {
                cleanupExportFile()
            }
        }
#endif
        .onDisappear {
            cleanupExportFile()
        }
    }
    
    private func authenticateAndExport() async {
        isAuthenticating = true
        defer { isAuthenticating = false }

        let useCase = AuthenticateAndExportIdentityUseCaseImpl(keychainRepository: deps.keychainRepository)
        do {
            let url = try await useCase.execute(identity: identity)
            await MainActor.run { shareURL = url }
        } catch {
            await MainActor.run {
                exportError = "Failed to export identity: \(error.localizedDescription)"
            }
        }
    }

    private func prepareContactExport() {
        if let existing = contactShareURL {
            try? FileManager.default.removeItem(at: existing)
            contactShareURL = nil
        }
        let useCase = ExportIdentityAsContactUseCaseImpl()
        do {
            contactShareURL = try useCase.execute(identity: identity)
        } catch {
            contactExportError = "Failed to export: \(error.localizedDescription)"
        }
    }

    private func cleanupExportFile() {
        if let url = shareURL {
            try? FileManager.default.removeItem(at: url)
            shareURL = nil
        }
        if let url = contactShareURL {
            try? FileManager.default.removeItem(at: url)
            contactShareURL = nil
        }
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
