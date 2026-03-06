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

    var body: some Scene {
        WindowGroup {
            ContentView()
                .alert("Propose Received", isPresented: $showImportAlert) {
                    Button("Import") {
                        if let url = importedProposeURL {
                            importPropose(from: url)
                        }
                    }
                    Button("Cancel", role: .cancel) {
                        importedProposeURL = nil
                    }
                } message: {
                    Text("A Propose file has been received via AirDrop. Would you like to import it?")
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
    
    private func importPropose(from url: URL) {
        do {
            let exportData = try ProposeExporter.importPropose(from: url)
            
            let modelContext = sharedModelContainer.mainContext
            let spaceRepository = SpaceRepository(modelContext: modelContext)
            let spaces = try spaceRepository.fetchAll()
            
            // 対応するSpaceを探す
            if let matchingSpace = spaces.first(where: { $0.id == exportData.spaceID }) {
                let proposeRepository = ProposeRepository(modelContext: modelContext)
                try proposeRepository.create(exportData.propose, spaceID: matchingSpace.id)
                
                print("✅ Propose imported successfully to space: \(matchingSpace.name)")
            } else if let firstSpace = spaces.first {
                // Space IDが一致しない場合、最初のSpaceに保存
                let proposeRepository = ProposeRepository(modelContext: modelContext)
                try proposeRepository.create(exportData.propose, spaceID: firstSpace.id)
                
                print("⚠️ Original space not found. Saved to: \(firstSpace.name)")
            } else {
                print("❌ No spaces found. Cannot import propose.")
            }
            
            // ファイルをクリーンアップ
            try? FileManager.default.removeItem(at: url)
            
        } catch {
            print("❌ Error importing propose: \(error)")
        }
        
        importedProposeURL = nil
    }
}
