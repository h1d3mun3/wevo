//
//  ProposeSettingsDetailView.swift
//  Wevo
//
//  Created by hidemune on 3/10/26.
//

import SwiftUI
import CryptoKit
import os

struct ProposeSettingsDetailView: View {
    let propose: Propose

    @Environment(\.dependencies) private var deps

    @State private var isHashValid: Bool?
    @State private var contactNicknames: [String: String] = [:]

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

                        // Hash verification result
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

            Section {
                LabeledContent("Created") {
                    Text(propose.createdAt, format: .dateTime)
                }
                LabeledContent("Last Modified") {
                    Text(propose.updatedAt, format: .dateTime)
                }
            } header: {
                Text("Local Record")
            } footer: {
                Text("Dates when this record was created or last modified on this device.")
            }

            let hasEventTimestamps = propose.counterpartySignTimestamp != nil
                || propose.creatorHonorTimestamp != nil
                || propose.counterpartyHonorTimestamp != nil
                || propose.creatorPartTimestamp != nil
                || propose.counterpartyPartTimestamp != nil
                || propose.dissolvedAt != nil
            if hasEventTimestamps {
                Section("Event Timestamps") {
                    if let ts = propose.counterpartySignTimestamp {
                        timestampRow("Counterparty Signed At", iso8601: ts)
                    }
                    if let ts = propose.creatorHonorTimestamp {
                        timestampRow("Creator Honored At", iso8601: ts)
                    }
                    if let ts = propose.counterpartyHonorTimestamp {
                        timestampRow("Counterparty Honored At", iso8601: ts)
                    }
                    if let ts = propose.creatorPartTimestamp {
                        timestampRow("Creator Parted At", iso8601: ts)
                    }
                    if let ts = propose.counterpartyPartTimestamp {
                        timestampRow("Counterparty Parted At", iso8601: ts)
                    }
                    if let ts = propose.dissolvedAt {
                        timestampRow("Dissolved At", iso8601: ts)
                    }
                }
            }

            // MARK: - Participants Section (replaces the old Signatures section)
            Section("Participants") {
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

            // MARK: - Status Section
            Section("Status") {
                LabeledContent("Local Status") {
                    HStack(spacing: 4) {
                        // localStatus icon (proposed=⏳, signed=✅)
                        Image(systemName: propose.localStatus == .proposed ? "clock" : "checkmark.circle.fill")
                            .foregroundStyle(propose.localStatus == .proposed ? .orange : .green)
                        Text(propose.localStatus.rawValue.capitalized)
                            .font(.caption)
                    }
                }
            }
        }
        .task {
            await verifyHash()
            await loadContactNicknames()
        }
        .navigationTitle("Propose Details")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    /// Renders a LabeledContent row for an ISO8601 timestamp string
    @ViewBuilder
    private func timestampRow(_ label: String, iso8601: String) -> some View {
        LabeledContent(label) {
            if let date = ISO8601DateFormatter().date(from: iso8601) {
                Text(date, format: .dateTime)
            } else {
                Text(iso8601)
                    .font(.caption)
                    .fontDesign(.monospaced)
            }
        }
    }

    /// Participant row (Creator / Counterparty)
    @ViewBuilder
    private func participantRow(publicKey: String, role: String, isSigned: Bool) -> some View {
        HStack(spacing: 8) {
            // Signature status icon (proposed=⏳, signed=✅)
            Image(systemName: isSigned ? "checkmark.circle.fill" : "clock")
                .foregroundStyle(isSigned ? .green : .orange)

            VStack(alignment: .leading, spacing: 2) {
                // Nickname or prefix of PublicKey
                let nickname = contactNicknames[publicKey] ?? String(publicKey.prefix(16)) + "..."
                Text(nickname)
                    .font(.body)

                Text(role)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(fingerprintDisplay(for: publicKey))
                    .font(.caption2)
                    .fontDesign(.monospaced)
                    .foregroundStyle(.tertiary)
                    .textSelection(.enabled)
            }
        }
        .padding(.vertical, 4)
    }

    /// Returns the fingerprint of a JWK public key in the same format as Contact.fingerprintDisplay:
    /// SHA256(rawRepresentation) の先頭8バイトをコロン区切り16進数で表示
    private func fingerprintDisplay(for jwkPublicKey: String) -> String {
        guard let key = P256.Signing.PublicKey.fromJWKString(jwkPublicKey) else {
            return String(jwkPublicKey.prefix(16)) + "..."
        }
        let hash = SHA256.hash(data: key.rawRepresentation)
        return Array(hash.prefix(8))
            .map { String(format: "%02X", $0) }
            .joined(separator: ":")
    }

    private func verifyHash() async {
        let useCase = VerifyProposeHashUseCaseImpl()
        let isValid = useCase.execute(message: propose.message, payloadHash: propose.payloadHash)

        await MainActor.run {
            isHashValid = isValid
        }
    }

    private func loadContactNicknames() async {
        let useCase = GetContactNicknamesMapUseCaseImpl(contactRepository: deps.contactRepository)
        do {
            let dict = try useCase.execute()
            await MainActor.run {
                contactNicknames = dict
            }
        } catch {
            Logger.contact.error("Error loading contact nicknames: \(error, privacy: .public)")
        }
    }
}

#Preview("Propose Settings Detail") {
    let propose = Propose(
        id: UUID(),
        spaceID: UUID(),
        message: "Preview message",
        creatorPublicKey: "creatorPublicKey",
        creatorSignature: "creatorSignature",
        counterpartyPublicKey: "counterpartyPublicKey",
        counterpartySignSignature: nil,
        createdAt: .now,
        updatedAt: .now
    )

    NavigationStack {
        ProposeSettingsDetailView(propose: propose)
    }
}
