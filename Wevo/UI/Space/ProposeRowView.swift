//
//  ProposeRowView.swift
//  Wevo
//
//  Created by hidemune on 3/10/26.
//

import SwiftUI
import SwiftData

struct ProposeRowView: View {
    let propose: Propose
    let space: Space
    let onSigned: () -> Void

    @Environment(\.modelContext) private var modelContext

    @State private var shareURL: URL?
    @State private var showShareSheet = false
    @State private var shareError: String?
    @State private var isResending = false
    @State private var resendSuccess: Bool?
    @State private var resendErrorMessage: String?
    @State private var serverStatus: ServerStatus = .unknown
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

    enum ServerStatus: Equatable {
        case unknown
        case checking
        case exists
        case notFound
        case error(String)

        var icon: String {
            switch self {
            case .unknown: return "circle"
            case .checking: return "circle.dotted"
            case .exists: return "checkmark.circle.fill"
            case .notFound: return "xmark.circle"
            case .error: return "exclamationmark.triangle"
            }
        }

        var color: Color {
            switch self {
            case .unknown: return .gray
            case .checking: return .blue
            case .exists: return .green
            case .notFound: return .orange
            case .error: return .red
            }
        }

        var description: String {
            switch self {
            case .unknown: return "Unknown"
            case .checking: return "Checking..."
            case .exists: return "On server"
            case .notFound: return "Not on server"
            case .error(let message): return "Error: \(message)"
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                showProposeDetail = true
            } label: {
                VStack(alignment: .leading, spacing: 8) {
                    // メッセージ
                    HStack {
                        Text(propose.message)
                            .font(.headline)
                            .lineLimit(2)

                        Spacer()

                        Text(propose.createdAt, format: .dateTime.month().day().hour().minute())
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    // サーバーステータス
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

            // アクションボタン（Buttonの外）
            HStack {
                // 再送信ボタン
                Button {
                    Task {
                        await resendToServer()
                    }
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

                // AirDrop共有ボタン
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
                        Button {
                            prepareShare()
                        } label: {
                            Label("Share", systemImage: "square.and.arrow.up")
                                .labelStyle(.iconOnly)
                                .font(.caption)
                        }
                        .buttonStyle(.borderless)
                    }
                } else {
                    Button {
                        sharePropose()
                    } label: {
                        Label("Share", systemImage: "square.and.arrow.up")
                            .labelStyle(.iconOnly)
                            .font(.caption)
                    }
                    .buttonStyle(.borderless)
                }
#else
                Button {
                    sharePropose()
                } label: {
                    Label("Share", systemImage: "square.and.arrow.up")
                        .labelStyle(.iconOnly)
                        .font(.caption)
                }
                .buttonStyle(.borderless)
#endif
            }

            // ステータスメッセージ
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

            // サーバーに新しい署名がある場合の通知
            if hasNewSignatures {
                HStack {
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)

                    Text("Server has \(serverSignatures.count) new signature(s)")
                        .font(.caption)
                        .foregroundStyle(.orange)
                        .fontWeight(.medium)

                    Spacer()

                    Button {
                        Task {
                            await syncSignaturesFromServer()
                            onSigned()
                        }
                    } label: {
                        if isSyncingSignatures {
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
                    .disabled(isSyncingSignatures)
                }
                .padding(.vertical, 4)
                .padding(.horizontal, 8)
                .background(Color.orange.opacity(0.1))
                .cornerRadius(8)
            }

            // ローカルにのみある署名がある場合の通知
            if hasLocalOnlySignatures {
                HStack {
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.blue)

                    Text("You have \(localOnlySignatures.count) local signature(s)")
                        .font(.caption)
                        .foregroundStyle(.blue)
                        .fontWeight(.medium)

                    Spacer()

                    Button {
                        Task {
                            await sendLocalSignaturesToServer()
                        }
                    } label: {
                        if isSendingSignatures {
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
                    .disabled(isSendingSignatures)
                }
                .padding(.vertical, 4)
                .padding(.horizontal, 8)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(8)
            }

            if !propose.signatures.isEmpty {
                Divider()
                    .padding(.vertical, 4)

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Signatures:")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)

                        Spacer()

                        // 署名ボタン（自分の署名がない場合のみ表示）
                        if let identity = defaultIdentity, !hasMySignature(identity: identity), signSuccess != true {
                            Button {
                                Task {
                                    await signPropose(with: identity)
                                    // 親ビューでProposeリストを再読み込み
                                    onSigned()
                                }
                            } label: {
                                if isSigning {
                                    HStack(spacing: 4) {
                                        ProgressView()
                                            .scaleEffect(0.6)
                                        Text("Signing...")
                                            .font(.caption2)
                                    }
                                } else {
                                    Label("Sign", systemImage: "signature")
                                        .font(.caption2)
                                }
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.mini)
                            .disabled(isSigning)
                        }
                    }

                    // 署名ステータスメッセージ
                    if let signSuccess = signSuccess {
                        HStack {
                            Image(systemName: signSuccess ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .font(.caption2)
                                .foregroundStyle(signSuccess ? .green : .red)
                            Text(signSuccess ? "Signed successfully" : (signErrorMessage ?? "Failed to sign"))
                                .font(.caption2)
                                .foregroundStyle(signSuccess ? .green : .red)
                        }
                        .padding(.top, 2)
                    }

                    ForEach(propose.signatures) { signature in
                        SignatureRowView(signature: signature, myPublicKey: defaultIdentity?.publicKey)
                    }
                }
            }
        }
        .padding(.vertical, 8)
        .task(id: propose.signatures.count) {
            // 署名の数が変わったら再チェック
            await checkServerStatus()
        }
        .task {
            // 初期化時にURLを準備
            prepareShare()
        }
        .task {
            // デフォルトIdentityを読み込み
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

    private func prepareShare() {
        print("📤 Preparing share for propose ID: \(propose.id)")
        do {
            let url = try ProposeExporter.exportPropose(propose, space: space)
            print("📤 Export successful, URL: \(url.path)")
            shareURL = url
            shareError = nil
            print("📤 Set shareURL = \(url)")
        } catch {
            print("❌ Error exporting propose: \(error)")
            shareError = "Export failed"
        }
    }

    private func sharePropose() {
        print("📤 Starting share propose for ID: \(propose.id)")
        do {
            let url = try ProposeExporter.exportPropose(propose, space: space)
            print("📤 Export successful, URL: \(url.path)")
            shareURL = url
            showShareSheet = true
            shareError = nil
            print("📤 Set showShareSheet = true, shareURL = \(url)")
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

            // 3秒後にメッセージを消す
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            await MainActor.run {
                resendSuccess = nil
            }

        } catch {
            print("❌ Error resending propose: \(error)")
            await MainActor.run {
                isResending = false
                resendSuccess = false
                resendErrorMessage = error.localizedDescription
            }

            // 5秒後にエラーメッセージを消す
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
            await MainActor.run {
                self.defaultIdentity = nil
            }
            return
        }

        let getAllIdentitiesUseCase = GetAllIdentitiesUseCaseImpl(keychainRepository: KeychainRepositoryImpl())

        do {
            let identities = try getAllIdentitiesUseCase.execute()
            await MainActor.run {
                self.defaultIdentity = identities.first { $0.id == defaultIdentityID }
            }
        } catch {
            print("❌ Error loading default identity: \(error)")
            await MainActor.run {
                self.defaultIdentity = nil
            }
        }
    }

    private func hasMySignature(identity: Identity) -> Bool {
        let myPublicKey = identity.publicKey
        // ローカルの署名とサーバーから取得した署名の両方をチェック
        let allSignatures = propose.signatures + serverSignatures
        return allSignatures.contains { signature in
            signature.publicKey == myPublicKey
        }
    }

    private func signPropose(with identity: Identity) async {
        await MainActor.run {
            isSigning = true
            signSuccess = nil
            signErrorMessage = nil
        }

        let signProposeUseCase = SignProposeUseCaseImpl(
            keychainRepository: KeychainRepositoryImpl(),
            proposeRepository: ProposeRepositoryImpl(modelContext: modelContext)
        )

        do {
            try await signProposeUseCase.execute(to: propose.id, signIdentityID: identity.id)
            signSuccess = true
            isSigning = false

            // 3秒後に成功メッセージを消す
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            await MainActor.run {
                signSuccess = nil
            }
        } catch {
            print("❌ Error signing propose: \(error)")
            await MainActor.run {
                isSigning = false
                signSuccess = false
                signErrorMessage = error.localizedDescription
            }

            // 5秒後にエラーメッセージを消す
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            await MainActor.run {
                signSuccess = nil
                signErrorMessage = nil
            }
        }
    }

    private func syncSignaturesFromServer() async {
        await MainActor.run {
            isSyncingSignatures = true
        }

        let appendServerSignaturesToLocalProposeUseCase = AppendServerSignaturesToLocalProposeUseCaseImpl(
            proposeRepository: ProposeRepositoryImpl(modelContext: modelContext)
        )

        do {
            try appendServerSignaturesToLocalProposeUseCase.execute(proposeID: propose.id, with: serverSignatures)

            // 同期完了後、状態をリセット
            hasNewSignatures = false
            serverSignatures = []
            isSyncingSignatures = false
        } catch {
            print("❌ Failed to sync signatures locally: \(error)")
            isSyncingSignatures = false
        }
    }

    private func sendLocalSignaturesToServer() async {
        await MainActor.run {
            isSendingSignatures = true
        }

        let useCase = SendLocalSignaturesToServerUseCaseImpl()

        do {
            try await useCase.execute(propose: propose, serverURL: space.url)

            await MainActor.run {
                isSendingSignatures = false
                hasLocalOnlySignatures = false
                localOnlySignatures = []

                // サーバーステータスを再チェック
                Task {
                    await checkServerStatus()
                }
            }

        } catch {
            print("❌ Error sending local signatures to server: \(error)")
            await MainActor.run {
                isSendingSignatures = false
            }
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
        .modelContainer(for: [SpaceSwiftData.self, ProposeSwiftData.self, SignatureSwiftData.self], inMemory: true)
}
