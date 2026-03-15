//
//  ProposeSignaturesSectionView.swift
//  Wevo
//
//  Created on 3/11/26.
//

import SwiftUI

/// Participants（Creator + Counterparty）のセクションビュー
/// 旧のシグネチャリスト表示から参加者ステータス表示に変更
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
    }

    @ViewBuilder
    private func participantRow(publicKey: String, role: String, isSigned: Bool) -> some View {
        HStack(spacing: 8) {
            // 署名状態アイコン（proposed=⏳, signed=✅）
            Image(systemName: isSigned ? "checkmark.circle.fill" : "clock")
                .font(.caption)
                .foregroundStyle(isSigned ? .green : .orange)

            VStack(alignment: .leading, spacing: 2) {
                // ニックネームまたはPublicKeyのプレフィックス
                let nickname = contactNicknames[publicKey] ?? String(publicKey.prefix(12)) + "..."
                Text(nickname)
                    .font(.caption)

                Text(role)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // 自分自身かどうかを示すバッジ
            if publicKey == defaultIdentity?.publicKey {
                Text("自分")
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
