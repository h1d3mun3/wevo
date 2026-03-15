//
//  ProposeServerSyncBannerView.swift
//  Wevo
//
//  Created on 3/11/26.
//

import SwiftUI

/// Banner displayed when the Counterparty's server signature is pending approval
/// Reflected locally only when the user explicitly chooses to accept
struct PendingSignatureBannerView: View {
    /// Counterparty's nickname or prefix of their PublicKey
    let counterpartyNickname: String
    /// Whether acceptance processing is in progress
    let isAccepting: Bool
    /// Callback when the "Accept" button is tapped
    let onAccept: () -> Void
    /// Callback when the "Ignore" button is tapped
    let onIgnore: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "signature")
                    .font(.caption)
                    .foregroundStyle(.orange)

                Text("\(counterpartyNickname) signed on the server")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .fontWeight(.medium)

                Spacer()
            }

            HStack(spacing: 8) {
                Spacer()

                Button("Ignore") {
                    onIgnore()
                }
                .buttonStyle(.borderless)
                .font(.caption)
                .foregroundStyle(.secondary)
                .disabled(isAccepting)

                Button(action: onAccept) {
                    if isAccepting {
                        HStack(spacing: 4) {
                            ProgressView()
                                .scaleEffect(0.7)
                            Text("Accepting...")
                                .font(.caption)
                        }
                    } else {
                        Label("Accept", systemImage: "checkmark.circle.fill")
                            .font(.caption)
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.mini)
                .disabled(isAccepting)
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(Color.orange.opacity(0.1))
        .cornerRadius(8)
    }
}
