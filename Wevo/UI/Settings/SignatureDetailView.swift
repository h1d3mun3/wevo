//
//  SignatureDetailView.swift
//  Wevo
//
//  Created by hidemune on 3/10/26.
//

import SwiftUI

struct SignatureDetailView: View {
    let signature: Signature

    var body: some View {
        List {
            Section("Public Key") {
                Text(signature.publicKey)
                    .font(.caption)
                    .fontDesign(.monospaced)
                    .textSelection(.enabled)
            }

            Section("Signature Data") {
                Text(signature.signature)
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
    let signature = Signature(
        id: UUID(),
        publicKey: "PreviewPublicKey",
        signature: "PreviewSignatureData",
        createdAt: .now
    )

    SignatureDetailView(signature: signature)
}
