//
//  ProposeSignaturesSectionView.swift
//  Wevo
//
//  Created on 3/11/26.
//

import SwiftUI

struct ProposeSignaturesSectionView: View {
    let signaturesWithNicknames: [(signature: Signature, nickname: String?)]
    let defaultIdentity: Identity?
    let showSignButton: Bool
    let isSigning: Bool
    let signSuccess: Bool?
    let signErrorMessage: String?
    let onSign: () -> Void

    var body: some View {
        Divider()
            .padding(.vertical, 4)

        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Signatures:")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)

                Spacer()

                if showSignButton {
                    Button(action: onSign) {
                        if isSigning {
                            HStack(spacing: 4) {
                                ProgressView()
                                    .scaleEffect(0.6)
                                Text("Signing...")
                                    .font(.caption2)
                            }
                        } else {
                            Label("Sign", systemImage: "signature")
                                .font(.caption2)
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.mini)
                    .disabled(isSigning)
                }
            }

            if let signSuccess = signSuccess {
                HStack {
                    Image(systemName: signSuccess ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .font(.caption2)
                        .foregroundStyle(signSuccess ? .green : .red)
                    Text(signSuccess ? "Signed successfully" : (signErrorMessage ?? "Failed to sign"))
                        .font(.caption2)
                        .foregroundStyle(signSuccess ? .green : .red)
                }
                .padding(.top, 2)
            }

            ForEach(signaturesWithNicknames, id: \.signature.id) { item in
                SignatureRowView(
                    signature: item.signature,
                    myPublicKey: defaultIdentity?.publicKey,
                    contactNickname: item.nickname
                )
            }
        }
    }
}
