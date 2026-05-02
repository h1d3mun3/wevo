//
//  ProposeSettingsDetailView.swift
//  Wevo
//
//  Created by hidemune on 3/10/26.
//

import SwiftUI
import os

// MARK: - Container

struct ProposeSettingsDetailView: View {
    let propose: Propose

    @Environment(\.dependencies) private var deps

    var body: some View {
        ProposeSettingsDetailContent(
            viewModel: ProposeSettingsDetailViewModel(propose: propose, deps: deps)
        )
    }
}

// MARK: - Content

private struct ProposeSettingsDetailContent: View {
    @State var viewModel: ProposeSettingsDetailViewModel

    var body: some View {
        List {
            Section("Message") {
                Text(viewModel.propose.message)
                    .font(.body)
            }

            Section("Hash") {
                LabeledContent("Payload Hash") {
                    HStack {
                        Text(viewModel.propose.payloadHash)
                            .font(.caption)
                            .fontDesign(.monospaced)
                            .textSelection(.enabled)

                        Spacer()

                        if let isValid = viewModel.isHashValid {
                            Image(systemName: isValid ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundStyle(isValid ? .green : .red)
                                .font(.title3)
                        } else {
                            ProgressView()
                                .scaleEffect(0.8)
                        }
                    }
                }

                if let isValid = viewModel.isHashValid, !isValid {
                    Text("⚠️ Hash mismatch: The payload hash does not match the message")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            Section("IDs") {
                LabeledContent("Propose ID") {
                    Text(viewModel.propose.id.uuidString)
                        .font(.caption)
                        .fontDesign(.monospaced)
                        .textSelection(.enabled)
                }

                LabeledContent("Space ID") {
                    Text(viewModel.propose.spaceID.uuidString)
                        .font(.caption)
                        .fontDesign(.monospaced)
                        .textSelection(.enabled)
                }
            }

            Section("Local Record") {
                LabeledContent("Created") {
                    Text(viewModel.propose.createdAt, format: .dateTime)
                }
                LabeledContent("Last Modified") {
                    Text(viewModel.propose.updatedAt, format: .dateTime)
                }
            }

            if viewModel.hasEventTimestamps {
                Section("Event Timestamps") {
                    if let ts = viewModel.propose.counterpartySignTimestamp {
                        timestampRow("Counterparty Signed At", iso8601: ts)
                    }
                    if let ts = viewModel.propose.creatorHonorTimestamp {
                        timestampRow("Creator Honored At", iso8601: ts)
                    }
                    if let ts = viewModel.propose.counterpartyHonorTimestamp {
                        timestampRow("Counterparty Honored At", iso8601: ts)
                    }
                    if let ts = viewModel.propose.creatorPartTimestamp {
                        timestampRow("Creator Parted At", iso8601: ts)
                    }
                    if let ts = viewModel.propose.counterpartyPartTimestamp {
                        timestampRow("Counterparty Parted At", iso8601: ts)
                    }
                    if let ts = viewModel.propose.creatorDissolveTimestamp {
                        timestampRow("Creator Dissolved At", iso8601: ts)
                    }
                    if let ts = viewModel.propose.counterpartyDissolveTimestamp {
                        timestampRow("Counterparty Dissolved At", iso8601: ts)
                    }
                }
            }

            Section("Participants") {
                participantRow(
                    publicKey: viewModel.propose.creatorPublicKey,
                    role: "Creator",
                    isSigned: true
                )

                participantRow(
                    publicKey: viewModel.propose.counterpartyPublicKey,
                    role: "Counterparty",
                    isSigned: viewModel.propose.counterpartySignSignature != nil
                )
            }

            Section("Status") {
                LabeledContent("Local Status") {
                    HStack(spacing: 4) {
                        Image(systemName: viewModel.propose.localStatus == .proposed ? "clock" : "checkmark.circle.fill")
                            .foregroundStyle(viewModel.propose.localStatus == .proposed ? .orange : .green)
                        Text(viewModel.propose.localStatus.rawValue.capitalized)
                            .font(.caption)
                    }
                }
            }
        }
        .task {
            await viewModel.load()
        }
        .navigationTitle("Propose Details")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

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

    @ViewBuilder
    private func participantRow(publicKey: String, role: String, isSigned: Bool) -> some View {
        HStack(spacing: 8) {
            Image(systemName: isSigned ? "checkmark.circle.fill" : "clock")
                .foregroundStyle(isSigned ? .green : .orange)

            VStack(alignment: .leading, spacing: 2) {
                Text(viewModel.nickname(for: publicKey))
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

    private func fingerprintDisplay(for jwkPublicKey: String) -> String {
        GetFingerprintUseCaseImpl().execute(jwkPublicKey: jwkPublicKey)
    }
}

// MARK: - Preview

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
