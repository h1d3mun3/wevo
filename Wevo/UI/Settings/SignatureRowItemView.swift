//
//  SignatureRowItemView.swift
//  Wevo
//
//  Created by hidemune on 3/10/26.
//

import SwiftUI

struct SignatureRowItemView: View {
    let signature: Signature
    let isValid: Bool?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                // Change icon and color based on verification status
                if let isValid = isValid {
                    Image(systemName: isValid ? "checkmark.seal.fill" : "xmark.seal.fill")
                        .foregroundStyle(isValid ? .green : .red)
                } else {
                    ProgressView()
                        .scaleEffect(0.8)
                }

                Text(signature.publicKey.prefix(16) + "...")
                    .font(.body)
                    .fontDesign(.monospaced)

                Spacer()
            }

            HStack {
                Text("Created:")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(signature.createdAt, format: .dateTime.month().day().hour().minute())
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 8)
    }
}

#Preview("Signature Row Item") {
    let signature = Signature(
        id: UUID(),
        publicKey: "PreviewPublicKey",
        signature: "PreviewSignatureData",
        createdAt: .now
    )

    SignatureRowItemView(signature: signature, isValid: true)
}
