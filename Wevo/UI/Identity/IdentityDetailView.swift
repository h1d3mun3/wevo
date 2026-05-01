//
//  IdentityDetailView.swift
//  Wevo
//
//  Created by hidemune on 3/6/26.
//

import SwiftUI

// MARK: - Container

struct IdentityDetailView: View {
    let identity: Identity

    @Environment(\.dependencies) private var deps

    var body: some View {
        IdentityDetailContent(
            viewModel: IdentityDetailViewModel(identity: identity, deps: deps)
        )
    }
}

// MARK: - Content

private struct IdentityDetailContent: View {
    @State var viewModel: IdentityDetailViewModel

    var body: some View {
        List {
            Section("Information") {
                LabeledContent("Nickname", value: viewModel.identity.nickname)
                LabeledContent("ID", value: viewModel.identity.id.uuidString)
                    .font(.system(.caption, design: .monospaced))
            }

            Section("Fingerprint") {
                Text(viewModel.identity.fingerprintDisplay)
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
            }

            if let base64 = viewModel.identity.publicKeyBase64 {
                Section("Public Key (base64)") {
                    Text(base64)
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                }
            }

            Section {
                Button(action: {
                    viewModel.showingEditSheet = true
                }) {
                    Label("Edit Nickname", systemImage: "pencil")
                }
            }

            Section("Share") {
                Button {
                    Task { await viewModel.authenticateAndExport() }
                } label: {
                    Label("Share Identity (Plain)", systemImage: "square.and.arrow.up")
                }
                .disabled(viewModel.isAuthenticating)
                .alert("Export Error", isPresented: .constant(viewModel.exportError != nil)) {
                    Button("OK", role: .cancel) { viewModel.exportError = nil }
                } message: {
                    Text(viewModel.exportError ?? "")
                }
                if let shareURL = viewModel.shareURL {
                    ShareLink(item: shareURL) {
                        Label("Open Share Sheet", systemImage: "square.and.arrow.up.on.square")
                    }
                }

                Button {
                    viewModel.prepareContactExport()
                } label: {
                    Label("Share Public Key as Contact", systemImage: "person.badge.plus")
                }
                .alert("Export Error", isPresented: .constant(viewModel.contactExportError != nil)) {
                    Button("OK", role: .cancel) { viewModel.contactExportError = nil }
                } message: {
                    Text(viewModel.contactExportError ?? "")
                }
                if let contactShareURL = viewModel.contactShareURL {
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
        .sheet(isPresented: $viewModel.showingEditSheet) {
            EditIdentityView(identity: viewModel.identity)
        }
        .onDisappear {
            viewModel.cleanupExportFile()
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
