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
    @State private var showProposeDetail = false
    @State private var contactNicknames: [String: String] = [:]

    /// サーバーで取得したCounterpartyの署名（ローカル未反映）
    @State private var pendingCounterpartySignSignature: String? = nil
    /// 署名承認処理中かどうか
    @State private var isAcceptingSignature = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // ヘッダー部分（メッセージ・日時・Counterpartyニックネーム）
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

                // CounterpartyのニックネームをHeaderに表示
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

                // ローカルステータスバッジ
                statusBadge
            }

            // アクションボタン
            actionBar

            // ステータスメッセージ
            statusMessages

            // Counterpartyの承認待ち署名バナー
            if let pendingSig = pendingCounterpartySignSignature {
                let counterpartyName = contactNicknames[propose.counterpartyPublicKey]
                    ?? String(propose.counterpartyPublicKey.prefix(12)) + "..."
                PendingSignatureBannerView(
                    counterpartyNickname: counterpartyName,
                    isAccepting: isAcceptingSignature
                ) {
                    Task {
                        await acceptCounterpartySignature(signature: pendingSig)
                        onSigned()
                    }
                } onIgnore: {
                    // 無視: バナーを非表示にするだけ（ローカルには反映しない）
                    pendingCounterpartySignSignature = nil
                }
            }

            // Counterpartyがまだ署名していない場合の署名ボタン
            if shouldShowSignButton {
                signButton
            }

            // Honor / Part ボタン（signed状態のとき）
            // TODO: PoC段階のため、Honor/Partは将来実装
            // signed状態のUI表示のみ（ボタンはスタブ）
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
            // ローカルステータスが変化したときにサーバーステータスを確認
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

    /// Signボタンを表示するかどうか
    /// Counterpartyかつproposed状態のときのみ表示
    private var shouldShowSignButton: Bool {
        guard let identity = defaultIdentity else { return false }
        // 自分がCounterpartyで、かつまだ署名していない（proposed状態）
        return identity.publicKey == propose.counterpartyPublicKey
            && propose.localStatus == .proposed
            && signSuccess != true
    }

    // MARK: - Sub Views

    /// ローカルステータスバッジ
    @ViewBuilder
    private var statusBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: propose.localStatus.statusIcon)
                .font(.caption2)
                .foregroundStyle(propose.localStatus.statusColor)
            Text(propose.localStatus.statusLabel)
                .font(.caption2)
                .foregroundStyle(propose.localStatus.statusColor)

            // サーバーステータスを追加で表示
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
                Text(resendSuccess ? "サーバーに送信しました" : (resendErrorMessage ?? "送信に失敗しました"))
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
                Text(signSuccess ? "署名しました" : (signErrorMessage ?? "署名に失敗しました"))
                    .font(.caption2)
                    .foregroundStyle(signSuccess ? .green : .red)
            }
        }
    }

    /// Signボタン（Counterpartyかつproposed状態のとき表示）
    @ViewBuilder
    private var signButton: some View {
        HStack {
            Spacer()
            Button {
                guard let identity = defaultIdentity else { return }
                Task {
                    await signPropose(with: identity)
                    onSigned()
                }
            } label: {
                if isSigning {
                    HStack(spacing: 4) {
                        ProgressView()
                            .scaleEffect(0.6)
                        Text("署名中...")
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

    /// Honor / Part スタブボタン（PoCのため将来実装）
    @ViewBuilder
    private var honorPartStubButtons: some View {
        HStack(spacing: 8) {
            Spacer()

            // TODO: PoC後にHonor機能を実装する
            Button {
                print("TODO: Honor機能は将来実装予定")
            } label: {
                Label("Honor", systemImage: "checkmark.seal")
                    .font(.caption)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .tint(.green)

            // TODO: PoC後にPart機能を実装する
            Button {
                print("TODO: Part機能は将来実装予定")
            } label: {
                Label("Part", systemImage: "xmark.seal")
                    .font(.caption)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .tint(.orange)
        }
    }

    // MARK: - Actions

    private func prepareShare() {
        let useCase = ExportProposeUseCaseImpl()
        do {
            shareURL = try useCase.execute(propose: propose, space: space)
            shareError = nil
        } catch {
            print("❌ Proposeエクスポートエラー: \(error)")
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
            print("❌ Proposeエクスポートエラー: \(error)")
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
            print("❌ Propose再送信エラー: \(error)")
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
            let result = try await useCase.execute(propose: propose, serverURL: space.url)

            await MainActor.run {
                serverStatus = .exists
                isCheckingServer = false
                // Counterpartyの承認待ち署名を設定
                pendingCounterpartySignSignature = result.pendingCounterpartySignSignature
            }

        } catch let error as CheckProposeServerStatusUseCaseError {
            await MainActor.run {
                serverStatus = .error(error.localizedDescription)
                isCheckingServer = false
            }

        } catch let error as ProposeAPIClient.APIError {
            if case .httpError(let statusCode) = error, statusCode == 404 {
                print("ℹ️ Proposeがサーバーに見つかりません: \(propose.id)")
                await MainActor.run {
                    serverStatus = .notFound
                    isCheckingServer = false
                }
                return
            }

            print("⚠️ サーバーステータス確認エラー: \(error)")
            await MainActor.run {
                serverStatus = .error(error.localizedDescription)
                isCheckingServer = false
            }

        } catch {
            print("⚠️ 予期しないエラー: \(error)")
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
            print("❌ デフォルトIdentityの読み込みエラー: \(error)")
            await MainActor.run { self.defaultIdentity = nil }
        }
    }

    private func loadContactNicknames() {
        let useCase = GetAllContactsUseCaseImpl(contactRepository: deps.contactRepository)
        do {
            let contacts = try useCase.execute()
            contactNicknames = Dictionary(uniqueKeysWithValues: contacts.map { ($0.publicKey, $0.nickname) })
        } catch {
            print("❌ Contactニックネームの読み込みエラー: \(error)")
        }
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

            await MainActor.run {
                signSuccess = true
                isSigning = false
            }

            try? await Task.sleep(nanoseconds: 3_000_000_000)
            await MainActor.run { signSuccess = nil }

        } catch SignProposeUseCaseError.notCounterparty {
            print("⚠️ このIdentityはCounterpartyではないため署名できません")
            await MainActor.run {
                isSigning = false
                signSuccess = false
                signErrorMessage = "このIdentityはCounterpartyではありません"
            }

            try? await Task.sleep(nanoseconds: 5_000_000_000)
            await MainActor.run {
                signSuccess = nil
                signErrorMessage = nil
            }

        } catch {
            print("❌ 署名エラー: \(error)")
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

    /// Counterpartyのサーバー署名を承認してローカルに反映する
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
            print("✅ Counterparty署名を承認してローカルに反映しました")
        } catch {
            print("❌ Counterparty署名の反映に失敗しました: \(error)")
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
