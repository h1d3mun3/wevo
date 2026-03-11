//
//  ProposeSettingsDetailView.swift
//  Wevo
//
//  Created by hidemune on 3/10/26.
//

import SwiftUI

struct ProposeSettingsDetailView: View {
    let propose: Propose

    @Environment(\.dependencies) private var deps

    @State private var selectedSignature: Signature?
    @State private var signatureVerifications: [UUID: Bool] = [:]
    @State private var isHashValid: Bool?

    var body: some View {
        List {
            Section("Message") {
                Text(propose.message)
                    .font(.body)
            }

            Section("Hash") {
                LabeledContent("Payload Hash") {
                    HStack {
                        Text(propose.payloadHash)
                            .font(.caption)
                            .fontDesign(.monospaced)
                            .textSelection(.enabled)

                        Spacer()

                        // ハッシュ検証結果
                        if let isValid = isHashValid {
                            Image(systemName: isValid ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundStyle(isValid ? .green : .red)
                                .font(.title3)
                        } else {
                            ProgressView()
                                .scaleEffect(0.8)
                        }
                    }
                }

                if let isValid = isHashValid, !isValid {
                    Text("⚠️ Hash mismatch: The payload hash does not match the message")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            Section("IDs") {
                LabeledContent("Propose ID") {
                    Text(propose.id.uuidString)
                        .font(.caption)
                        .fontDesign(.monospaced)
                        .textSelection(.enabled)
                }

                LabeledContent("Space ID") {
                    Text(propose.spaceID.uuidString)
                        .font(.caption)
                        .fontDesign(.monospaced)
                        .textSelection(.enabled)
                }
            }

            Section("Timestamps") {
                LabeledContent("Created At") {
                    Text(propose.createdAt, format: .dateTime)
                }

                LabeledContent("Updated At") {
                    Text(propose.updatedAt, format: .dateTime)
                }
            }

            Section("Signatures (\(propose.signatures.count))") {
                if propose.signatures.isEmpty {
                    Text("No signatures")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(propose.signatures) { signature in
                        Button {
                            selectedSignature = signature
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(signature.publicKey.prefix(32) + "...")
                                        .font(.caption)
                                        .fontDesign(.monospaced)

                                    Text(signature.createdAt, format: .dateTime.month().day().hour().minute())
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                // 検証状態を表示
                                if let isValid = signatureVerifications[signature.id] {
                                    Image(systemName: isValid ? "checkmark.seal.fill" : "xmark.seal.fill")
                                        .foregroundStyle(isValid ? .green : .red)
                                        .font(.title3)
                                } else {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .task {
            await verifyHash()
            await verifyAllSignatures()
        }
        .navigationTitle("Propose Details")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .sheet(item: $selectedSignature) { signature in
            NavigationStack {
                SignatureDetailView(signature: signature)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Close") {
                                selectedSignature = nil
                            }
                        }
                    }
            }
        }
    }

    private func verifyHash() async {
        let useCase = VerifyProposeHashUseCaseImpl()
        let isValid = useCase.execute(message: propose.message, payloadHash: propose.payloadHash)

        await MainActor.run {
            isHashValid = isValid
        }
    }

    private func verifyAllSignatures() async {
        for signature in propose.signatures {
            let isValid = await verifySignature(signature)
            await MainActor.run {
                signatureVerifications[signature.id] = isValid
            }
        }
    }

    private func verifySignature(_ signature: Signature) async -> Bool {
        let verifySignatureUseCase = VerifySignatureUseCaseImpl(keychainRepository: deps.keychainRepository)

        do {
            let isValid = try verifySignatureUseCase.execute(
                signature: signature.signature,
                message: propose.payloadHash,
                publicKey: signature.publicKey
            )

            return isValid
        } catch {
            print("❌ Error verifying signature \(signature.id): \(error)")
            return false
        }
    }
}

#Preview("Propose Settings Detail") {
    let signature = Signature(
        id: UUID(),
        publicKey: "PreviewPublicKey",
        signature: "PreviewSignature",
        createdAt: .now
    )

    let propose = Propose(
        id: UUID(),
        spaceID: UUID(),
        message: "Preview message",
        signatures: [signature],
        createdAt: .now,
        updatedAt: .now
    )

    ProposeSettingsDetailView(propose: propose)
}
