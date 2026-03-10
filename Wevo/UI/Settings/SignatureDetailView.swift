//
//  SignatureDetailView.swift
//  Wevo
//
//  Created by hidemune on 3/10/26.
//

import SwiftUI
import SwiftData

struct SignatureDetailView: View {
    let signature: SignatureSwiftData

    var body: some View {
        List {
            Section("Public Key") {
                Text(signature.publicKey)
                    .font(.caption)
                    .fontDesign(.monospaced)
                    .textSelection(.enabled)
            }

            Section("Signature Data") {
                Text(signature.signatureData)
                    .font(.caption)
                    .fontDesign(.monospaced)
                    .textSelection(.enabled)
            }

            Section("IDs") {
                LabeledContent("Signature ID") {
                    Text(signature.id.uuidString)
                        .font(.caption)
                        .fontDesign(.monospaced)
                        .textSelection(.enabled)
                }
            }

            Section("Timestamp") {
                LabeledContent("Created At") {
                    Text(signature.createdAt, format: .dateTime)
                }
            }
        }
        .navigationTitle("Signature Details")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}

#Preview("Signature Detail") {
    let signature = SignatureSwiftData(
        id: UUID(),
        publicKey: "PreviewPublicKey",
        signatureData: "PreviewSignatureData",
        createdAt: .now
    )

    SignatureDetailView(signature: signature)
        .modelContainer(for: [SignatureSwiftData.self], inMemory: true)
}
