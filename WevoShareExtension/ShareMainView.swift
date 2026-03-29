//
//  ShareMainView.swift
//  WevoShareExtension
//

import SwiftUI
import CryptoKit

// MARK: - Share Main View

struct ShareMainView: View {
    let sharedText: String
    let onDismiss: () -> Void

    var body: some View {
        NavigationStack {
            Group {
                if SignatureBlock.contains(sharedText), let block = SignatureBlock.parse(sharedText) {
                    VerifyView(
                        originalText: block.originalText,
                        publicKeyBase64: block.publicKey,
                        signatureBase64: block.signature,
                        onDismiss: onDismiss
                    )
                } else {
                    SignView(textToSign: sharedText, onDismiss: onDismiss)
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onDismiss)
                }
            }
        }
    }
}

// MARK: - Sign View

struct SignView: View {
    let textToSign: String
    let onDismiss: () -> Void

    @State private var identities: [ExtensionIdentity] = []
    @State private var selectedID: UUID?
    @State private var signedText: String?
    @State private var errorMessage: String?
    @State private var isSigning = false
    @State private var copied = false

    private let keychain = ExtensionKeychainService()

    var body: some View {
        if let result = signedText {
            completionView(result)
        } else {
            selectionView
        }
    }

    // MARK: Identity Selection View

    private var selectionView: some View {
        Form {
            Section("Text to Sign") {
                Text(textToSign)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(4)
            }

            Section("Sign with Identity") {
                if identities.isEmpty {
                    Text("No identities found.\nCreate one in Wevo first.")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                } else {
                    ForEach(identities, id: \.id) { identity in
                        Button {
                            selectedID = identity.id
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(identity.nickname)
                                        .foregroundStyle(.primary)
                                    Text(fingerprintFor(identity))
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                if selectedID == identity.id {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(Color.accentColor)
                                }
                            }
                        }
                    }
                }
            }

            if let msg = errorMessage {
                Section {
                    Label(msg, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.red)
                        .font(.caption)
                }
            }

            Section {
                Button {
                    performSign()
                } label: {
                    HStack {
                        Spacer()
                        if isSigning {
                            ProgressView()
                        } else {
                            Text("Sign")
                                .fontWeight(.semibold)
                        }
                        Spacer()
                    }
                }
                .disabled(selectedID == nil || isSigning)
            }
        }
        .navigationTitle("Sign")
        .onAppear(perform: loadIdentities)
    }

    // MARK: Completion View

    private func completionView(_ result: String) -> some View {
        Form {
            Section("Signed Text") {
                Text(result)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }

            Section {
                Button {
                    copyToClipboard(result)
                } label: {
                    HStack {
                        Spacer()
                        Label(
                            copied ? "Copied!" : "Copy to Clipboard",
                            systemImage: copied ? "checkmark.circle" : "doc.on.clipboard"
                        )
                        .foregroundStyle(copied ? Color.green : Color.accentColor)
                        Spacer()
                    }
                }

                Button("Done") { onDismiss() }
                    .frame(maxWidth: .infinity)
            }
        }
        .navigationTitle("Signed")
    }

    // MARK: Actions

    private func loadIdentities() {
        do {
            identities = try keychain.getAllIdentities()
            if identities.count == 1 { selectedID = identities[0].id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func performSign() {
        guard let id = selectedID else { return }
        isSigning = true
        errorMessage = nil
        Task {
            do {
                let sig = try keychain.signText(textToSign, withIdentityId: id)
                let pubKey = try keychain.getPublicKeyRawBase64(forIdentityId: id)
                let result = SignatureBlock.format(
                    text: textToSign,
                    publicKeyBase64: pubKey,
                    signatureBase64: sig
                )
                await MainActor.run {
                    signedText = result
                    isSigning = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isSigning = false
                }
            }
        }
    }

    private func copyToClipboard(_ text: String) {
        #if canImport(UIKit)
        UIPasteboard.general.string = text
        #elseif canImport(AppKit)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        #endif
        withAnimation { copied = true }
        Task {
            try? await Task.sleep(for: .seconds(2))
            await MainActor.run { withAnimation { copied = false } }
        }
    }

    private func fingerprintFor(_ identity: ExtensionIdentity) -> String {
        guard let pk = P256.Signing.PublicKey(jwkString: identity.publicKeyJWK) else { return "---" }
        let hash = SHA256.hash(data: pk.rawRepresentation)
        return Array(hash.prefix(8))
            .map { String(format: "%02X", $0) }
            .joined(separator: ":")
    }
}

// MARK: - Verify View

struct VerifyView: View {
    let originalText: String
    let publicKeyBase64: String
    let signatureBase64: String
    let onDismiss: () -> Void

    @State private var result: VerificationResult = .loading

    private let keychain = ExtensionKeychainService()

    enum VerificationResult {
        case loading
        case valid(signer: SignerType)
        case invalid
        case error(String)
    }

    enum SignerType {
        case selfSigned
        case known
        case unknown
    }

    var body: some View {
        Form {
            Section("Signed Text") {
                Text(originalText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(5)
                    .textSelection(.enabled)
            }

            Section("Verification Result") {
                resultRow
            }

            Section("Public Key Fingerprint") {
                Text(ExtensionKeychainService.fingerprint(rawPublicKeyBase64: publicKeyBase64))
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }

            Section {
                Button("Done") { onDismiss() }
                    .frame(maxWidth: .infinity)
            }
        }
        .navigationTitle("Verify Signature")
        .onAppear(perform: verify)
    }

    @ViewBuilder
    private var resultRow: some View {
        switch result {
        case .loading:
            HStack(spacing: 8) {
                ProgressView()
                Text("Verifying...")
                    .foregroundStyle(.secondary)
            }
        case .valid(let signer):
            switch signer {
            case .selfSigned:
                Label("Not tampered (signed by you)", systemImage: "checkmark.seal.fill")
                    .foregroundStyle(.green)
            case .known:
                Label("Not tampered (known signer)", systemImage: "checkmark.seal.fill")
                    .foregroundStyle(.green)
            case .unknown:
                Label("Not tampered (unknown signer)", systemImage: "exclamationmark.shield.fill")
                    .foregroundStyle(.orange)
            }
        case .invalid:
            Label("Tampered", systemImage: "xmark.shield.fill")
                .foregroundStyle(.red)
        case .error(let msg):
            Label("Error: \(msg)", systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
        }
    }

    private func verify() {
        Task {
            do {
                let isValid = try keychain.verifyText(
                    originalText,
                    publicKeyBase64: publicKeyBase64,
                    signatureBase64: signatureBase64
                )
                let signer: SignerType
                if isValid {
                    if (try? keychain.isSelfPublicKey(rawBase64: publicKeyBase64)) ?? false {
                        signer = .selfSigned
                    } else if ExtensionContactStore().isKnownContact(rawPublicKeyBase64: publicKeyBase64) {
                        signer = .known
                    } else {
                        signer = .unknown
                    }
                } else {
                    signer = .unknown
                }
                await MainActor.run {
                    result = isValid ? .valid(signer: signer) : .invalid
                }
            } catch {
                await MainActor.run {
                    result = .error(error.localizedDescription)
                }
            }
        }
    }
}
