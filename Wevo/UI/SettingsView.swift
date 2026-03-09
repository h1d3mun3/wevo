//
//  SettingsView.swift
//  Wevo
//
//  Created by hidemune on 3/7/26.
//

import SwiftUI
import SwiftData
import CryptoKit

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var proposes: [ProposeSwiftData] = []
    @State private var spaces: [SpaceSwiftData] = []
    @State private var signatures: [SignatureSwiftData] = []
    @State private var selectedTab = 0
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // タブ選択
                Picker("Data Type", selection: $selectedTab) {
                    Text("Proposes").tag(0)
                    Text("Signatures").tag(1)
                    Text("Spaces").tag(2)
                }
                .pickerStyle(.segmented)
                .padding()
                
                Divider()
                
                // コンテンツ
                if selectedTab == 0 {
                    ProposeListView(proposes: proposes, onDelete: loadData)
                } else if selectedTab == 1 {
                    SignatureListView(signatures: signatures, onDelete: loadData)
                } else {
                    SpaceListView(spaces: spaces, onDelete: loadData)
                }
            }
            .navigationTitle("Settings")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        loadData()
                    } label: {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                }
            }
            .task {
                loadData()
            }
        }
    }
    
    private func loadData() {
        // Proposesを取得
        let proposeDescriptor = FetchDescriptor<ProposeSwiftData>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        
        do {
            proposes = try modelContext.fetch(proposeDescriptor)
        } catch {
            print("❌ Error loading proposes: \(error)")
            proposes = []
        }
        
        // Spacesを取得
        let spaceDescriptor = FetchDescriptor<SpaceSwiftData>(
            sortBy: [SortDescriptor(\.orderIndex)]
        )
        
        do {
            spaces = try modelContext.fetch(spaceDescriptor)
        } catch {
            print("❌ Error loading spaces: \(error)")
            spaces = []
        }
        
        // Signaturesを取得
        let signatureDescriptor = FetchDescriptor<SignatureSwiftData>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        
        do {
            signatures = try modelContext.fetch(signatureDescriptor)
        } catch {
            print("❌ Error loading signatures: \(error)")
            signatures = []
        }
    }
}

// MARK: - Propose List View

struct ProposeListView: View {
    let proposes: [ProposeSwiftData]
    @Environment(\.modelContext) private var modelContext
    
    @State private var proposeToDelete: ProposeSwiftData?
    @State private var showDeleteAlert = false
    
    var onDelete: () -> Void = {}
    
    var body: some View {
        List {
            if proposes.isEmpty {
                Text("No proposes in database")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
            } else {
                ForEach(proposes, id: \.id) { propose in
                    NavigationLink {
                        ProposeDetailView(propose: propose)
                    } label: {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(propose.message)
                                .font(.headline)
                                .lineLimit(2)
                            
                            HStack {
                                Text("Created:")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(propose.createdAt, format: .dateTime.month().day().hour().minute())
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            
                            HStack {
                                Image(systemName: "signature")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text("\((propose.signatures ?? []).count) signature(s)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                }
                .onDelete { indexSet in
                    for index in indexSet {
                        let propose = proposes[index]
                        deletePropose(propose)
                    }
                }
            }
        }
        .listStyle(.plain)
        .alert("Delete Propose", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                if let propose = proposeToDelete {
                    deletePropose(propose)
                }
            }
        } message: {
            if let propose = proposeToDelete {
                Text("Are you sure you want to delete this propose?\n\n\(propose.message)")
            }
        }
    }
    
    private func deletePropose(_ propose: ProposeSwiftData) {
        let deleteProposeUseCase = DeleteProposeUseCaseImpl(proposeRepository: ProposeRepositoryImpl(modelContext: modelContext))
        do {
            try deleteProposeUseCase.execute(id: propose.id)
            print("✅ Propose deleted: \(propose.id)")
            onDelete()
        } catch {
            print("❌ Error deleting propose: \(error)")
        }
    }
}

// MARK: - Space List View

struct SpaceListView: View {
    let spaces: [SpaceSwiftData]
    @Environment(\.modelContext) private var modelContext
    
    var onDelete: () -> Void = {}
    
    var body: some View {
        List {
            if spaces.isEmpty {
                Text("No spaces in database")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
            } else {
                ForEach(spaces) { space in
                    NavigationLink {
                        SpaceDetailSettingsView(space: space)
                    } label: {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(space.name)
                                    .font(.headline)
                                
                                Spacer()
                                
                                Text("Order: \(space.orderIndex)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            
                            HStack {
                                Text("URL:")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(space.urlString)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                }
                .onDelete { indexSet in
                    for index in indexSet {
                        let space = spaces[index]
                        deleteSpace(space)
                    }
                }
            }
        }
        .listStyle(.plain)
    }
    
    private func deleteSpace(_ space: SpaceSwiftData) {
        let deleteSpaceUseCase = DeleteSpaceUseCaseImpl(spaceRepository: SpaceRepositoryImpl(modelContext: modelContext))
        do {
            try deleteSpaceUseCase.execute(id: space.id)
            print("✅ Space deleted: \(space.id)")
            onDelete()
        } catch {
            print("❌ Error deleting space: \(error)")
        }
    }
}

// MARK: - Signature List View

struct SignatureListView: View {
    let signatures: [SignatureSwiftData]
    @Environment(\.modelContext) private var modelContext
    
    var onDelete: () -> Void = {}
    
    var body: some View {
        List {
            if signatures.isEmpty {
                Text("No signatures in database")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
            } else {
                ForEach(signatures, id: \.id) { signature in
                    NavigationLink {
                        SignatureDetailView(signature: signature)
                    } label: {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "checkmark.seal.fill")
                                    .foregroundStyle(.green)
                                
                                Text(signature.publicKey.prefix(16) + "...")
                                    .font(.body)
                                    .fontDesign(.monospaced)
                                
                                Spacer()
                            }
                            
                            HStack {
                                Text("Created:")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(signature.createdAt, format: .dateTime.month().day().hour().minute())
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                }
                .onDelete { indexSet in
                    for index in indexSet {
                        let signature = signatures[index]
                        deleteSignature(signature)
                    }
                }
            }
        }
        .listStyle(.plain)
    }
    
    private func deleteSignature(_ signature: SignatureSwiftData) {
        modelContext.delete(signature)
        
        do {
            try modelContext.save()
            print("✅ Signature deleted: \(signature.id)")
            onDelete()
        } catch {
            print("❌ Error deleting signature: \(error)")
        }
    }
}

// MARK: - Propose Detail View

struct ProposeDetailView: View {
    let propose: ProposeSwiftData
    
    @State private var selectedSignature: SignatureSwiftData?
    @State private var showSignatureDetail = false
    @State private var signatureVerifications: [UUID: Bool] = [:]
    @State private var isHashValid: Bool?
    
    var body: some View {
        List {
            Section("Message") {
                Text(propose.message)
                    .font(.body)
            }
            
            Section("Hash") {
                LabeledContent("Payload Hash") {
                    HStack {
                        Text(propose.payloadHash)
                            .font(.caption)
                            .fontDesign(.monospaced)
                            .textSelection(.enabled)
                        
                        Spacer()
                        
                        // ハッシュ検証結果
                        if let isValid = isHashValid {
                            Image(systemName: isValid ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundStyle(isValid ? .green : .red)
                                .font(.title3)
                        } else {
                            ProgressView()
                                .scaleEffect(0.8)
                        }
                    }
                }
                
                if let isValid = isHashValid, !isValid {
                    Text("⚠️ Hash mismatch: The payload hash does not match the message")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
            
            Section("IDs") {
                LabeledContent("Propose ID") {
                    Text(propose.id.uuidString)
                        .font(.caption)
                        .fontDesign(.monospaced)
                        .textSelection(.enabled)
                }
                
                LabeledContent("Space ID") {
                    Text(propose.spaceID.uuidString)
                        .font(.caption)
                        .fontDesign(.monospaced)
                        .textSelection(.enabled)
                }
            }
            
            Section("Timestamps") {
                LabeledContent("Created At") {
                    Text(propose.createdAt, format: .dateTime)
                }
                
                LabeledContent("Updated At") {
                    Text(propose.updatedAt, format: .dateTime)
                }
            }
            
            Section("Signatures (\((propose.signatures ?? []).count))") {
                if (propose.signatures ?? []).isEmpty {
                    Text("No signatures")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach((propose.signatures ?? []), id: \.id) { signature in
                        Button {
                            selectedSignature = signature
                            showSignatureDetail = true
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(signature.publicKey.prefix(32) + "...")
                                        .font(.caption)
                                        .fontDesign(.monospaced)
                                    
                                    Text(signature.createdAt, format: .dateTime.month().day().hour().minute())
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                                
                                Spacer()
                                
                                // 検証状態を表示
                                if let isValid = signatureVerifications[signature.id] {
                                    Image(systemName: isValid ? "checkmark.seal.fill" : "xmark.seal.fill")
                                        .foregroundStyle(isValid ? .green : .red)
                                        .font(.title3)
                                } else {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .task {
            await verifyHash()
            await verifyAllSignatures()
        }
        .navigationTitle("Propose Details")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .sheet(isPresented: $showSignatureDetail) {
            if let signature = selectedSignature {
                NavigationStack {
                    SignatureDetailView(signature: signature)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Close") {
                                    showSignatureDetail = false
                                }
                            }
                        }
                }
            }
        }
    }
    
    private func verifyHash() async {
        let messageHash = propose.message.sha256HashedString
        let isValid = messageHash == propose.payloadHash
        
        await MainActor.run {
            isHashValid = isValid
        }
        
        if isValid {
            print("✅ Hash valid: message hash matches payloadHash")
        } else {
            print("❌ Hash invalid: message hash (\(messageHash)) does not match payloadHash (\(propose.payloadHash))")
        }
    }
    
    private func verifyAllSignatures() async {
        for signature in (propose.signatures ?? []) {
            let isValid = await verifySignature(signature)
            await MainActor.run {
                signatureVerifications[signature.id] = isValid
            }
        }
    }
    
    private func verifySignature(_ signature: SignatureSwiftData) async -> Bool {
        do {
            // Base64デコードして公開鍵を取得
            guard let publicKeyData = Data(base64Encoded: signature.publicKey) else {
                print("❌ Failed to decode public key for signature: \(signature.id)")
                return false
            }
            
            // P256公開鍵を作成
            let publicKey = try CryptoKit.P256.Signing.PublicKey(x963Representation: publicKeyData)
            
            // 署名データをBase64デコード
            guard let signatureData = Data(base64Encoded: signature.signatureData) else {
                print("❌ Failed to decode signature data for signature: \(signature.id)")
                return false
            }
            
            // P256署名を作成（DER形式から）
            let sig = try CryptoKit.P256.Signing.ECDSASignature(derRepresentation: signatureData)
            
            // payloadHashをUTF-8データに変換
            let messageData = Data(propose.payloadHash.utf8)
            
            // 署名を検証
            let isValid = publicKey.isValidSignature(sig, for: messageData)
            
            print(isValid ? "✅ Signature valid: \(signature.id)" : "❌ Signature invalid: \(signature.id)")
            return isValid
            
        } catch {
            print("❌ Error verifying signature \(signature.id): \(error)")
            return false
        }
    }
}

// MARK: - Space Detail Settings View

struct SpaceDetailSettingsView: View {
    let space: SpaceSwiftData
    
    var body: some View {
        List {
            Section("Information") {
                LabeledContent("Name") {
                    Text(space.name)
                        .textSelection(.enabled)
                }
                
                LabeledContent("URL") {
                    Text(space.urlString)
                        .font(.caption)
                        .textSelection(.enabled)
                }
                
                LabeledContent("Order Index") {
                    Text("\(space.orderIndex)")
                }
            }
            
            Section("IDs") {
                LabeledContent("Space ID") {
                    Text(space.id.uuidString)
                        .font(.caption)
                        .fontDesign(.monospaced)
                        .textSelection(.enabled)
                }
                
                if let defaultIdentityID = space.defaultIdentityID {
                    LabeledContent("Default Identity ID") {
                        Text(defaultIdentityID.uuidString)
                            .font(.caption)
                            .fontDesign(.monospaced)
                            .textSelection(.enabled)
                    }
                } else {
                    LabeledContent("Default Identity") {
                        Text("None")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            
            Section("Timestamps") {
                LabeledContent("Created At") {
                    Text(space.createdAt, format: .dateTime)
                }
                
                LabeledContent("Updated At") {
                    Text(space.updatedAt, format: .dateTime)
                }
            }
        }
        .navigationTitle("Space Details")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}

// MARK: - Signature Detail View

struct SignatureDetailView: View {
    let signature: SignatureSwiftData
    
    var body: some View {
        List {
            Section("Public Key") {
                Text(signature.publicKey)
                    .font(.caption)
                    .fontDesign(.monospaced)
                    .textSelection(.enabled)
            }
            
            Section("Signature Data") {
                Text(signature.signatureData)
                    .font(.caption)
                    .fontDesign(.monospaced)
                    .textSelection(.enabled)
            }
            
            Section("IDs") {
                LabeledContent("Signature ID") {
                    Text(signature.id.uuidString)
                        .font(.caption)
                        .fontDesign(.monospaced)
                        .textSelection(.enabled)
                }
            }
            
            Section("Timestamp") {
                LabeledContent("Created At") {
                    Text(signature.createdAt, format: .dateTime)
                }
            }
        }
        .navigationTitle("Signature Details")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}

// MARK: - Preview

#Preview {
    SettingsView()
        .modelContainer(for: [ProposeSwiftData.self, SpaceSwiftData.self], inMemory: true)
}
