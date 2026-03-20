//
//  WevoApp.swift
//  Wevo
//
//  Created by hidemune on 3/5/26.
//

import SwiftUI
import SwiftData
import os

@main
struct WevoApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            SpaceSwiftData.self,
            ProposeSwiftData.self,
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
                    migrateDataIfNeeded()
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
        Logger.app.debug("Received URL: \(url, privacy: .private)")
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
            Logger.app.warning("Unknown file type: \(ext, privacy: .public)")
        }
    }
    
    private func prepareImport(from url: URL) {
        do {
            let exportData = try ProposeExporter.importPropose(from: url)

            let spaces = try container.spaceRepository.fetchAll()
            
            guard !spaces.isEmpty else {
                Logger.app.error("No spaces found. Cannot import propose.")
                cleanup()
                return
            }
            
            importedProposeData = (propose: exportData.propose, spaceID: exportData.spaceID)
            availableSpaces = spaces
            showSpaceSelector = true
            
        } catch {
            Logger.app.error("Error preparing import: \(error, privacy: .public)")
            cleanup()
        }
    }

    private func prepareIdentityImport(from url: URL) {
        do {
            let plain = try IdentityPlainTransfer.importPlainFromFile(url: url)
            pendingIdentityPlain = plain
            showIdentityImportSheet = true
        } catch {
            Logger.app.error("Error preparing identity import: \(error, privacy: .public)")
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
            Logger.app.error("Error preparing contact import: \(error, privacy: .public)")
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
            let useCase = ImportProposeUseCaseImpl(proposeRepository: container.proposeRepository, keychainRepository: container.keychainRepository)
            try useCase.execute(propose: propose, spaceID: space.id)
            Logger.app.info("Propose imported successfully to space: \(space.name, privacy: .private)")
        } catch {
            Logger.app.error("Error importing propose: \(error, privacy: .public)")
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

    // Bump this value whenever a schema change requires existing Propose data to be cleared.
    private static let currentDataVersion = 2
    private static let dataVersionKey = "wevo_data_version"

    /// Clears all Propose records when the data version has changed.
    /// Spaces, Identities, and Contacts are preserved.
    @MainActor
    private func migrateDataIfNeeded() {
        let stored = UserDefaults.standard.integer(forKey: Self.dataVersionKey)
        guard stored < Self.currentDataVersion else { return }

        let context = sharedModelContainer.mainContext
        do {
            try context.delete(model: ProposeSwiftData.self)
            try context.save()
            Logger.app.info("Data migration to v\(Self.currentDataVersion): all Proposes cleared")
        } catch {
            Logger.app.error("Data migration failed: \(error, privacy: .public)")
        }
        UserDefaults.standard.set(Self.currentDataVersion, forKey: Self.dataVersionKey)
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
                Logger.app.debug("Cleaned up temporary file: \(file.lastPathComponent, privacy: .private)")
            }
        }
    }
}
