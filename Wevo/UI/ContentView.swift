//
//  ContentView.swift
//  Wevo
//
//  Created by hidemune on 3/5/26.
//

import SwiftUI
import os

// MARK: - Container

struct ContentView: View {
    @Environment(\.dependencies) private var deps

    var body: some View {
        ContentViewContent(viewModel: ContentViewModel(deps: deps))
    }
}

// MARK: - Content

private struct ContentViewContent: View {
    @State var viewModel: ContentViewModel

    var body: some View {
        NavigationSplitView {
            List {
                if viewModel.spaces.isEmpty {
                    Text("No spaces available")
                        .foregroundStyle(.secondary)
                } else {
                    Section("Spaces") {
                        ForEach(viewModel.spaces) { space in
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
                        .onDelete(perform: viewModel.deleteSpace)
                    }
                }

                if !viewModel.orphanedProposeGroups.isEmpty {
                    Section("Orphaned Proposes") {
                        ForEach(viewModel.orphanedProposeGroups, id: \.spaceID) { group in
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
                    Button(action: { viewModel.shouldShowSettings = true }) {
                        Label("Settings", systemImage: "gearshape.fill")
                    }
                }
                ToolbarItem {
                    Button(action: { viewModel.shouldShowContactList = true }) {
                        Label("Contacts", systemImage: "person.2.fill")
                    }
                }
                ToolbarItem {
                    Button(action: { viewModel.shouldShowIdentityList = true }) {
                        Label("Manage Keys", systemImage: "key.fill")
                    }
                }
                ToolbarItem {
                    Button(action: { viewModel.shouldShowAddSpace = true }) {
                        Label("Add Space", systemImage: "globe")
                    }
                }
            }
            .task {
                await viewModel.loadSpaces()
            }
            .onCloudKitImport {
                Task { await viewModel.loadSpaces() }
            }
        } detail: {
            Text("Select an item")
        }
        .sheet(isPresented: $viewModel.shouldShowSettings) {
            SettingsView()
        }
        .sheet(isPresented: $viewModel.shouldShowIdentityList) {
            IdentityListView()
        }
        .sheet(isPresented: $viewModel.shouldShowContactList) {
            ContactListView()
        }
        .sheet(isPresented: $viewModel.shouldShowAddSpace, onDismiss: {
            Task { await viewModel.loadSpaces() }
        }) {
            AddSpaceView()
        }
        .alert("Error", isPresented: .init(
            get: { viewModel.deleteSpaceError != nil },
            set: { if !$0 { viewModel.deleteSpaceError = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.deleteSpaceError ?? "")
        }
    }
}

// MARK: - Preview

#Preview {
    ContentView()
}
