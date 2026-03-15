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
    /// Custom message to display (nil = default "X signed on the server")
    var message: String? = nil
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

                Text(message ?? "\(counterpartyNickname) signed on the server")
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

/// Banner displayed when the server has reached a terminal status (honored/parted/dissolved)
/// that has not yet been reflected locally
struct PendingServerStatusBannerView: View {
    let status: ProposeStatus
    let isApplying: Bool
    let onApply: () -> Void
    let onIgnore: () -> Void

    private var bannerColor: Color {
        switch status {
        case .honored:   return .green
        case .parted:    return .gray
        case .dissolved: return .red
        default:         return .orange
        }
    }

    private var bannerIcon: String {
        switch status {
        case .honored:   return "checkmark.seal.fill"
        case .parted:    return "xmark.seal"
        case .dissolved: return "trash.circle"
        default:         return "exclamationmark.circle"
        }
    }

    private var bannerMessage: String {
        switch status {
        case .honored:   return "Server status: Honored — reflect locally?"
        case .parted:    return "Server status: Parted — reflect locally?"
        case .dissolved: return "Server status: Dissolved — reflect locally?"
        default:         return "Server status updated — reflect locally?"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: bannerIcon)
                    .font(.caption)
                    .foregroundStyle(bannerColor)

                Text(bannerMessage)
                    .font(.caption)
                    .foregroundStyle(bannerColor)
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
                .disabled(isApplying)

                Button(action: onApply) {
                    if isApplying {
                        HStack(spacing: 4) {
                            ProgressView()
                                .scaleEffect(0.7)
                            Text("Applying...")
                                .font(.caption)
                        }
                    } else {
                        Label("Apply", systemImage: "arrow.down.circle.fill")
                            .font(.caption)
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.mini)
                .tint(bannerColor)
                .disabled(isApplying)
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(bannerColor.opacity(0.1))
        .cornerRadius(8)
    }
}
