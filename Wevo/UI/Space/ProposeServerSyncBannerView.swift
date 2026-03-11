//
//  ProposeServerSyncBannerView.swift
//  Wevo
//
//  Created on 3/11/26.
//

import SwiftUI

/// サーバーに新しい署名がある場合の同期バナー
struct ProposeNewSignaturesBannerView: View {
    let count: Int
    let isSyncing: Bool
    let onSync: () -> Void

    var body: some View {
        HStack {
            Image(systemName: "exclamationmark.circle.fill")
                .font(.caption)
                .foregroundStyle(.orange)

            Text("Server has \(count) new signature(s)")
                .font(.caption)
                .foregroundStyle(.orange)
                .fontWeight(.medium)

            Spacer()

            Button(action: onSync) {
                if isSyncing {
                    HStack(spacing: 4) {
                        ProgressView()
                            .scaleEffect(0.7)
                        Text("Syncing...")
                            .font(.caption)
                    }
                } else {
                    Label("Sync from Server", systemImage: "arrow.down.circle.fill")
                        .font(.caption)
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.mini)
            .disabled(isSyncing)
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(Color.orange.opacity(0.1))
        .cornerRadius(8)
    }
}

/// ローカルにのみある署名がある場合の送信バナー
struct ProposeLocalSignaturesBannerView: View {
    let count: Int
    let isSending: Bool
    let onSend: () -> Void

    var body: some View {
        HStack {
            Image(systemName: "exclamationmark.circle.fill")
                .font(.caption)
                .foregroundStyle(.blue)

            Text("You have \(count) local signature(s)")
                .font(.caption)
                .foregroundStyle(.blue)
                .fontWeight(.medium)

            Spacer()

            Button(action: onSend) {
                if isSending {
                    HStack(spacing: 4) {
                        ProgressView()
                            .scaleEffect(0.7)
                        Text("Sending...")
                            .font(.caption)
                    }
                } else {
                    Label("Send to Server", systemImage: "arrow.up.circle.fill")
                        .font(.caption)
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.mini)
            .disabled(isSending)
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(Color.blue.opacity(0.1))
        .cornerRadius(8)
    }
}
