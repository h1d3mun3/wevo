//
//  ProposeRowView.swift
//  Wevo
//
//  Created by hidemune on 3/10/26.
//

import SwiftUI

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

    /// Counterparty signature retrieved from server (not yet reflected locally)
    @State private var pendingCounterpartySignSignature: String? = nil
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

                // Show Counterparty nickname in header
                let counterpartyName = contactNicknames[propose.counterpartyPublicKey]
                    ?? String(propose.counterpartyPublicKey.prefix(12)) + "..."
                HStack(spacing: 4) {
                    Image(systemName: "person.fill")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text("To: \(counterpartyName)")
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
            if let pendingSig = pendingCounterpartySignSignature {
                let counterpartyName = contactNicknames[propose.counterpartyPublicKey]
                    ?? String(propose.counterpartyPublicKey.prefix(12)) + "..."
                let isSelfSigned = defaultIdentity?.publicKey == propose.counterpartyPublicKey
                PendingSignatureBannerView(
                    counterpartyNickname: counterpartyName,
                    message: isSelfSigned ? "Your signature was sent to the server. Save locally?" : nil,
                    isAccepting: isAcceptingSignature
                ) {
                    Task {
                        await acceptCounterpartySignature(signature: pendingSig)
                        onSigned()
                    }
                } onIgnore: {
                    // Ignore: just hide the banner (do not reflect locally)
                    pendingCounterpartySignSignature = nil
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

    /// Whether to show the Sign button
    /// Only shown when the identity is the Counterparty and the state is proposed
    private var shouldShowSignButton: Bool {
        guard let identity = defaultIdentity else { return false }
        return identity.publicKey == propose.counterpartyPublicKey
            && propose.localStatus == .proposed
            && pendingCounterpartySignSignature == nil
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
            print("❌ Propose export error: \(error)")
            shareError = "Export failed"
        }
    }

    private func sharePropose() {
        let useCase = ExportProposeUseCaseImpl()
        do {
            shareURL = try useCase.execute(propose: propose, space: space)
            showShareSheet = true
            shareError = nil
        } catch {
            print("❌ Propose export error: \(error)")
            shareError = "Export failed"
        }
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
            print("❌ Propose resend error: \(error)")
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
                pendingCounterpartySignSignature = result.pendingCounterpartySignSignature
                if pendingStatusTransition == nil {
                    pendingStatusTransition = result.pendingStatusTransition
                }
                myHonorSigned = result.myHonorSigned
                myPartSigned = result.myPartSigned
            }

        } catch let error as CheckProposeServerStatusUseCaseError {
            await MainActor.run {
                serverStatus = .error(error.localizedDescription)
                isCheckingServer = false
            }

        } catch let error as ProposeAPIClient.APIError {
            if case .httpError(let statusCode) = error, statusCode == 404 {
                print("ℹ️ Propose not found on server: \(propose.id)")
                await MainActor.run {
                    serverStatus = .notFound
                    isCheckingServer = false
                }
                return
            }

            print("⚠️ Server status check error: \(error)")
            await MainActor.run {
                serverStatus = .error(error.localizedDescription)
                isCheckingServer = false
            }

        } catch {
            print("⚠️ Unexpected error: \(error)")
            await MainActor.run {
                serverStatus = .error(error.localizedDescription)
                isCheckingServer = false
            }
        }
    }

    private func loadDefaultIdentity() async {
        guard let defaultIdentityID = space.defaultIdentityID else {
            await MainActor.run { self.defaultIdentity = nil }
            return
        }

        let getAllIdentitiesUseCase = GetAllIdentitiesUseCaseImpl(keychainRepository: deps.keychainRepository)

        do {
            let identities = try getAllIdentitiesUseCase.execute()
            await MainActor.run {
                self.defaultIdentity = identities.first { $0.id == defaultIdentityID }
            }
        } catch {
            print("❌ Error loading default Identity: \(error)")
            await MainActor.run { self.defaultIdentity = nil }
        }
    }

    private func loadContactNicknames() {
        let useCase = GetAllContactsUseCaseImpl(contactRepository: deps.contactRepository)
        do {
            let contacts = try useCase.execute()
            contactNicknames = Dictionary(uniqueKeysWithValues: contacts.map { ($0.publicKey, $0.nickname) })
        } catch {
            print("❌ Error loading contact nicknames: \(error)")
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
                // Show confirmation banner instead of auto-saving locally
                pendingCounterpartySignSignature = signature
            }

            await checkServerStatus()
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            await MainActor.run { signSuccess = nil }

        } catch SignProposeServerOnlyUseCaseError.notCounterparty {
            print("⚠️ This identity is not the Counterparty and cannot sign")
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
            print("❌ Signing error: \(error)")
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
            await checkServerStatus()
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            await MainActor.run { dissolveSuccess = nil }
        } catch {
            print("❌ Dissolve error: \(error)")
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
            await checkServerStatus()
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            await MainActor.run { honorSuccess = nil }
        } catch {
            print("❌ Honor error: \(error)")
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
            await checkServerStatus()
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            await MainActor.run { partSuccess = nil }
        } catch {
            print("❌ Part error: \(error)")
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
            print("✅ Applied server status (\(status.rawValue)) locally")
            onSigned()
        } catch {
            print("❌ Failed to apply server status locally: \(error)")
            await MainActor.run { isApplyingServerStatus = false }
        }
    }

    /// Accept the Counterparty's server signature and reflect it locally
    private func acceptCounterpartySignature(signature: String) async {
        await MainActor.run { isAcceptingSignature = true }

        let useCase = AppendServerSignaturesToLocalProposeUseCaseImpl(
            proposeRepository: deps.proposeRepository
        )

        do {
            try useCase.execute(proposeID: propose.id, counterpartySignSignature: signature)

            await MainActor.run {
                isAcceptingSignature = false
                pendingCounterpartySignSignature = nil
            }
            print("✅ Accepted Counterparty signature and reflected it locally")
        } catch {
            print("❌ Failed to reflect Counterparty signature locally: \(error)")
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
