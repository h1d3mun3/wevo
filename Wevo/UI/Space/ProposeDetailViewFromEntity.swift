//
//  ProposeDetailViewFromEntity.swift
//  Wevo
//
//  Created by hidemune on 3/10/26.
//

import SwiftUI
import SwiftData

struct ProposeDetailViewFromEntity: View {
    let propose: Propose
    let space: Space
    let modelContext: ModelContext

    @State private var proposeSwiftData: ProposeSwiftData?
    @State private var isLoading = true

    var body: some View {
        Group {
            if isLoading {
                ProgressView("Loading...")
            } else if let proposeSwiftData = proposeSwiftData {
                ProposeSettingsDetailView(propose: proposeSwiftData)
            } else {
                VStack {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    Text("Propose not found")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .task {
            await loadProposeSwiftData()
        }
    }

    private func loadProposeSwiftData() async {
        let proposeID = propose.id
        let predicate = #Predicate<ProposeSwiftData> { model in
            model.id == proposeID
        }

        var descriptor = FetchDescriptor<ProposeSwiftData>(predicate: predicate)
        descriptor.fetchLimit = 1

        do {
            let models = try modelContext.fetch(descriptor)
            await MainActor.run {
                proposeSwiftData = models.first
                isLoading = false
            }
        } catch {
            print("❌ Error loading ProposeSwiftData: \(error)")
            await MainActor.run {
                isLoading = false
            }
        }
    }
}
