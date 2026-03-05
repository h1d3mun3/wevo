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
    @Environment(\.modelContext) private var modelContext
    @Query private var items: [Item]

    var body: some View {
        NavigationSplitView {
            List {
                ForEach(items) { item in
                    NavigationLink {
                        Text("Item at \(item.timestamp, format: Date.FormatStyle(date: .numeric, time: .standard))")
                    } label: {
                        Text(item.timestamp, format: Date.FormatStyle(date: .numeric, time: .standard))
                    }
                }
                .onDelete(perform: deleteItems)
            }
#if os(macOS)
            .navigationSplitViewColumnWidth(min: 180, ideal: 200)
#endif
            .toolbar {
#if os(iOS)
                ToolbarItem(placement: .navigationBarTrailing) {
                    EditButton()
                }
#endif
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
        } detail: {
            Text("Select an item")
        }
        .sheet(isPresented: $shouldShowIdentityList) {
            IdentityListView()
        }
        .sheet(isPresented: $shouldShowAddSpace) {
            AddSpaceView()
        }
    }

    private func addItem() {
        withAnimation {
            let newItem = Item(timestamp: Date())
            modelContext.insert(newItem)
        }
    }

    private func deleteItems(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(items[index])
            }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Item.self, inMemory: true)
}
