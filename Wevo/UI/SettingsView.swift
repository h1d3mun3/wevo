//
//  SettingsView.swift
//  Wevo
//
//  Created by hidemune on 3/7/26.
//

import SwiftUI
import SwiftData

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
                                Text("\(propose.signatures.count) signature(s)")
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
        do {
            let repository = ProposeRepository(modelContext: modelContext)
            try repository.delete(by: propose.id)
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
        do {
            let repository = SpaceRepository(modelContext: modelContext)
            try repository.delete(by: space.id)
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
    
    var body: some View {
        List {
            Section("Message") {
                Text(propose.message)
                    .font(.body)
            }
            
            Section("Hash") {
                LabeledContent("Payload Hash") {
                    Text(propose.payloadHash)
                        .font(.caption)
                        .fontDesign(.monospaced)
                        .textSelection(.enabled)
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
            
            Section("Signatures (\(propose.signatures.count))") {
                if propose.signatures.isEmpty {
                    Text("No signatures")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(propose.signatures, id: \.id) { signature in
                        NavigationLink {
                            SignatureDetailView(signature: signature)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(signature.publicKey.prefix(32) + "...")
                                    .font(.caption)
                                    .fontDesign(.monospaced)
                                
                                Text(signature.createdAt, format: .dateTime.month().day().hour().minute())
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Propose Details")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
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
