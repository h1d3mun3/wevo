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
    @State private var serverSignatures: [Signature] = []
    @State private var hasNewSignatures = false
    @State private var isSyncingSignatures = false
    @State private var localOnlySignatures: [Signature] = []
    @State private var hasLocalOnlySignatures = false
    @State private var isSendingSignatures = false
    @State private var showProposeDetail = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // メッセージ部分
            Button {
                showProposeDetail = true
            } label: {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(propose.message)
                            .font(.headline)
                            .lineLimit(2)

                        Spacer()

                        Text(propose.createdAt, format: .dateTime.month().day().hour().minute())
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    HStack(spacing: 4) {
                        Image(systemName: serverStatus.icon)
                            .font(.caption2)
                            .foregroundStyle(serverStatus.color)
                        Text(serverStatus.description)
                            .font(.caption2)
                            .foregroundStyle(serverStatus.color)
                    }

                    Text("\(propose.signatures.count) signature(s)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)

            // アクションボタン
            actionBar

            // ステータスメッセージ
            statusMessages

            // サーバー同期バナー
            if hasNewSignatures {
                ProposeNewSignaturesBannerView(
                    count: serverSignatures.count,
                    isSyncing: isSyncingSignatures
                ) {
                    Task {
                        await syncSignaturesFromServer()
                        onSigned()
                    }
                }
            }

            if hasLocalOnlySignatures {
                ProposeLocalSignaturesBannerView(
                    count: localOnlySignatures.count,
                    isSending: isSendingSignatures
                ) {
                    Task { await sendLocalSignaturesToServer() }
                }
            }

            // 署名セクション
            if !propose.signatures.isEmpty {
                ProposeSignaturesSectionView(
                    signatures: propose.signatures,
                    defaultIdentity: defaultIdentity,
                    showSignButton: shouldShowSignButton,
                    isSigning: isSigning,
                    signSuccess: signSuccess,
                    signErrorMessage: signErrorMessage
                ) {
                    guard let identity = defaultIdentity else { return }
                    Task {
                        await signPropose(with: identity)
                        onSigned()
                    }
                }
            }
        }
        .padding(.vertical, 8)
        .task(id: propose.signatures.count) {
            await checkServerStatus()
        }
        .task {
            prepareShare()
        }
        .task {
            await loadDefaultIdentity()
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

    private var shouldShowSignButton: Bool {
        guard let identity = defaultIdentity else { return false }
        return !hasMySignature(identity: identity) && signSuccess != true
    }

    // MARK: - Sub Views

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
                Text(resendSuccess ? "Sent to server successfully" : (resendErrorMessage ?? "Failed to send to server"))
                    .font(.caption2)
                    .foregroundStyle(resendSuccess ? .green : .red)
            }
        }

        if let shareError = shareError {
            Text(shareError)
                .font(.caption2)
                .foregroundStyle(.red)
        }
    }

    // MARK: - Actions

    private func prepareShare() {
        let useCase = ExportProposeUseCaseImpl()
        do {
            shareURL = try useCase.execute(propose: propose, space: space)
            shareError = nil
        } catch {
            print("❌ Error exporting propose: \(error)")
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
            print("❌ Error exporting propose: \(error)")
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
            print("❌ Error resending propose: \(error)")
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
            let status = try await useCase.execute(propose: propose, serverURL: space.url)

            await MainActor.run {
                serverStatus = .exists
                isCheckingServer = false
                self.serverSignatures = status.newServerSignatures
                self.hasNewSignatures = !status.newServerSignatures.isEmpty
                self.localOnlySignatures = status.localOnlySignatures
                self.hasLocalOnlySignatures = !status.localOnlySignatures.isEmpty
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

            print("⚠️ Error checking propose on server: \(error)")
            await MainActor.run {
                serverStatus = .error(error.localizedDescription)
                isCheckingServer = false
            }

        } catch {
            print("⚠️ Unexpected error checking propose: \(error)")
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
            print("❌ Error loading default identity: \(error)")
            await MainActor.run { self.defaultIdentity = nil }
        }
    }

    private func hasMySignature(identity: Identity) -> Bool {
        let useCase = HasIdentitySignedProposeUseCaseImpl()
        return useCase.execute(
            identity: identity,
            proposeSignatures: propose.signatures,
            serverSignatures: serverSignatures
        )
    }

    private func signPropose(with identity: Identity) async {
        await MainActor.run {
            isSigning = true
            signSuccess = nil
            signErrorMessage = nil
        }

        let signProposeUseCase = SignProposeUseCaseImpl(
            keychainRepository: deps.keychainRepository,
            proposeRepository: deps.proposeRepository
        )

        do {
            try await signProposeUseCase.execute(to: propose.id, signIdentityID: identity.id)
            signSuccess = true
            isSigning = false

            try? await Task.sleep(nanoseconds: 3_000_000_000)
            await MainActor.run { signSuccess = nil }
        } catch {
            print("❌ Error signing propose: \(error)")
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

    private func syncSignaturesFromServer() async {
        await MainActor.run { isSyncingSignatures = true }

        let useCase = AppendServerSignaturesToLocalProposeUseCaseImpl(
            proposeRepository: deps.proposeRepository
        )

        do {
            try useCase.execute(proposeID: propose.id, with: serverSignatures)
            hasNewSignatures = false
            serverSignatures = []
            isSyncingSignatures = false
        } catch {
            print("❌ Failed to sync signatures locally: \(error)")
            isSyncingSignatures = false
        }
    }

    private func sendLocalSignaturesToServer() async {
        await MainActor.run { isSendingSignatures = true }

        let useCase = SendLocalSignaturesToServerUseCaseImpl()

        do {
            try await useCase.execute(propose: propose, serverURL: space.url)

            await MainActor.run {
                isSendingSignatures = false
                hasLocalOnlySignatures = false
                localOnlySignatures = []
                Task { await checkServerStatus() }
            }

        } catch {
            print("❌ Error sending local signatures to server: \(error)")
            await MainActor.run { isSendingSignatures = false }
        }
    }
}

#Preview("Propose Row") {
    let signature = Signature(
        id: UUID(),
        publicKey: "PreviewPk",
        signature: "PreviewSig",
        createdAt: .now
    )

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
        signatures: [signature],
        createdAt: .now,
        updatedAt: .now
    )

    ProposeRowView(propose: propose, space: space, onSigned: {})
}
