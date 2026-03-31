//
//  ProposeRowView.swift
//  Wevo
//
//  Created by hidemune on 3/10/26.
//

import SwiftUI
import os

struct ProposeRowView: View {
    let propose: Propose
    let space: Space
    let onSigned: () -> Void
    var serverCheckTrigger: UUID = UUID()

    @Environment(\.dependencies) private var deps

    @State private var shareURL: URL?
    @State private var showShareSheet = false
    @State private var shareError: String?
    @State private var isResending = false
    @State private var resendSuccess: Bool?
    @State private var resendErrorMessage: String?
    @State private var serverStatus: ProposeServerStatus = .unknown
    @State private var isCheckingServer = false
    @State private var isSigning = false
    @State private var signSuccess: Bool?
    @State private var signErrorMessage: String?
    @State private var defaultIdentity: Identity?
    @State private var showProposeDetail = false
    @State private var contactNicknames: [String: String] = [:]

    /// Server HashedPropose when Counterparty has signed on server but not yet reflected locally
    @State private var pendingServerPropose: HashedPropose? = nil
    /// Whether signature acceptance is in progress
    @State private var isAcceptingSignature = false

    /// Terminal server status (honored/parted/dissolved) pending local reflection
    @State private var pendingStatusTransition: ProposeStatus? = nil
    /// Whether terminal status application is in progress
    @State private var isApplyingServerStatus = false

    @State private var isHonoring = false
    @State private var honorSuccess: Bool?
    @State private var honorErrorMessage: String?
    @State private var myHonorSigned = false

    @State private var isParting = false
    @State private var partSuccess: Bool?
    @State private var partErrorMessage: String?
    @State private var myPartSigned = false

    @State private var isDissolving = false
    @State private var dissolveSuccess: Bool?
    @State private var dissolveErrorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header section (message, timestamp, Counterparty nickname)
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(propose.message)
                        .font(.headline)
                        .lineLimit(2)

                    Spacer()

                    Text(propose.createdAt, format: .dateTime.month().day().hour().minute())
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                // Show other participants in header
                HStack(spacing: 4) {
                    Image(systemName: "person.fill")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text("To: \(otherParticipantNames)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                // Local status badge
                statusBadge
            }

            // Action buttons
            actionBar

            // Status messages
            statusMessages

            // Pending signature banner for Counterparty approval
            if let serverPropose = pendingServerPropose {
                let counterpartyName = otherParticipantNames
                let isSelfSigned = defaultIdentity?.publicKey == propose.counterpartyPublicKey
                PendingSignatureBannerView(
                    counterpartyNickname: counterpartyName,
                    message: isSelfSigned ? "Your signature was sent to the server. Save locally?" : nil,
                    isAccepting: isAcceptingSignature
                ) {
                    Task {
                        await acceptServerPropose(serverPropose)
                        onSigned()
                    }
                } onIgnore: {
                    // Ignore: just hide the banner (do not reflect locally)
                    pendingServerPropose = nil
                }
            }

            // Pending terminal status banner (honored/parted/dissolved from server)
            if let pendingStatus = pendingStatusTransition {
                PendingServerStatusBannerView(
                    status: pendingStatus,
                    isApplying: isApplyingServerStatus
                ) {
                    Task { await applyServerStatus(pendingStatus) }
                } onIgnore: {
                    pendingStatusTransition = nil
                }
            }

            // Sign button when Counterparty has not yet signed
            if shouldShowSignButton {
                signButton
            }

            // Dissolve button (only available in proposed state, for any participant)
            if propose.localStatus == .proposed {
                dissolveButton
            }

            // Honor / Part buttons (when in signed state)
            if propose.localStatus == .signed {
                honorPartStubButtons
            }
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .onTapGesture {
            showProposeDetail = true
        }
        .task(id: propose.localStatus) {
            // Check server status when local status changes
            await checkServerStatus()
        }
        .task(id: serverCheckTrigger) {
            // Check server status when pull-to-refresh is triggered
            await checkServerStatus()
        }
        .task {
            prepareShare()
        }
        .task {
            await loadDefaultIdentity()
        }
        .task {
            loadContactNicknames()
        }
        .sheet(isPresented: $showProposeDetail) {
            ProposeDetailView(propose: propose, space: space)
        }
#if os(iOS)
        .sheet(isPresented: $showShareSheet) {
            if let shareURL = shareURL {
                ShareSheetView(items: [shareURL])
            }
        }
#elseif os(macOS)
        .sheet(isPresented: $showShareSheet) {
            if let shareURL = shareURL {
                ShareSheetView(items: [shareURL])
            }
        }
#endif
    }

    // MARK: - Computed Properties

    /// Names of all participants other than the current user, joined by ", "
    /// Extracts all public keys from the Propose and filters out self,
    /// making it forward-compatible with future 1:n proposes
    private var otherParticipantNames: String {
        let myKey = defaultIdentity?.publicKey
        let otherKeys = propose.allParticipantPublicKeys.filter { $0 != myKey }
        if otherKeys.isEmpty { return "..." }
        return otherKeys
            .map { contactNicknames[$0] ?? String($0.prefix(12)) + "..." }
            .joined(separator: ", ")
    }

    /// Whether to show the Sign button
    /// Only shown when the identity is the Counterparty and the state is proposed
    private var shouldShowSignButton: Bool {
        guard let identity = defaultIdentity else { return false }
        let canSign = CanSignProposeUseCaseImpl().execute(identity: identity, propose: propose)
        return canSign
            && pendingServerPropose == nil
            && signSuccess != true
    }

    // MARK: - Sub Views

    /// Local status badge
    @ViewBuilder
    private var statusBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: propose.localStatus.statusIcon)
                .font(.caption2)
                .foregroundStyle(propose.localStatus.statusColor)
            Text(propose.localStatus.statusLabel)
                .font(.caption2)
                .foregroundStyle(propose.localStatus.statusColor)

            // Also show server status
            Image(systemName: serverStatus.icon)
                .font(.caption2)
                .foregroundStyle(serverStatus.color)
            Text(serverStatus.description)
                .font(.caption2)
                .foregroundStyle(serverStatus.color)
        }
    }

    @ViewBuilder
    private var actionBar: some View {
        HStack {
            Button {
                Task { await resendToServer() }
            } label: {
                if isResending {
                    ProgressView()
                        .scaleEffect(0.7)
                } else {
                    Label("Resend", systemImage: "arrow.clockwise")
                        .labelStyle(.iconOnly)
                        .font(.caption)
                }
            }
            .buttonStyle(.borderless)
            .disabled(isResending || serverStatus == .exists)
            .opacity((isResending || serverStatus == .exists) ? 0.5 : 1.0)

#if os(iOS)
            if #available(iOS 16.0, *) {
                if let shareURL = shareURL {
                    ShareLink(item: shareURL) {
                        Label("Share", systemImage: "square.and.arrow.up")
                            .labelStyle(.iconOnly)
                            .font(.caption)
                    }
                    .buttonStyle(.borderless)
                } else {
                    Button { prepareShare() } label: {
                        Label("Share", systemImage: "square.and.arrow.up")
                            .labelStyle(.iconOnly)
                            .font(.caption)
                    }
                    .buttonStyle(.borderless)
                }
            } else {
                Button { sharePropose() } label: {
                    Label("Share", systemImage: "square.and.arrow.up")
                        .labelStyle(.iconOnly)
                        .font(.caption)
                }
                .buttonStyle(.borderless)
            }
#else
            Button { sharePropose() } label: {
                Label("Share", systemImage: "square.and.arrow.up")
                    .labelStyle(.iconOnly)
                    .font(.caption)
            }
            .buttonStyle(.borderless)
#endif
        }
    }

    @ViewBuilder
    private var statusMessages: some View {
        if let resendSuccess = resendSuccess {
            HStack {
                Image(systemName: resendSuccess ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .font(.caption2)
                    .foregroundStyle(resendSuccess ? .green : .red)
                Text(resendSuccess ? "Sent to server" : (resendErrorMessage ?? "Failed to send"))
                    .font(.caption2)
                    .foregroundStyle(resendSuccess ? .green : .red)
            }
        }

        if let shareError = shareError {
            Text(shareError)
                .font(.caption2)
                .foregroundStyle(.red)
        }

        if let signSuccess = signSuccess {
            HStack {
                Image(systemName: signSuccess ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .font(.caption2)
                    .foregroundStyle(signSuccess ? .green : .red)
                Text(signSuccess ? "Signed" : (signErrorMessage ?? "Failed to sign"))
                    .font(.caption2)
                    .foregroundStyle(signSuccess ? .green : .red)
            }
        }

        if let honorSuccess = honorSuccess {
            HStack {
                Image(systemName: honorSuccess ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .font(.caption2)
                    .foregroundStyle(honorSuccess ? .green : .red)
                Text(honorSuccess ? "Honor sent" : (honorErrorMessage ?? "Failed to honor"))
                    .font(.caption2)
                    .foregroundStyle(honorSuccess ? .green : .red)
            }
        }

        if let partSuccess = partSuccess {
            HStack {
                Image(systemName: partSuccess ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .font(.caption2)
                    .foregroundStyle(partSuccess ? .green : .red)
                Text(partSuccess ? "Part sent" : (partErrorMessage ?? "Failed to part"))
                    .font(.caption2)
                    .foregroundStyle(partSuccess ? .green : .red)
            }
        }

        if let dissolveSuccess = dissolveSuccess {
            HStack {
                Image(systemName: dissolveSuccess ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .font(.caption2)
                    .foregroundStyle(dissolveSuccess ? .green : .red)
                Text(dissolveSuccess ? "Dissolved" : (dissolveErrorMessage ?? "Failed to dissolve"))
                    .font(.caption2)
                    .foregroundStyle(dissolveSuccess ? .green : .red)
            }
        }
    }

    /// Sign button (shown when identity is Counterparty and state is proposed)
    @ViewBuilder
    private var signButton: some View {
        HStack {
            Spacer()
            Button {
                guard let identity = defaultIdentity else { return }
                Task {
                    await signPropose(with: identity)
                }
            } label: {
                if isSigning {
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
            .disabled(isSigning)
        }
    }

    /// Dissolve button (shown when in proposed state)
    @ViewBuilder
    private var dissolveButton: some View {
        HStack {
            Spacer()
            Button {
                guard let identity = defaultIdentity else { return }
                Task { await dissolvePropose(with: identity) }
            } label: {
                if isDissolving {
                    ProgressView().scaleEffect(0.7)
                } else if dissolveSuccess == true {
                    Label("Dissolved", systemImage: "trash.circle.fill").font(.caption)
                } else {
                    Label("Dissolve", systemImage: "trash.circle").font(.caption)
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .tint(.red)
            .disabled(isDissolving || defaultIdentity == nil)
        }
    }

    /// Honor / Part buttons (shown when in signed state)
    @ViewBuilder
    private var honorPartStubButtons: some View {
        HStack(spacing: 8) {
            Spacer()

            Button {
                guard let identity = defaultIdentity else { return }
                Task { await honorPropose(with: identity) }
            } label: {
                if isHonoring {
                    ProgressView().scaleEffect(0.7)
                } else if myHonorSigned {
                    Label("Honor Sent", systemImage: "checkmark.seal.fill").font(.caption)
                } else {
                    Label("Honor", systemImage: "checkmark.seal").font(.caption)
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .tint(myHonorSigned ? .green : .primary)
            .disabled(isHonoring || defaultIdentity == nil || myHonorSigned || myPartSigned)

            Button {
                guard let identity = defaultIdentity else { return }
                Task { await partPropose(with: identity) }
            } label: {
                if isParting {
                    ProgressView().scaleEffect(0.7)
                } else if myPartSigned {
                    Label("Part Sent", systemImage: "xmark.seal.fill").font(.caption)
                } else {
                    Label("Part", systemImage: "xmark.seal").font(.caption)
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .tint(myPartSigned ? .orange : .primary)
            .disabled(isParting || defaultIdentity == nil || myPartSigned)
        }
    }

    // MARK: - Actions

    private func prepareShare() {
        let useCase = ExportProposeUseCaseImpl()
        do {
            shareURL = try useCase.execute(propose: propose, space: space)
            shareError = nil
        } catch {
            Logger.propose.error("Propose export error: \(error, privacy: .public)")
            shareError = "Export failed"
        }
    }

    private func sharePropose() {
        if shareURL == nil {
            prepareShare()
        }
        showShareSheet = true
    }

    private func resendToServer() async {
        await MainActor.run {
            isResending = true
            resendSuccess = nil
            resendErrorMessage = nil
        }

        let useCase = ResendProposeToServerUseCaseImpl()

        do {
            try await useCase.execute(propose: propose, serverURL: space.url)

            await MainActor.run {
                isResending = false
                resendSuccess = true
                serverStatus = .exists
            }

            try? await Task.sleep(nanoseconds: 3_000_000_000)
            await MainActor.run { resendSuccess = nil }

        } catch {
            Logger.propose.error("Propose resend error: \(error, privacy: .public)")
            await MainActor.run {
                isResending = false
                resendSuccess = false
                resendErrorMessage = error.localizedDescription
            }

            try? await Task.sleep(nanoseconds: 5_000_000_000)
            await MainActor.run {
                resendSuccess = nil
                resendErrorMessage = nil
            }
        }
    }

    private func checkServerStatus() async {
        guard space.url != "" else { return }
        
        guard !isCheckingServer else { return }

        await MainActor.run {
            isCheckingServer = true
            serverStatus = .checking
        }

        let useCase = CheckProposeServerStatusUseCaseImpl()

        do {
            let myPublicKey = await MainActor.run { defaultIdentity?.publicKey }
            let result = try await useCase.execute(propose: propose, serverURL: space.url, myPublicKey: myPublicKey)

            await MainActor.run {
                serverStatus = .exists
                isCheckingServer = false
                pendingServerPropose = result.pendingServerPropose
                if pendingStatusTransition == nil {
                    pendingStatusTransition = result.pendingStatusTransition
                }
                myHonorSigned = result.myHonorSigned
                myPartSigned = result.myPartSigned
            }

        } catch CheckProposeServerStatusUseCaseError.proposeNotFound {
            Logger.propose.info("Propose not found on server: \(propose.id, privacy: .private)")
            await MainActor.run {
                serverStatus = .notFound
                isCheckingServer = false
            }

        } catch {
            Logger.propose.warning("Server status check error: \(error, privacy: .public)")
            await MainActor.run {
                serverStatus = .error(error.localizedDescription)
                isCheckingServer = false
            }
        }
    }

    /// Check server status and automatically apply pending changes after own actions
    private func checkAndAutoApplyServerStatus() async {
        let useCase = AutoApplyServerChangesUseCaseImpl(proposeRepository: deps.proposeRepository)
        let myPublicKey = defaultIdentity?.publicKey
        do {
            try await useCase.execute(propose: propose, serverURL: space.url, myPublicKey: myPublicKey)
            onSigned()
        } catch {
            Logger.propose.warning("AutoApplyServerChanges error: \(error, privacy: .public)")
            // Fall back to a manual server check so the banner can appear as a recovery path.
            await checkServerStatus()
        }
    }

    private func loadDefaultIdentity() async {
        let useCase = GetDefaultIdentityForSpaceUseCaseImpl(keychainRepository: deps.keychainRepository)
        do {
            let identity = try useCase.execute(space: space)
            await MainActor.run { self.defaultIdentity = identity }
        } catch {
            Logger.identity.error("Error loading default Identity: \(error, privacy: .public)")
            await MainActor.run { self.defaultIdentity = nil }
        }
    }

    private func loadContactNicknames() {
        let useCase = GetContactNicknamesMapUseCaseImpl(contactRepository: deps.contactRepository)
        do {
            contactNicknames = try useCase.execute()
        } catch {
            Logger.contact.error("Error loading contact nicknames: \(error, privacy: .public)")
        }
    }

    private func signPropose(with identity: Identity) async {
        await MainActor.run {
            isSigning = true
            signSuccess = nil
            signErrorMessage = nil
        }

        let useCase = SignProposeServerOnlyUseCaseImpl(keychainRepository: deps.keychainRepository)

        do {
            let signature = try await useCase.execute(
                propose: propose,
                identityID: identity.id,
                serverURL: space.url
            )

            await MainActor.run {
                isSigning = false
                signSuccess = true
            }

            await checkAndAutoApplyServerStatus()
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            await MainActor.run { signSuccess = nil }

        } catch SignProposeServerOnlyUseCaseError.notCounterparty {
            Logger.propose.warning("This identity is not the Counterparty and cannot sign")
            await MainActor.run {
                isSigning = false
                signSuccess = false
                signErrorMessage = "This identity is not the Counterparty"
            }

            try? await Task.sleep(nanoseconds: 5_000_000_000)
            await MainActor.run {
                signSuccess = nil
                signErrorMessage = nil
            }

        } catch {
            Logger.propose.error("Signing error: \(error, privacy: .public)")
            await MainActor.run {
                isSigning = false
                signSuccess = false
                signErrorMessage = error.localizedDescription
            }

            try? await Task.sleep(nanoseconds: 5_000_000_000)
            await MainActor.run {
                signSuccess = nil
                signErrorMessage = nil
            }
        }
    }

    private func dissolvePropose(with identity: Identity) async {
        await MainActor.run { isDissolving = true; dissolveSuccess = nil; dissolveErrorMessage = nil }

        let useCase = DissolveProposeUseCaseImpl(keychainRepository: deps.keychainRepository)
        do {
            try await useCase.execute(propose: propose, identityID: identity.id, serverURL: space.url)
            await MainActor.run { isDissolving = false; dissolveSuccess = true }
            await checkAndAutoApplyServerStatus()
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            await MainActor.run { dissolveSuccess = nil }
        } catch {
            Logger.propose.error("Dissolve error: \(error, privacy: .public)")
            await MainActor.run { isDissolving = false; dissolveSuccess = false; dissolveErrorMessage = error.localizedDescription }
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            await MainActor.run { dissolveSuccess = nil; dissolveErrorMessage = nil }
        }
    }

    private func honorPropose(with identity: Identity) async {
        await MainActor.run { isHonoring = true; honorSuccess = nil; honorErrorMessage = nil }

        let useCase = HonorProposeUseCaseImpl(keychainRepository: deps.keychainRepository)
        do {
            try await useCase.execute(propose: propose, identityID: identity.id, serverURL: space.url)
            await MainActor.run { isHonoring = false; honorSuccess = true; myHonorSigned = true }
            await checkAndAutoApplyServerStatus()
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            await MainActor.run { honorSuccess = nil }
        } catch {
            Logger.propose.error("Honor error: \(error, privacy: .public)")
            await MainActor.run { isHonoring = false; honorSuccess = false; honorErrorMessage = error.localizedDescription }
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            await MainActor.run { honorSuccess = nil; honorErrorMessage = nil }
        }
    }

    private func partPropose(with identity: Identity) async {
        await MainActor.run { isParting = true; partSuccess = nil; partErrorMessage = nil }

        let useCase = PartProposeUseCaseImpl(keychainRepository: deps.keychainRepository)
        do {
            try await useCase.execute(propose: propose, identityID: identity.id, serverURL: space.url)
            await MainActor.run { isParting = false; partSuccess = true; myPartSigned = true }
            await checkAndAutoApplyServerStatus()
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            await MainActor.run { partSuccess = nil }
        } catch {
            Logger.propose.error("Part error: \(error, privacy: .public)")
            await MainActor.run { isParting = false; partSuccess = false; partErrorMessage = error.localizedDescription }
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            await MainActor.run { partSuccess = nil; partErrorMessage = nil }
        }
    }

    /// Apply terminal server status locally
    private func applyServerStatus(_ status: ProposeStatus) async {
        await MainActor.run { isApplyingServerStatus = true }

        let useCase = ApplyServerStatusToLocalProposeUseCaseImpl(
            proposeRepository: deps.proposeRepository
        )

        do {
            try useCase.execute(proposeID: propose.id, status: status)
            await MainActor.run {
                isApplyingServerStatus = false
                pendingStatusTransition = nil
            }
            Logger.propose.info("Applied server status (\(status.rawValue, privacy: .public)) locally")
            onSigned()
        } catch {
            Logger.propose.error("Failed to apply server status locally: \(error, privacy: .public)")
            await MainActor.run { isApplyingServerStatus = false }
        }
    }

    /// Accept the server HashedPropose and reflect all signatures locally
    private func acceptServerPropose(_ serverPropose: HashedPropose) async {
        await MainActor.run { isAcceptingSignature = true }

        let useCase = AppendServerSignaturesToLocalProposeUseCaseImpl(
            proposeRepository: deps.proposeRepository
        )

        do {
            try useCase.execute(proposeID: propose.id, serverPropose: serverPropose)

            await MainActor.run {
                isAcceptingSignature = false
                pendingServerPropose = nil
            }
            Logger.propose.info("Accepted server signatures and reflected them locally")
        } catch {
            Logger.propose.error("Failed to reflect server signatures locally: \(error, privacy: .public)")
            await MainActor.run { isAcceptingSignature = false }
        }
    }
}

// MARK: - ProposeStatus Extensions for UI

private extension ProposeStatus {
    var statusIcon: String {
        switch self {
        case .proposed: return "clock"
        case .signed:   return "checkmark.circle"
        case .honored:  return "checkmark.seal.fill"
        case .parted:   return "xmark.seal"
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
