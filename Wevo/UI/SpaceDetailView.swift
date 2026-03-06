//
//  SpaceDetailView.swift
//  Wevo
//
//  Created by hidemune on 3/6/26.
//

import SwiftUI

struct SpaceDetailView: View {
    let space: Space
    
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
                        Task {
                            await loadProposes()
                        }
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
                        ProposeRowView(propose: propose)
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
            await loadProposes()
        }
        .refreshable {
            await loadProposes()
        }
        .sheet(isPresented: $shouldShowCreatePropose) {
            if let identity = defaultIdentity {
                CreateProposeView(space: space, identity: identity) {
                    Task {
                        await loadProposes()
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
    
    private func loadProposes() async {
        guard let defaultIdentity = defaultIdentity else {
            await MainActor.run {
                self.isLoading = false
                self.errorMessage = "No default key is set for this space"
                self.proposes = []
            }
            return
        }
        
        // String URLをURLに変換
        guard let baseURL = URL(string: space.url) else {
            await MainActor.run {
                self.isLoading = false
                self.errorMessage = "Invalid server URL: \(space.url)"
                self.proposes = []
            }
            return
        }
        
        await MainActor.run {
            self.isLoading = true
            self.errorMessage = nil
        }
        
        do {
            // 公開鍵をBase64エンコードした文字列に変換
            let publicKeyString = defaultIdentity.publicKey.base64EncodedString()
            
            let client = ProposeAPIClient(baseURL: baseURL)
            let page = try await client.listProposes(publicKey: publicKeyString, page: 1, per: 100)
            
            await MainActor.run {
                self.proposes = page.items
                self.isLoading = false
                
                if page.items.isEmpty {
                    print("ℹ️ No proposes found for public key: \(publicKeyString)")
                } else {
                    print("✅ Loaded \(page.items.count) proposes (total: \(page.metadata.total))")
                }
            }
        } catch {
            print("❌ Error loading proposes: \(error)")
            await MainActor.run {
                self.isLoading = false
                self.errorMessage = "Failed to load proposes: \(error.localizedDescription)"
                self.proposes = []
            }
        }
    }
}

// MARK: - Propose Row View

struct ProposeRowView: View {
    let propose: Propose
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "doc.text.fill")
                    .foregroundStyle(.blue)
                Text("Propose")
                    .font(.headline)
                Spacer()
                if let createdAt = propose.createdAt {
                    Text(createdAt, format: .dateTime.month().day().hour().minute())
                        .font(.caption)
                        .foregroundStyle(.secondary)
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
                Text("Payload Hash:")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(propose.payloadHash)
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
