//
//  DataBrowserView.swift
//  Wevo
//

import SwiftUI
import os

struct DataBrowserView: View {
    @Environment(\.dependencies) private var deps

    @State private var proposes: [Propose] = []
    @State private var spaces: [Space] = []
    @State private var selectedTab = 0

    var body: some View {
        VStack(spacing: 0) {
            Picker("Data Type", selection: $selectedTab) {
                Text("Proposes").tag(0)
                Text("Spaces").tag(1)
            }
            .pickerStyle(.segmented)
            .padding()

            Divider()

            if selectedTab == 0 {
                ProposeListView(proposes: proposes, onDelete: loadData)
            } else {
                SpaceListView(spaces: spaces, onDelete: loadData)
            }
        }
        .navigationTitle("Data Browser")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
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
        .onCloudKitImport {
            loadData()
        }
    }

    private func loadData() {
        let useCase = LoadSettingsDataUseCaseImpl(
            proposeRepository: deps.proposeRepository,
            spaceRepository: deps.spaceRepository
        )

        do {
            let data = try useCase.execute()
            proposes = data.proposes
            spaces = data.spaces
        } catch {
            Logger.app.error("Error loading settings data: \(error, privacy: .public)")
            proposes = []
            spaces = []
        }
    }
}
