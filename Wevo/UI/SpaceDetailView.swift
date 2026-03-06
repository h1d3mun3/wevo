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
                        ProposeRowView(propose: propose, space: space)
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
    
    @State private var shareURL: URL?
    @State private var showShareSheet = false
    @State private var shareError: String?
    @State private var isResending = false
    @State private var resendSuccess: Bool?
    @State private var resendErrorMessage: String?
    @State private var serverStatus: ServerStatus = .unknown
    @State private var isCheckingServer = false
    
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
            // メッセージ
            HStack {
                Text(propose.message)
                    .font(.headline)
                    .lineLimit(2)
                Spacer()
                if let createdAt = propose.createdAt {
                    Text(createdAt, format: .dateTime.month().day().hour().minute())
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
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
                Button {
                    sharePropose()
                } label: {
                    Label("Share", systemImage: "square.and.arrow.up")
                        .labelStyle(.iconOnly)
                        .font(.caption)
                }
                .buttonStyle(.borderless)
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
            
            if !propose.signatures.isEmpty {
                Divider()
                    .padding(.vertical, 4)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Signatures:")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    
                    ForEach(propose.signatures) { signature in
                        SignatureRowView(signature: signature)
                    }
                }
            }
        }
        .padding(.vertical, 8)
        .sheet(isPresented: $showShareSheet) {
            if let shareURL = shareURL {
                ShareSheet(items: [shareURL])
            }
        }
        .task {
            await checkServerStatus()
        }
    }
    
    private func sharePropose() {
        do {
            let url = try ProposeExporter.exportPropose(propose, space: space)
            shareURL = url
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
                signature: firstSignature.signatureData
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
            let _ = try await client.getPropose(proposeID: propose.id)
            
            // 成功 = サーバーに存在する
            print("✅ Propose exists on server: \(propose.id)")
            await MainActor.run {
                serverStatus = .exists
                isCheckingServer = false
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
}

// MARK: - Signature Row View

struct SignatureRowView: View {
    let signature: Signature
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Image(systemName: "checkmark.seal.fill")
                    .font(.caption2)
                    .foregroundStyle(.green)
                Text(signature.publicKey.prefix(16) + "...")
                    .font(.caption2)
                    .fontDesign(.monospaced)
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                if let createdAt = signature.createdAt {
                    Text(createdAt, format: .dateTime.month().day().hour().minute())
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(.leading, 8)
    }
}

// MARK: - Share Sheet

#if os(iOS)
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
#elseif os(macOS)
struct ShareSheet: NSViewRepresentable {
    let items: [Any]
    
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        guard let window = nsView.window else { return }
        
        let picker = NSSharingServicePicker(items: items)
        picker.show(relativeTo: .zero, of: nsView, preferredEdge: .minY)
    }
}
#endif

// MARK: - Preview

#Preview {
    NavigationStack {
        SpaceDetailView(space: Space(
            id: UUID(),
            name: "Example Space",
            url: "https://api.example.com",
            defaultIdentityID: UUID(),
            orderIndex: 0
        ))
    }
}
