//
//  SettingsView.swift
//  Wevo
//
//  Created by hidemune on 3/7/26.
//

import SwiftUI
import SwiftData
import CryptoKit

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
