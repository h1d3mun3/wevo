//
//  ProposeSignaturesSectionView.swift
//  Wevo
//
//  Created on 3/11/26.
//

import SwiftUI

/// Section view for Participants (Creator + Counterparty)
/// Changed from the old signature list display to participant status display
struct ProposeSignaturesSectionView: View {
    let propose: Propose
    let contactNicknames: [String: String]
    let defaultIdentity: Identity?

    var body: some View {
        Divider()
            .padding(.vertical, 4)

        VStack(alignment: .leading, spacing: 4) {
            Text("Participants:")
                .font(.caption2)
                .foregroundStyle(.tertiary)

            // Creator row (always signed)
            participantRow(
                publicKey: propose.creatorPublicKey,
                role: "Creator",
                isSigned: true
            )

            // Counterparty row (icon based on localStatus)
            participantRow(
                publicKey: propose.counterpartyPublicKey,
                role: "Counterparty",
                isSigned: propose.counterpartySignSignature != nil
            )
        }
    }

    @ViewBuilder
    private func participantRow(publicKey: String, role: String, isSigned: Bool) -> some View {
        HStack(spacing: 8) {
            // Signature status icon (proposed=⏳, signed=✅)
            Image(systemName: isSigned ? "checkmark.circle.fill" : "clock")
                .font(.caption)
                .foregroundStyle(isSigned ? .green : .orange)

            VStack(alignment: .leading, spacing: 2) {
                // Nickname or prefix of PublicKey
                let nickname = contactNicknames[publicKey] ?? String(publicKey.prefix(12)) + "..."
                Text(nickname)
                    .font(.caption)

                Text(role)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Badge indicating whether this is the current user
            if publicKey == defaultIdentity?.publicKey {
                Text("Me")
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.blue.opacity(0.1))
                    .foregroundStyle(.blue)
                    .cornerRadius(4)
            }
        }
        .padding(.vertical, 2)
    }
}
