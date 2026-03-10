//
//  SignatureRowView.swift
//  Wevo
//
//  Created by hidemune on 3/10/26.
//

import SwiftUI

struct SignatureRowView: View {
    let signature: Signature
    let myPublicKey: String?

    private var isMySignature: Bool {
        guard let myPublicKey = myPublicKey else { return false }
        return signature.publicKey == myPublicKey
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Image(systemName: isMySignature ? "person.fill.checkmark" : "checkmark.seal.fill")
                    .font(.caption2)
                    .foregroundStyle(isMySignature ? .blue : .green)

                Text(signature.publicKey.prefix(16) + "...")
                    .font(.caption2)
                    .fontDesign(.monospaced)
                    .foregroundStyle(isMySignature ? .blue : .secondary)
                    .fontWeight(isMySignature ? .semibold : .regular)

                if isMySignature {
                    Text("(You)")
                        .font(.caption2)
                        .foregroundStyle(.blue)
                        .italic()
                }

                Spacer()

                Text(signature.createdAt, format: .dateTime.month().day().hour().minute())
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.leading, 8)
        .padding(.vertical, 2)
        .background(isMySignature ? Color.blue.opacity(0.05) : Color.clear)
        .cornerRadius(4)
    }
}
