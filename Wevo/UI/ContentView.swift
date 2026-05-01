//
//  ContentView.swift
//  Wevo
//
//  Created by hidemune on 3/5/26.
//

import SwiftUI
import os

struct ContentView: View {
    @State private var shouldShowIdentityList = false
    @State private var shouldShowContactList = false
    @State private var shouldShowAddSpace = false
    @State private var shouldShowSettings = false
    @State private var spaces: [Space] = []
    @State private var orphanedProposeGroups: [OrphanedProposeGroup] = []
    @State private var deleteSpaceError: String?
    @Environment(\.dependencies) private var deps

    var body: some View {
        NavigationSplitView {
            List {
                // Spaces Section
                if spaces.isEmpty {
                    Text("No spaces available")
                        .foregroundStyle(.secondary)
                } else {
                    Section("Spaces") {
                        ForEach(spaces) { space in
                            NavigationLink {
                                SpaceDetailView(space: space)
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(space.name)
                                        .font(.headline)
                                    Text(space.url)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .onDelete(perform: deleteSpace)
                    }
                }

                // Orphaned Proposes Section
                if !orphanedProposeGroups.isEmpty {
                    Section("Orphaned Proposes") {
                        ForEach(orphanedProposeGroups, id: \.spaceID) { group in
                            NavigationLink {
                                OrphanedProposeGroupView(spaceID: group.spaceID, proposes: group.proposes)
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Unknown Space")
                                        .font(.headline)
                                    Text("\(group.proposes.count) propose(s)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }
#if os(macOS)
            .navigationSplitViewColumnWidth(350)
#endif
            .toolbar {
                ToolbarItem(placement: .navigation) {
                    Button(action: { shouldShowSettings = true }) {
                        Label("Settings", systemImage: "gearshape.fill")
                    }
                }
                
                ToolbarItem {
                    Button(action: { shouldShowContactList = true }) {
                        Label("Contacts", systemImage: "person.2.fill")
                    }
                }

                ToolbarItem {
                    Button(action: { shouldShowIdentityList = true }) {
                        Label("Manage Keys", systemImage: "key.fill")
                    }
                }

                ToolbarItem {
                    Button(action: { shouldShowAddSpace = true }) {
                        Label("Add Space", systemImage: "globe")
                    }
                }
            }
            .task {
                await loadSpaces()
            }
            .onCloudKitImport {
                Task { await loadSpaces() }
            }
        } detail: {
            Text("Select an item")
        }
        .sheet(isPresented: $shouldShowSettings) {
            SettingsView()
        }
        .sheet(isPresented: $shouldShowIdentityList) {
            IdentityListView()
        }
        .sheet(isPresented: $shouldShowContactList) {
            ContactListView()
        }
        .sheet(isPresented: $shouldShowAddSpace, onDismiss: {
            Task {
                await loadSpaces()
            }
        }) {
            AddSpaceView()
        }
        .alert("Error", isPresented: .init(
            get: { deleteSpaceError != nil },
            set: { if !$0 { deleteSpaceError = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(deleteSpaceError ?? "")
        }
    }

    private func loadSpaces() async {
        let getAllSpacesUseCase = GetAllSpacesUseCaseImpl(spaceRepository: deps.spaceRepository)
        let getOrphanedProposesUseCase = GetOrphanedProposesUseCaseImpl(proposeRepository: deps.proposeRepository)

        do {
            let loadedSpaces = try getAllSpacesUseCase.execute()
            let spaceIDs = Set(loadedSpaces.map { $0.id })
            let groups = try getOrphanedProposesUseCase.execute(validSpaceIDs: spaceIDs)

            await MainActor.run {
                spaces = loadedSpaces
                orphanedProposeGroups = groups
            }
        } catch {
            Logger.space.error("Error loading spaces: \(error, privacy: .public)")
            await MainActor.run {
                spaces = []
                orphanedProposeGroups = []
            }
        }
    }
    
    private func deleteSpace(offsets: IndexSet) {
        let deleteSpaceUseCase = DeleteSpaceUseCaseImpl(spaceRepository: deps.spaceRepository)
        Task {
            do {
                for index in offsets {
                    let space = spaces[index]
                    try deleteSpaceUseCase.execute(id: space.id)
                }
                await loadSpaces()
            } catch {
                Logger.space.error("Error deleting space: \(error, privacy: .public)")
                await MainActor.run {
                    deleteSpaceError = error.localizedDescription
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
