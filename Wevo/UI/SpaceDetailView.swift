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
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(alignment: .leading, spacing: 8) {
                Text(space.name)
                    .font(.title)
                    .fontWeight(.bold)
                
                Text(space.url)
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
        .navigationTitle(space.name)
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
                CreateProposeView(space: space, identity: identity) {
                    Task {
                        loadProposesFromLocal()
                    }
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
            let loadedProposes = try repository.fetchAll(for: space.id)
            
            proposes = loadedProposes
            isLoading = false
            
            if loadedProposes.isEmpty {
                print("ℹ️ No proposes found locally for space: \(space.name)")
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
}

// MARK: - Propose Row View

struct ProposeRowView: View {
    let propose: Propose
    let space: Space
    
    @State private var shareURL: URL?
    @State private var showShareSheet = false
    @State private var shareError: String?
    
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
