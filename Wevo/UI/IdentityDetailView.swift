//
//  IdentityDetailView.swift
//  Wevo
//
//  Created by hidemune on 3/6/26.
//

import SwiftUI
import CryptoKit
import UniformTypeIdentifiers

struct IdentityDetailView: View {
    let identity: Identity
    
    @State private var errorMessage: String?
    @State private var exportError: String?
    @State private var showingEditSheet = false
    @State private var shareURL: URL?
    @State private var showShareSheet = false
    
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
                ShareSheet(items: [shareURL])
            }
        }
#endif
    }
    
    private func preparePlainExport() {
        do {
            // Fetch private key from Keychain (biometric auth may be required)
            let privateKeyData = try KeychainRepository.shared.getPrivateKey(id: identity.id)
            let base64 = privateKeyData.base64EncodedString()
            let url = try IdentityPlainTransfer.exportPlainToFile(identity: identity, privateKeyBase64: base64)
            shareURL = url
        } catch {
            exportError = "Failed to export identity: \(error.localizedDescription)"
        }
    }
}

// MARK: - Edit Identity View

struct EditIdentityView: View {
    @Environment(\.dismiss) private var dismiss
    
    let identity: Identity
    @State private var nickname: String
    @State private var isSaving = false
    @State private var errorMessage: String?
    
    init(identity: Identity) {
        self.identity = identity
        _nickname = State(initialValue: identity.nickname)
    }
    
    private var canSave: Bool {
        !nickname.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        nickname != identity.nickname &&
        !isSaving
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Nickname") {
                    TextField("Nickname", text: $nickname)
                }
                
                if let errorMessage = errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle("Edit Identity")
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .disabled(isSaving)
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            await save()
                        }
                    }
                    .disabled(!canSave)
                }
            }
        }
    }
    
    private func save() async {
        isSaving = true
        errorMessage = nil
        
        do {
            let trimmedNickname = nickname.trimmingCharacters(in: .whitespacesAndNewlines)
            try KeychainRepository.shared.updateNickname(id: identity.id, newNickname: trimmedNickname)
            
            await MainActor.run {
                isSaving = false
                dismiss()
            }
        } catch {
            await MainActor.run {
                errorMessage = "Failed to update: \(error.localizedDescription)"
                isSaving = false
            }
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

#Preview("Edit Identity") {
    EditIdentityView(identity: Identity(
        id: UUID(),
        nickname: "My Identity",
        publicKey: "SOME PUBLIC KEY"
    ))
}
