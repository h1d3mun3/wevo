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
    @State private var migrationError: String?

    var body: some View {
        List {
            Section("Information") {
                LabeledContent("Nickname", value: identity.nickname)
                LabeledContent("ID", value: identity.id.uuidString)
                    .font(.system(.caption, design: .monospaced))
            }
            
            Section("Public Key") {
                VStack(alignment: .leading, spacing: 8) {
                    Text(identity.publicKey)
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                    
                    Button(action: {
                        #if os(iOS)
                        UIPasteboard.general.string = identity.publicKey
                        #elseif os(macOS)
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(identity.publicKey, forType: .string)
                        #endif
                    }) {
                        Label("Copy to Clipboard", systemImage: "doc.on.doc")
                    }
                    .buttonStyle(.bordered)
                }
                
                if let errorMessage = errorMessage {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                        .font(.caption)
                }
            }
            
            Section {
                Button(action: {
                    showingEditSheet = true
                }) {
                    Label("Edit Nickname", systemImage: "pencil")
                }
            }

            Section {
                Button(action: {
                    migrateKey()
                }) {
                    Label("Migration Key", systemImage: "icloud")
                }
                .alert("Migration Error", isPresented: .constant(migrationError != nil)) {
                    Button("OK", role: .cancel) { migrationError = nil }
                } message: {
                    Text(migrationError ?? "")
                }
            }

            Section("Share") {
#if os(iOS)
                Button {
                    preparePlainExport()
                } label: {
                    Label("Share Identity (Plain)", systemImage: "square.and.arrow.up")
                }
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
#else
                Button {
                    preparePlainExport()
                    showShareSheet = true
                } label: {
                    Label("Share Identity (Plain)", systemImage: "square.and.arrow.up")
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
#endif
    }
    
    private func preparePlainExport() {
        let useCase = ExportIdentityUseCaseImpl(keychainRepository: deps.keychainRepository)
        do {
            shareURL = try useCase.execute(identity: identity)
        } catch {
            exportError = "Failed to export identity: \(error.localizedDescription)"
        }
    }

    private func migrateKey() {
        let migrateIdentityUseCase = MigrateIdentityUseCaseImpl(keychainRepository: deps.keychainRepository)
        do {
            try migrateIdentityUseCase.execute(id: identity.id)
        } catch {
            migrationError = "Failed to migrateError identity: \(error.localizedDescription)"
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
