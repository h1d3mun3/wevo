//
//  ProposeRowView.swift
//  Wevo
//
//  Created by hidemune on 3/10/26.
//

import SwiftUI
import os

// MARK: - Container

struct ProposeRowView: View {
    let propose: Propose
    let space: Space
    let onSigned: () -> Void
    var serverCheckTrigger: UUID = UUID()

    @Environment(\.dependencies) private var deps

    var body: some View {
        ProposeRowContent(
            viewModel: ProposeRowViewModel(propose: propose, space: space, deps: deps),
            propose: propose,
            onSigned: onSigned,
            serverCheckTrigger: serverCheckTrigger
        )
    }
}

// MARK: - Content

private struct ProposeRowContent: View {
    @State var viewModel: ProposeRowViewModel
    let propose: Propose
    let onSigned: () -> Void
    let serverCheckTrigger: UUID

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header section (message, timestamp, counterparty nickname)
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(viewModel.propose.message)
                        .font(.headline)
                        .lineLimit(2)

                    Spacer()

                    Text(viewModel.propose.createdAt, format: .dateTime.month().day().hour().minute())
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 4) {
                    Image(systemName: "person.fill")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text("To: \(viewModel.otherParticipantNames)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                statusBadge
            }

            actionBar
            statusMessages

            // Pending local resend banner
            if viewModel.pendingLocalResend {
                PendingLocalResendBannerView(isResending: viewModel.isResendingLocalSignature) {
                    Task { await viewModel.resendLocalSignature() }
                } onIgnore: {
                    viewModel.pendingLocalResend = false
                }
            }

            // Pending server update banner
            if let serverUpdate = viewModel.pendingServerUpdate {
                let terminalStatuses: Set<ProposeStatus> = [.honored, .parted, .dissolved]
                if terminalStatuses.contains(serverUpdate.status) {
                    PendingServerStatusBannerView(
                        status: serverUpdate.status,
                        isApplying: viewModel.isApplyingServerUpdate
                    ) {
                        Task {
                            await viewModel.acceptServerPropose(serverUpdate)
                            onSigned()
                        }
                    } onIgnore: {
                        viewModel.pendingServerUpdate = nil
                    }
                } else {
                    let isSelfSigned = viewModel.defaultIdentity?.publicKey == viewModel.propose.counterpartyPublicKey
                    PendingSignatureBannerView(
                        counterpartyNickname: viewModel.otherParticipantNames,
                        message: isSelfSigned ? "Your signature was sent to the server. Save locally?" : nil,
                        isAccepting: viewModel.isApplyingServerUpdate
                    ) {
                        Task {
                            await viewModel.acceptServerPropose(serverUpdate)
                            onSigned()
                        }
                    } onIgnore: {
                        viewModel.pendingServerUpdate = nil
                    }
                }
            }

            // Sign button (shown when identity is counterparty and status is proposed)
            if viewModel.shouldShowSignButton {
                signButton
            }

            // Dissolve button (only available in proposed state)
            if viewModel.propose.localStatus == .proposed {
                dissolveButton
            }

            // Honor / Part buttons (when in signed state)
            if viewModel.propose.localStatus == .signed {
                honorPartStubButtons
            }
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .onTapGesture {
            viewModel.showProposeDetail = true
        }
        .task(id: propose.localStatus) {
            await viewModel.checkServerStatus()
        }
        .task(id: serverCheckTrigger) {
            await viewModel.checkServerStatus()
        }
        .task {
            viewModel.prepareShare()
        }
        .task {
            await viewModel.loadDefaultIdentity()
        }
        .task {
            viewModel.loadContactNicknames()
        }
        .onChange(of: propose.updatedAt) { _, _ in
            viewModel.propose = propose
        }
        .sheet(isPresented: $viewModel.showProposeDetail) {
            ProposeDetailView(propose: viewModel.propose, space: viewModel.space)
        }
#if os(iOS)
        .sheet(isPresented: $viewModel.showShareSheet) {
            if let shareURL = viewModel.shareURL {
                ShareSheetView(items: [shareURL])
            }
        }
#endif
    }

    // MARK: - Sub Views

    @ViewBuilder
    private var statusBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: viewModel.propose.localStatus.statusIcon)
                .font(.caption2)
                .foregroundStyle(viewModel.propose.localStatus.statusColor)
            Text(viewModel.propose.localStatus.statusLabel)
                .font(.caption2)
                .foregroundStyle(viewModel.propose.localStatus.statusColor)

            Image(systemName: viewModel.serverStatus.icon)
                .font(.caption2)
                .foregroundStyle(viewModel.serverStatus.color)
            Text(viewModel.serverStatus.description)
                .font(.caption2)
                .foregroundStyle(viewModel.serverStatus.color)
        }
    }

    @ViewBuilder
    private var actionBar: some View {
        HStack {
            Button {
                Task { await viewModel.resendToServer() }
            } label: {
                if viewModel.isResending {
                    ProgressView()
                        .scaleEffect(0.7)
                } else {
                    Label("Resend", systemImage: "arrow.clockwise")
                        .labelStyle(.iconOnly)
                        .font(.caption)
                }
            }
            .buttonStyle(.borderless)
            .disabled(viewModel.isResending || viewModel.serverStatus == .exists)
            .opacity((viewModel.isResending || viewModel.serverStatus == .exists) ? 0.5 : 1.0)

#if os(iOS)
            if #available(iOS 16.0, *) {
                if let shareURL = viewModel.shareURL {
                    ShareLink(item: shareURL) {
                        Label("Share", systemImage: "square.and.arrow.up")
                            .labelStyle(.iconOnly)
                            .font(.caption)
                    }
                    .buttonStyle(.borderless)
                } else {
                    Button { viewModel.prepareShare() } label: {
                        Label("Share", systemImage: "square.and.arrow.up")
                            .labelStyle(.iconOnly)
                            .font(.caption)
                    }
                    .buttonStyle(.borderless)
                }
            } else {
                Button { viewModel.sharePropose() } label: {
                    Label("Share", systemImage: "square.and.arrow.up")
                        .labelStyle(.iconOnly)
                        .font(.caption)
                }
                .buttonStyle(.borderless)
            }
#else
            if let shareURL = viewModel.shareURL {
                ShareLink(item: shareURL) {
                    Label("Share", systemImage: "square.and.arrow.up")
                        .labelStyle(.iconOnly)
                        .font(.caption)
                }
                .buttonStyle(.borderless)
            } else {
                Button { viewModel.prepareShare() } label: {
                    Label("Share", systemImage: "square.and.arrow.up")
                        .labelStyle(.iconOnly)
                        .font(.caption)
                }
                .buttonStyle(.borderless)
            }
#endif
        }
    }

    @ViewBuilder
    private var statusMessages: some View {
        if let resendSuccess = viewModel.resendSuccess {
            HStack {
                Image(systemName: resendSuccess ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .font(.caption2)
                    .foregroundStyle(resendSuccess ? .green : .red)
                Text(resendSuccess ? "Sent to server" : (viewModel.resendErrorMessage ?? "Failed to send"))
                    .font(.caption2)
                    .foregroundStyle(resendSuccess ? .green : .red)
            }
        }

        if let shareError = viewModel.shareError {
            Text(shareError)
                .font(.caption2)
                .foregroundStyle(.red)
        }

        if let signSuccess = viewModel.signSuccess {
            HStack {
                Image(systemName: signSuccess ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .font(.caption2)
                    .foregroundStyle(signSuccess ? .green : .red)
                Text(signSuccess ? "Signed" : (viewModel.signErrorMessage ?? "Failed to sign"))
                    .font(.caption2)
                    .foregroundStyle(signSuccess ? .green : .red)
            }
        }

        if let honorSuccess = viewModel.honorSuccess {
            HStack {
                Image(systemName: honorSuccess ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .font(.caption2)
                    .foregroundStyle(honorSuccess ? .green : .red)
                Text(honorSuccess ? "Honor sent" : (viewModel.honorErrorMessage ?? "Failed to honor"))
                    .font(.caption2)
                    .foregroundStyle(honorSuccess ? .green : .red)
            }
        }

        if let partSuccess = viewModel.partSuccess {
            HStack {
                Image(systemName: partSuccess ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .font(.caption2)
                    .foregroundStyle(partSuccess ? .green : .red)
                Text(partSuccess ? "Part sent" : (viewModel.partErrorMessage ?? "Failed to part"))
                    .font(.caption2)
                    .foregroundStyle(partSuccess ? .green : .red)
            }
        }

        if let dissolveSuccess = viewModel.dissolveSuccess {
            HStack {
                Image(systemName: dissolveSuccess ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .font(.caption2)
                    .foregroundStyle(dissolveSuccess ? .green : .red)
                Text(dissolveSuccess ? "Dissolved" : (viewModel.dissolveErrorMessage ?? "Failed to dissolve"))
                    .font(.caption2)
                    .foregroundStyle(dissolveSuccess ? .green : .red)
            }
        }
    }

    @ViewBuilder
    private var signButton: some View {
        HStack {
            Spacer()
            Button {
                guard let identity = viewModel.defaultIdentity else { return }
                Task { await viewModel.signPropose(with: identity) }
            } label: {
                if viewModel.isSigning {
                    HStack(spacing: 4) {
                        ProgressView()
                            .scaleEffect(0.6)
                        Text("Signing...")
                            .font(.caption)
                    }
                } else {
                    Label("Sign", systemImage: "signature")
                        .font(.caption)
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(viewModel.isSigning)
        }
    }

    @ViewBuilder
    private var dissolveButton: some View {
        HStack {
            Spacer()
            Button {
                guard let identity = viewModel.defaultIdentity else { return }
                Task { await viewModel.dissolvePropose(with: identity) }
            } label: {
                if viewModel.isDissolving {
                    ProgressView().scaleEffect(0.7)
                } else if viewModel.dissolveSuccess == true {
                    Label("Dissolved", systemImage: "trash.circle.fill").font(.caption)
                } else {
                    Label("Dissolve", systemImage: "trash.circle").font(.caption)
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .tint(.red)
            .disabled(viewModel.isDissolving || viewModel.defaultIdentity == nil)
        }
    }

    @ViewBuilder
    private var honorPartStubButtons: some View {
        HStack(spacing: 8) {
            Spacer()

            Button {
                guard let identity = viewModel.defaultIdentity else { return }
                Task { await viewModel.honorPropose(with: identity) }
            } label: {
                if viewModel.isHonoring {
                    ProgressView().scaleEffect(0.7)
                } else if viewModel.myHonorSigned {
                    Label("Honor Sent", systemImage: "checkmark.seal.fill").font(.caption)
                } else {
                    Label("Honor", systemImage: "checkmark.seal").font(.caption)
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .tint(viewModel.myHonorSigned ? .green : .primary)
            .disabled(
                viewModel.isHonoring
                || viewModel.defaultIdentity == nil
                || viewModel.myHonorSigned
                || viewModel.myPartSigned
            )

            Button {
                guard let identity = viewModel.defaultIdentity else { return }
                Task { await viewModel.partPropose(with: identity) }
            } label: {
                if viewModel.isParting {
                    ProgressView().scaleEffect(0.7)
                } else if viewModel.myPartSigned {
                    Label("Part Sent", systemImage: "xmark.seal.fill").font(.caption)
                } else {
                    Label("Part", systemImage: "xmark.seal").font(.caption)
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .tint(viewModel.myPartSigned ? .orange : .primary)
            .disabled(viewModel.isParting || viewModel.defaultIdentity == nil || viewModel.myPartSigned)
        }
    }
}

// MARK: - ProposeStatus Extensions for UI

private extension ProposeStatus {
    var statusIcon: String {
        switch self {
        case .proposed:  return "clock"
        case .signed:    return "checkmark.circle"
        case .honored:   return "checkmark.seal.fill"
        case .parted:    return "xmark.seal"
        case .dissolved: return "trash.circle"
        }
    }

    var statusColor: Color {
        switch self {
        case .proposed:  return .orange
        case .signed:    return .blue
        case .honored:   return .green
        case .parted:    return .gray
        case .dissolved: return .red
        }
    }

    var statusLabel: String {
        switch self {
        case .proposed:  return "Proposed"
        case .signed:    return "Signed"
        case .honored:   return "Honored"
        case .parted:    return "Parted"
        case .dissolved: return "Dissolved"
        }
    }
}

#Preview("Propose Row") {
    let space = Space(
        id: UUID(),
        name: "Preview Space",
        url: "https://example.com",
        defaultIdentityID: nil,
        orderIndex: 0,
        createdAt: .now,
        updatedAt: .now
    )

    let propose = Propose(
        id: UUID(),
        spaceID: space.id,
        message: "Preview message",
        creatorPublicKey: "creatorPubKey",
        creatorSignature: "creatorSig",
        counterpartyPublicKey: "counterpartyPubKey",
        counterpartySignSignature: nil,
        createdAt: .now,
        updatedAt: .now
    )

    ProposeRowView(propose: propose, space: space, onSigned: {})
}
