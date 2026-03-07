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
    @State private var selectedTab = 0
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // タブ選択
                Picker("Data Type", selection: $selectedTab) {
                    Text("Proposes").tag(0)
                    Text("Spaces").tag(1)
                }
                .pickerStyle(.segmented)
                .padding()
                
                Divider()
                
                // コンテンツ
                if selectedTab == 0 {
                    ProposeListView(proposes: proposes)
                } else {
                    SpaceListView(spaces: spaces)
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
    }
}

// MARK: - Propose List View

struct ProposeListView: View {
    let proposes: [ProposeSwiftData]
    
    var body: some View {
        List {
            if proposes.isEmpty {
                Text("No proposes in database")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
            } else {
                ForEach(proposes, id: \.id) { propose in
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
                        
                        HStack {
                            Text("Hash:")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(propose.payloadHash.prefix(16) + "...")
                                .font(.caption)
                                .fontDesign(.monospaced)
                                .foregroundStyle(.secondary)
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
                            Text("Space ID:")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(propose.spaceID.uuidString)
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

                            Text("Updated: \(propose.updatedAt, format: .dateTime.month().day().hour().minute())")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                        
                        // Signatures
                        if !propose.signatures.isEmpty {
                            Divider()
                                .padding(.vertical, 4)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Signatures:")
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                                
                                ForEach(propose.signatures, id: \.id) { signature in
                                    HStack {
                                        Image(systemName: "checkmark.seal.fill")
                                            .font(.caption2)
                                            .foregroundStyle(.green)
                                        
                                        Text(signature.publicKey.prefix(16) + "...")
                                            .font(.caption2)
                                            .fontDesign(.monospaced)
                                            .foregroundStyle(.secondary)
                                        
                                        Spacer()

                                        Text(signature.createdAt, format: .dateTime.month().day().hour().minute())
                                            .font(.caption2)
                                            .foregroundStyle(.tertiary)
                                    }
                                    .padding(.leading, 8)
                                }
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
        }
        .listStyle(.plain)
    }
}

// MARK: - Space List View

struct SpaceListView: View {
    let spaces: [SpaceSwiftData]
    
    var body: some View {
        List {
            if spaces.isEmpty {
                Text("No spaces in database")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
            } else {
                ForEach(spaces, id: \.id) { space in
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
                        
                        HStack {
                            Text("ID:")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(space.id.uuidString)
                                .font(.caption)
                                .fontDesign(.monospaced)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                        
                        if let defaultIdentityID = space.defaultIdentityID {
                            HStack {
                                Text("Default Identity ID:")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(defaultIdentityID.uuidString)
                                    .font(.caption)
                                    .fontDesign(.monospaced)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            }
                        }
                        
                        HStack {
                            Text("Created: \(space.createdAt, format: .dateTime.month().day().hour().minute())")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                            
                            Spacer()
                            
                            Text("Updated: \(space.updatedAt, format: .dateTime.month().day().hour().minute())")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
        }
        .listStyle(.plain)
    }
}

// MARK: - Preview

#Preview {
    SettingsView()
        .modelContainer(for: [ProposeSwiftData.self, SpaceSwiftData.self], inMemory: true)
}
