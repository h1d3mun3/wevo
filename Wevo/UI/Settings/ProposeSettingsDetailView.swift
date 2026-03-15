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

            // MARK: - Participantsセクション（旧Signaturesセクションを置き換え）
            Section("Participants") {
                // Creator行（常に署名済み）
                participantRow(
                    publicKey: propose.creatorPublicKey,
                    role: "Creator",
                    isSigned: true
                )

                // Counterparty行（localStatusに応じたアイコン）
                participantRow(
                    publicKey: propose.counterpartyPublicKey,
                    role: "Counterparty",
                    isSigned: propose.counterpartySignSignature != nil
                )
            }

            // MARK: - Statusセクション
            Section("Status") {
                LabeledContent("Local Status") {
                    HStack(spacing: 4) {
                        // localStatusのアイコン（proposed=⏳, signed=✅）
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

    /// 参加者行（Creator / Counterparty）
    @ViewBuilder
    private func participantRow(publicKey: String, role: String, isSigned: Bool) -> some View {
        HStack(spacing: 8) {
            // 署名状態アイコン（proposed=⏳, signed=✅）
            Image(systemName: isSigned ? "checkmark.circle.fill" : "clock")
                .foregroundStyle(isSigned ? .green : .orange)

            VStack(alignment: .leading, spacing: 2) {
                // ニックネームまたはPublicKeyのプレフィックス
                let nickname = contactNicknames[publicKey] ?? String(publicKey.prefix(16)) + "..."
                Text(nickname)
                    .font(.body)

                Text(role)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(publicKey.prefix(24) + "...")
                    .font(.caption2)
                    .fontDesign(.monospaced)
                    .foregroundStyle(.tertiary)
                    .textSelection(.enabled)
            }
        }
        .padding(.vertical, 4)
    }

    private func verifyHash() async {
        let useCase = VerifyProposeHashUseCaseImpl()
        let isValid = useCase.execute(message: propose.message, payloadHash: propose.payloadHash)

        await MainActor.run {
            isHashValid = isValid
        }
    }

    private func loadContactNicknames() async {
        let useCase = GetAllContactsUseCaseImpl(contactRepository: deps.contactRepository)
        do {
            let contacts = try useCase.execute()
            let dict = Dictionary(uniqueKeysWithValues: contacts.map { ($0.publicKey, $0.nickname) })
            await MainActor.run {
                contactNicknames = dict
            }
        } catch {
            print("❌ Contactニックネームの読み込みエラー: \(error)")
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
