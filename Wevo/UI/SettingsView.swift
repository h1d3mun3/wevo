//
//  SettingsView.swift
//  Wevo
//
//  Created by hidemune on 3/7/26.
//

import SwiftUI

struct SettingsView: View {
    @Environment(\.dependencies) private var deps
    @Environment(\.dismiss) private var dismiss

    @State private var proposes: [Propose] = []
    @State private var spaces: [Space] = []
    @State private var signatures: [Signature] = []
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
        do {
            proposes = try deps.proposeRepository.fetchAll()
        } catch {
            print("❌ Error loading proposes: \(error)")
            proposes = []
        }

        // Spacesを取得
        do {
            spaces = try deps.spaceRepository.fetchAll()
        } catch {
            print("❌ Error loading spaces: \(error)")
            spaces = []
        }

        // Signaturesを取得
        do {
            signatures = try deps.signatureRepository.fetchAll()
        } catch {
            print("❌ Error loading signatures: \(error)")
            signatures = []
        }
    }
}

#Preview("Settings") {
    SettingsView()
}
