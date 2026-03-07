//
//  SpaceDetailView.swift
//  Wevo
//
//  Created by hidemune on 3/6/26.
//

import SwiftUI
import SwiftData

struct SpaceDetailView: View {
    let space: Space
    
    @Environment(\.modelContext) private var modelContext
    
    @State private var proposes: [Propose] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var defaultIdentity: Identity?
    @State private var shouldShowCreatePropose = false
    @State private var shouldShowEditSpace = false
    @State private var currentSpace: Space
    
    init(space: Space) {
        self.space = space
        _currentSpace = State(initialValue: space)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(currentSpace.name)
                            .font(.title)
                            .fontWeight(.bold)
                        
                        Text(currentSpace.url)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        if let identity = defaultIdentity {
                            HStack {
                                Image(systemName: "key.fill")
                                    .foregroundStyle(.secondary)
                                Text("Default Key: \(identity.nickname)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    
                    Spacer()
                    
                    Button {
                        shouldShowEditSpace = true
                    } label: {
                        Image(systemName: "pencil.circle.fill")
                            .font(.title2)
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color(.systemBackground))
            
            Divider()
            
            // Content
            if isLoading {
                Spacer()
                ProgressView("Loading proposes...")
                    .progressViewStyle(.circular)
                Spacer()
            } else if let errorMessage = errorMessage {
                Spacer()
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundStyle(.red)
                    Text(errorMessage)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    Button("Retry") {
                        loadProposesFromLocal()
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
                Spacer()
            } else if proposes.isEmpty {
                Spacer()
                VStack(spacing: 16) {
                    Image(systemName: "doc.text")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    Text("No proposes found")
                        .foregroundStyle(.secondary)
                    if defaultIdentity == nil {
                        Text("Please set a default key for this space")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
                Spacer()
            } else {
                List {
                    ForEach(proposes) { propose in
                        ProposeRowView(propose: propose, space: space) {
                            loadProposesFromLocal()
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle(currentSpace.name)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    shouldShowCreatePropose = true
                } label: {
                    Label("Create Propose", systemImage: "plus")
                }
                .disabled(defaultIdentity == nil)
            }
        }
        .task(id: space.id) {
            await loadDefaultIdentity()
            loadProposesFromLocal()
        }
        .refreshable {
            loadProposesFromLocal()
        }
        .sheet(isPresented: $shouldShowCreatePropose) {
            if let identity = defaultIdentity {
                CreateProposeView(space: currentSpace, identity: identity) {
                    Task {
                        loadProposesFromLocal()
                    }
                }
            }
        }
        .sheet(isPresented: $shouldShowEditSpace) {
            EditSpaceView(space: currentSpace) {
                Task {
                    await reloadSpace()
                }
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
        
        do {
            let identities = try KeychainRepository.shared.getAllIdentities()
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
    
    private func loadProposesFromLocal() {
        isLoading = true
        errorMessage = nil
        
        do {
            let repository = ProposeRepository(modelContext: modelContext)
            let loadedProposes = try repository.fetchAll(for: currentSpace.id)
            
            proposes = loadedProposes
            isLoading = false
            
            if loadedProposes.isEmpty {
                print("ℹ️ No proposes found locally for space: \(currentSpace.name)")
            } else {
                print("✅ Loaded \(loadedProposes.count) proposes from local storage")
            }
        } catch {
            print("❌ Error loading proposes from local storage: \(error)")
            isLoading = false
            errorMessage = "Failed to load proposes: \(error.localizedDescription)"
            proposes = []
        }
    }
    
    private func reloadSpace() async {
        await MainActor.run {
            let repository = SpaceRepository(modelContext: modelContext)
            do {
                if let updatedSpace = try? repository.fetch(by: space.id) {
                    currentSpace = updatedSpace
                    print("✅ Space reloaded: \(updatedSpace.name)")
                }
            }
        }
    }
}

// MARK: - Propose Row View

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
        NavigationLink {
            ProposeDetailViewFromEntity(propose: propose, space: space, modelContext: modelContext)
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
                
                // ハッシュ
                HStack {
                    Text("Hash:")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(propose.payloadHash.prefix(16) + "...")
                        .font(.caption)
                        .fontDesign(.monospaced)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    // サーバーステータス
                    HStack(spacing: 4) {
                        Image(systemName: serverStatus.icon)
                            .font(.caption2)
                            .foregroundStyle(serverStatus.color)
                        Text(serverStatus.description)
                            .font(.caption2)
                            .foregroundStyle(serverStatus.color)
                    }
                }
                
                HStack {
                    Text("ID:")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(propose.id.uuidString)
                        .font(.caption)
                        .fontDesign(.monospaced)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                
                HStack {
                    Image(systemName: "signature")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(propose.signatures.count) signature(s)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Spacer()
                    
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
                        if let identity = defaultIdentity, !hasMySignature(identity: identity) {
                            Button {
                                Task {
                                    await signPropose(with: identity)
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
        }
        .buttonStyle(.plain)
        .task {
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
        #if os(iOS)
        .sheet(isPresented: $showShareSheet) {
            if let shareURL = shareURL {
                ShareSheet(items: [shareURL])
            }
        }
        #elseif os(macOS)
        .sheet(isPresented: $showShareSheet) {
            if let shareURL = shareURL {
                ShareSheet(items: [shareURL])
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
        
        do {
            // URLを確認
            guard let baseURL = URL(string: space.url) else {
                await MainActor.run {
                    isResending = false
                    resendSuccess = false
                    resendErrorMessage = "Invalid server URL"
                }
                return
            }
            
            // 最初のSignatureを取得（Proposeを作成した人の署名）
            guard let firstSignature = propose.signatures.first else {
                await MainActor.run {
                    isResending = false
                    resendSuccess = false
                    resendErrorMessage = "No signature found"
                }
                return
            }

            // ProposeInputを作成（ハッシュのみ送信）
            let input = ProposeAPIClient.ProposeInput(
                id: propose.id,
                payloadHash: propose.payloadHash,
                publicKey: firstSignature.publicKey,
                signatures: propose.signatures.compactMap({
                    return ProposeAPIClient.SignInput(publicKey: $0.publicKey, signature: $0.signature)
                })
            )
            
            // APIクライアントで送信
            let client = ProposeAPIClient(baseURL: baseURL)
            try await client.createPropose(input: input)
            
            print("✅ Propose resent to server successfully: \(propose.id)")
            
            await MainActor.run {
                isResending = false
                resendSuccess = true
                serverStatus = .exists // ステータスを更新
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
        
        do {
            // URLを確認
            guard let baseURL = URL(string: space.url) else {
                await MainActor.run {
                    serverStatus = .error("Invalid URL")
                    isCheckingServer = false
                }
                return
            }
            
            // APIクライアントで確認
            let client = ProposeAPIClient(baseURL: baseURL)
            let hashedPropose = try await client.getPropose(proposeID: propose.id)
            
            // 成功 = サーバーに存在する
            print("✅ Propose exists on server: \(propose.id)")
            print("📊 Server has \(hashedPropose.signatures.count) signatures, local has \(propose.signatures.count)")
            
            // 署名の公開鍵で比較するためのセット
            let localPublicKeys = Set(propose.signatures.map { $0.publicKey })
            let serverPublicKeys = Set(hashedPropose.signatures.map { $0.publicKey })
            
            // サーバーにのみある署名を抽出（ローカルにない新しい署名）
            let newServerSignatures = hashedPropose.signatures.compactMap { signInput -> Signature? in
                guard !localPublicKeys.contains(signInput.publicKey) else { return nil }
                return Signature(
                    id: UUID(),
                    publicKey: signInput.publicKey,
                    signature: signInput.signature,
                    createdAt: signInput.createdAt
                )
            }
            
            // ローカルにのみある署名を抽出（サーバーにまだ送られていない署名）
            let localOnlySigs = propose.signatures.filter { signature in
                !serverPublicKeys.contains(signature.publicKey)
            }
            
            await MainActor.run {
                serverStatus = .exists
                isCheckingServer = false
                
                // サーバーから取得した新しい署名
                self.serverSignatures = newServerSignatures
                self.hasNewSignatures = !newServerSignatures.isEmpty
                
                // ローカルのみの署名
                self.localOnlySignatures = localOnlySigs
                self.hasLocalOnlySignatures = !localOnlySigs.isEmpty
                
                if !newServerSignatures.isEmpty {
                    print("🔄 Found \(newServerSignatures.count) new signature(s) on server")
                }
                
                if !localOnlySigs.isEmpty {
                    print("📤 Found \(localOnlySigs.count) local-only signature(s)")
                }
            }
            
        } catch let error as ProposeAPIClient.APIError {
            // HTTPエラーをチェック
            if case .httpError(let statusCode) = error {
                if statusCode == 404 {
                    // 404 = サーバーに存在しない
                    print("ℹ️ Propose not found on server: \(propose.id)")
                    await MainActor.run {
                        serverStatus = .notFound
                        isCheckingServer = false
                    }
                    return
                }
            }
            
            // その他のエラー
            print("⚠️ Error checking propose on server: \(error)")
            await MainActor.run {
                serverStatus = .error(error.localizedDescription)
                isCheckingServer = false
            }
            
        } catch {
            // 予期しないエラー
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
        
        do {
            let identities = try KeychainRepository.shared.getAllIdentities()
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
        return propose.signatures.contains { signature in
            signature.publicKey == myPublicKey
        }
    }
    
    private func signPropose(with identity: Identity) async {
        await MainActor.run {
            isSigning = true
            signSuccess = nil
            signErrorMessage = nil
        }
        
        do {
            // ペイロードハッシュに署名
            let signatureData = try KeychainRepository.shared.signMessage(
                propose.payloadHash,
                withIdentityId: identity.id
            )
            
            // 新しいSignatureを作成
            let newSignature = Signature(
                id: UUID(),
                publicKey: identity.publicKey,
                signature: signatureData,
                createdAt: Date()
            )
            
            // Proposeに署名を追加
            var updatedSignatures = propose.signatures
            updatedSignatures.append(newSignature)
            
            let updatedPropose = Propose(
                id: propose.id,
                message: propose.message,
                signatures: updatedSignatures,
                createdAt: propose.createdAt,
                updatedAt: propose.updatedAt
            )
            
            // ローカルに保存
            await MainActor.run {
                let repository = ProposeRepository(modelContext: modelContext)
                do {
                    try repository.update(updatedPropose)
                    print("✅ Signature added locally: \(propose.id)")
                } catch {
                    print("❌ Failed to update propose locally: \(error)")
                    signSuccess = false
                    signErrorMessage = "Failed to save locally"
                    isSigning = false
                    return
                }
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
        
        do {
            // サーバーから取得した署名をローカルのProposeに追加
            var updatedSignatures = propose.signatures
            updatedSignatures.append(contentsOf: serverSignatures)
            
            let updatedPropose = Propose(
                id: propose.id,
                message: propose.message,
                signatures: updatedSignatures,
                createdAt: propose.createdAt,
                updatedAt: Date()
            )
            
            // ローカルに保存
            await MainActor.run {
                let repository = ProposeRepository(modelContext: modelContext)
                do {
                    try repository.update(updatedPropose)
                    print("✅ Synced \(serverSignatures.count) new signature(s) from server: \(propose.id)")
                    
                    // 同期完了後、状態をリセット
                    hasNewSignatures = false
                    serverSignatures = []
                    isSyncingSignatures = false
                } catch {
                    print("❌ Failed to sync signatures locally: \(error)")
                    isSyncingSignatures = false
                }
            }
        }
    }
    
    private func sendLocalSignaturesToServer() async {
        await MainActor.run {
            isSendingSignatures = true
        }
        
        do {
            // URLを確認
            guard let baseURL = URL(string: space.url) else {
                await MainActor.run {
                    isSendingSignatures = false
                }
                print("❌ Invalid server URL")
                return
            }
            
            // 最初のSignatureを取得（Proposeを作成した人の署名）
            guard let firstSignature = propose.signatures.first else {
                await MainActor.run {
                    isSendingSignatures = false
                }
                print("❌ No signature found")
                return
            }
            
            // 全ての署名（既存 + ローカルのみ）をSignInputに変換
            let allSignInputs = propose.signatures.map { signature in
                ProposeAPIClient.SignInput(
                    publicKey: signature.publicKey,
                    signature: signature.signature
                )
            }
            
            // ProposeInputを作成（全ての署名を送信）
            let input = ProposeAPIClient.ProposeInput(
                id: propose.id,
                payloadHash: propose.payloadHash,
                publicKey: firstSignature.publicKey,
                signatures: allSignInputs
            )
            
            // APIクライアントでcreateProposeを使用（サーバー側で既存の場合は更新される想定）
            let client = ProposeAPIClient(baseURL: baseURL)
            try await client.updatePropose(proposeID: input.id, input: input)

            print("✅ Sent \(localOnlySignatures.count) local signature(s) to server (total: \(allSignInputs.count)): \(propose.id)")
            
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

// MARK: - Signature Row View

struct SignatureRowView: View {
    let signature: Signature
    let myPublicKey: String?

    private var isMySignature: Bool {
        guard let myPublicKey = myPublicKey else { return false }
        return signature.publicKey == myPublicKey
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Image(systemName: isMySignature ? "person.fill.checkmark" : "checkmark.seal.fill")
                    .font(.caption2)
                    .foregroundStyle(isMySignature ? .blue : .green)
                
                Text(signature.publicKey.prefix(16) + "...")
                    .font(.caption2)
                    .fontDesign(.monospaced)
                    .foregroundStyle(isMySignature ? .blue : .secondary)
                    .fontWeight(isMySignature ? .semibold : .regular)
                
                if isMySignature {
                    Text("(You)")
                        .font(.caption2)
                        .foregroundStyle(.blue)
                        .italic()
                }
                
                Spacer()
                
                Text(signature.createdAt, format: .dateTime.month().day().hour().minute())
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.leading, 8)
        .padding(.vertical, 2)
        .background(isMySignature ? Color.blue.opacity(0.05) : Color.clear)
        .cornerRadius(4)
    }
}

// MARK: - Share Sheet

#if os(iOS)
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        print("📤 ShareSheet: Creating UIActivityViewController with items: \(items)")
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
#elseif os(macOS)
struct ShareSheet: NSViewRepresentable {
    let items: [Any]
    
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        print("📤 ShareSheet: Creating NSView with items: \(items)")
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        guard let window = nsView.window else { 
            print("⚠️ ShareSheet: No window available")
            return 
        }
        
        print("📤 ShareSheet: Showing NSSharingServicePicker")
        let picker = NSSharingServicePicker(items: items)
        picker.show(relativeTo: .zero, of: nsView, preferredEdge: .minY)
    }
}
#endif

// MARK: - Propose Detail View From Entity

struct ProposeDetailViewFromEntity: View {
    let propose: Propose
    let space: Space
    let modelContext: ModelContext
    
    @State private var proposeSwiftData: ProposeSwiftData?
    @State private var isLoading = true
    
    var body: some View {
        Group {
            if isLoading {
                ProgressView("Loading...")
            } else if let proposeSwiftData = proposeSwiftData {
                ProposeDetailView(propose: proposeSwiftData)
            } else {
                VStack {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    Text("Propose not found")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .task {
            await loadProposeSwiftData()
        }
    }
    
    private func loadProposeSwiftData() async {
        let proposeID = propose.id
        let predicate = #Predicate<ProposeSwiftData> { model in
            model.id == proposeID
        }
        
        var descriptor = FetchDescriptor<ProposeSwiftData>(predicate: predicate)
        descriptor.fetchLimit = 1
        
        do {
            let models = try modelContext.fetch(descriptor)
            await MainActor.run {
                proposeSwiftData = models.first
                isLoading = false
            }
        } catch {
            print("❌ Error loading ProposeSwiftData: \(error)")
            await MainActor.run {
                isLoading = false
            }
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        SpaceDetailView(space: Space(
            id: UUID(),
            name: "Example Space",
            url: "https://api.example.com",
            defaultIdentityID: UUID(),
            orderIndex: 0,
            createdAt: .now,
            updatedAt: .now
        ))
    }
}
