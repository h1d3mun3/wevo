//
//  ContentView.swift
//  Wevo
//
//  Created by hidemune on 3/5/26.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @State private var shouldShowIdentityList = false
    @State private var shouldShowAddSpace = false
    @State private var shouldShowSettings = false
    @State private var spaces: [Space] = []
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        NavigationSplitView {
            List {
                if spaces.isEmpty {
                    Text("No spaces available")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(spaces, id: \.id) { space in
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
#if os(macOS)
            .navigationSplitViewColumnWidth(min: 180, ideal: 200)
#endif
            .toolbar {
                ToolbarItem(placement: .navigation) {
                    Button(action: { shouldShowSettings = true }) {
                        Label("Settings", systemImage: "gearshape.fill")
                    }
                }
                
                ToolbarItem {
                    Button(action: { shouldShowIdentityList = true }) {
                        Label("Manage Keys", systemImage: "key.fill")
                    }
                }

                ToolbarItem{
                    Button(action: { shouldShowAddSpace = true }) {
                        Label("Add Space", systemImage: "globe")
                    }
                }
            }
            .task {
                await loadSpaces()
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
        .sheet(isPresented: $shouldShowAddSpace, onDismiss: {
            Task {
                await loadSpaces()
            }
        }) {
            AddSpaceView()
        }
    }

    private func loadSpaces() async {
        let repository = SpaceRepository(modelContext: modelContext)
        do {
            let loadedSpaces = try repository.fetchAll()
            await MainActor.run {
                spaces = loadedSpaces
            }
        } catch {
            print("❌ Error loading spaces: \(error)")
            await MainActor.run {
                spaces = []
            }
        }
    }
    
    private func deleteSpace(offsets: IndexSet) {
        Task {
            let repository = SpaceRepository(modelContext: modelContext)
            do {
                for index in offsets {
                    let space = spaces[index]
                    try repository.delete(by: space.id)
                }
                await loadSpaces()
            } catch {
                print("❌ Error deleting space: \(error)")
                // TODO: エラーをユーザーに表示
            }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: SpaceSwiftData.self, inMemory: true)
}
