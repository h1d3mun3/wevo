//
//  ProposeServerSyncBannerView.swift
//  Wevo
//
//  Created on 3/11/26.
//

import SwiftUI

/// Counterpartyのサーバー署名が承認待ちの場合に表示するバナー
/// ユーザーが明示的に「承認する」を選んだ場合のみローカルに反映する
struct PendingSignatureBannerView: View {
    /// CounterpartyのニックネームまたはPublicKeyのプレフィックス
    let counterpartyNickname: String
    /// 承認処理中かどうか
    let isAccepting: Bool
    /// 「承認する」ボタンが押されたときのコールバック
    let onAccept: () -> Void
    /// 「無視する」ボタンが押されたときのコールバック
    let onIgnore: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "signature")
                    .font(.caption)
                    .foregroundStyle(.orange)

                Text("\(counterpartyNickname)がサーバーで署名しました")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .fontWeight(.medium)

                Spacer()
            }

            HStack(spacing: 8) {
                Spacer()

                Button("無視する") {
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
                            Text("承認中...")
                                .font(.caption)
                        }
                    } else {
                        Label("承認する", systemImage: "checkmark.circle.fill")
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
