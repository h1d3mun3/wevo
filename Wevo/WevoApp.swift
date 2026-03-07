//
//  WevoApp.swift
//  Wevo
//
//  Created by hidemune on 3/5/26.
//

import SwiftUI
import SwiftData

@main
struct WevoApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            SpaceSwiftData.self,
            ProposeSwiftData.self,
            SignatureSwiftData.self
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false, cloudKitDatabase: .none)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()
    
    @State private var importedProposeURL: URL?
    @State private var showImportAlert = false
    @State private var showSpaceSelector = false
    @State private var importedProposeData: (propose: Propose, spaceID: UUID)?
    @State private var availableSpaces: [Space] = []

    var body: some Scene {
        WindowGroup {
            ContentView()
                .sheet(isPresented: $showSpaceSelector) {
                    if let proposeData = importedProposeData {
                        SpaceSelectorView(
                            propose: proposeData.propose,
                            originalSpaceID: proposeData.spaceID,
                            spaces: availableSpaces,
                            onSelect: { selectedSpace in
                                importPropose(proposeData.propose, to: selectedSpace)
                                showSpaceSelector = false
                                cleanup()
                            },
                            onCancel: {
                                showSpaceSelector = false
                                cleanup()
                            }
                        )
                    }
                }
                .alert("Propose Received", isPresented: $showImportAlert) {
                    Button("Choose Space") {
                        if let url = importedProposeURL {
                            prepareImport(from: url)
                        }
                    }
                    Button("Cancel", role: .cancel) {
                        cleanup()
                    }
                } message: {
                    Text("A Propose file has been received via AirDrop. Choose which Space to import it to.")
                }
                .onOpenURL { url in
                    handleIncomingURL(url)
                }
        }
        .modelContainer(sharedModelContainer)
    }
    
    private func handleIncomingURL(_ url: URL) {
        print("📥 Received URL: \(url)")
        
        // .wevo-propose ファイルかチェック
        if url.pathExtension == "wevo-propose" {
            importedProposeURL = url
            showImportAlert = true
        } else {
            print("⚠️ Unknown file type: \(url.pathExtension)")
        }
    }
    
    private func prepareImport(from url: URL) {
        do {
            let exportData = try ProposeExporter.importPropose(from: url)
            
            let modelContext = sharedModelContainer.mainContext
            let spaceRepository = SpaceRepository(modelContext: modelContext)
            let spaces = try spaceRepository.fetchAll()
            
            guard !spaces.isEmpty else {
                print("❌ No spaces found. Cannot import propose.")
                cleanup()
                return
            }
            
            importedProposeData = (propose: exportData.propose, spaceID: exportData.spaceID)
            availableSpaces = spaces
            showSpaceSelector = true
            
        } catch {
            print("❌ Error preparing import: \(error)")
            cleanup()
        }
    }
    
    private func importPropose(_ propose: Propose, to space: Space) {
        let modelContext = sharedModelContainer.mainContext
        let proposeRepository = ProposeRepository(modelContext: modelContext)
        
        do {
            try proposeRepository.create(propose, spaceID: space.id)
            print("✅ Propose imported successfully to space: \(space.name)")
        } catch {
            print("❌ Error importing propose: \(error)")
        }
    }
    
    private func cleanup() {
        if let url = importedProposeURL {
            try? FileManager.default.removeItem(at: url)
        }
        importedProposeURL = nil
        importedProposeData = nil
        availableSpaces = []
    }
}
// MARK: - Space Selector View

struct SpaceSelectorView: View {
    let propose: Propose
    let originalSpaceID: UUID
    let spaces: [Space]
    let onSelect: (Space) -> Void
    let onCancel: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Propose to Import")
                            .font(.headline)
                        
                        Text(propose.message)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(3)
                        
                        HStack {
                            Image(systemName: "signature")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                            Text("\(propose.signatures.count) signature(s)")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                            
                            Spacer()
                            
                            Text(propose.createdAt, format: .dateTime.month().day().hour().minute())
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .padding(.vertical, 4)
                }
                
                Section("Select Space") {
                    ForEach(spaces) { space in
                        Button {
                            onSelect(space)
                            dismiss()
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(space.name)
                                        .font(.body)
                                        .foregroundStyle(.primary)
                                    
                                    Text(space.url)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                
                                Spacer()
                                
                                if space.id == originalSpaceID {
                                    Image(systemName: "arrow.down.circle.fill")
                                        .foregroundStyle(.blue)
                                        .font(.title3)
                                    Text("Original")
                                        .font(.caption)
                                        .foregroundStyle(.blue)
                                        .fontWeight(.medium)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .navigationTitle("Import Propose")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onCancel()
                        dismiss()
                    }
                }
            }
        }
    }
}

