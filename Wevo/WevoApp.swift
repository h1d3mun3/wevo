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
            SignatureSwiftData.self,
            ContactSwiftData.self
        ])
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            cloudKitDatabase: .automatic
        )

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
    
    @State private var importedIdentityURL: URL?
    @State private var showIdentityImportAlert = false
    @State private var pendingIdentityPlain: IdentityPlainExport?
    @State private var showIdentityImportSheet = false

    @State private var importedContactURL: URL?
    @State private var showContactImportAlert = false
    @State private var pendingContactExport: ContactExportData?
    @State private var showContactImportSheet = false

    @MainActor
    private var container: AppDependencyContainer {
        AppDependencyContainer(modelContext: sharedModelContainer.mainContext)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
#if os(macOS)
                .frame(minWidth: 400, minHeight: 500)
#endif
                .task {
                    cleanupTemporaryFiles()
                }
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
                .sheet(isPresented: $showIdentityImportSheet) {
                    if let export = pendingIdentityPlain {
                        IdentityImportView(exportData: export) {
                            // onComplete
                            cleanupIdentityImport()
                        } onCancel: {
                            cleanupIdentityImport()
                        }
                    }
                }
                .sheet(isPresented: $showContactImportSheet) {
                    if let export = pendingContactExport {
                        ContactImportView(exportData: export) {
                            cleanupContactImport()
                        } onCancel: {
                            cleanupContactImport()
                        }
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
                .alert("Identity Received", isPresented: $showIdentityImportAlert) {
                    Button("Preview") {
                        if let url = importedIdentityURL {
                            prepareIdentityImport(from: url)
                        }
                    }
                    Button("Cancel", role: .cancel) {
                        cleanupIdentityImport()
                    }
                } message: {
                    Text("An Identity file has been received via AirDrop. Preview and import it?")
                }
                .alert("Contact Received", isPresented: $showContactImportAlert) {
                    Button("Preview") {
                        if let url = importedContactURL {
                            prepareContactImport(from: url)
                        }
                    }
                    Button("Cancel", role: .cancel) {
                        cleanupContactImport()
                    }
                } message: {
                    Text("A Contact file has been received via AirDrop. Preview and import it?")
                }
                .onOpenURL { url in
                    handleIncomingURL(url)
                }
        }
        .environment(\.dependencies, container)
        .modelContainer(sharedModelContainer)
    }
    
    private func handleIncomingURL(_ url: URL) {
        print("📥 Received URL: \(url)")
        let ext = url.pathExtension
        if ext == "wevo-propose" {
            importedProposeURL = url
            showImportAlert = true
        } else if ext == "wevo-identity" {
            importedIdentityURL = url
            showIdentityImportAlert = true
        } else if ext == "wevo-contact" {
            importedContactURL = url
            showContactImportAlert = true
        } else {
            print("⚠️ Unknown file type: \(ext)")
        }
    }
    
    private func prepareImport(from url: URL) {
        do {
            let exportData = try ProposeExporter.importPropose(from: url)

            let spaces = try container.spaceRepository.fetchAll()
            
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
    
    private func prepareIdentityImport(from url: URL) {
        do {
            let plain = try IdentityPlainTransfer.importPlainFromFile(url: url)
            pendingIdentityPlain = plain
            showIdentityImportSheet = true
        } catch {
            print("❌ Error preparing identity import: \(error)")
            cleanupIdentityImport()
        }
    }

    private func cleanupIdentityImport() {
        if let url = importedIdentityURL {
            try? FileManager.default.removeItem(at: url)
        }
        importedIdentityURL = nil
        pendingIdentityPlain = nil
        showIdentityImportSheet = false
        showIdentityImportAlert = false
    }

    private func prepareContactImport(from url: URL) {
        do {
            pendingContactExport = try ContactTransfer.importFromFile(url: url)
            showContactImportSheet = true
        } catch {
            print("❌ Error preparing contact import: \(error)")
            cleanupContactImport()
        }
    }

    private func cleanupContactImport() {
        if let url = importedContactURL {
            try? FileManager.default.removeItem(at: url)
        }
        importedContactURL = nil
        pendingContactExport = nil
        showContactImportSheet = false
        showContactImportAlert = false
    }
    
    private func importPropose(_ propose: Propose, to space: Space) {
        do {
            try container.proposeRepository.create(propose, spaceID: space.id)
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

    /// Deletes private key and Propose export files in the temporary directory on app launch
    private func cleanupTemporaryFiles() {
        let tempDir = FileManager.default.temporaryDirectory
        let sensitiveExtensions = ["wevo-identity", "wevo-propose", "wevo-contact"]

        guard let files = try? FileManager.default.contentsOfDirectory(
            at: tempDir,
            includingPropertiesForKeys: nil
        ) else { return }

        for file in files {
            if sensitiveExtensions.contains(file.pathExtension) {
                try? FileManager.default.removeItem(at: file)
                print("🧹 Cleaned up temporary file: \(file.lastPathComponent)")
            }
        }
    }
}
