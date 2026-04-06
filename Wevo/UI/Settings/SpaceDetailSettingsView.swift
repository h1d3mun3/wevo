//
//  SpaceDetailSettingsView.swift
//  Wevo
//
//  Created by hidemune on 3/10/26.
//

import SwiftUI
import os

struct SpaceDetailSettingsView: View {
    let space: Space

    @Environment(\.dependencies) private var deps
    @Environment(\.dismiss) private var dismiss
    @State private var currentSpace: Space

    init(space: Space) {
        self.space = space
        _currentSpace = State(initialValue: space)
    }

    var body: some View {
        List {
            Section("Information") {
                LabeledContent("Name") {
                    Text(currentSpace.name)
                        .textSelection(.enabled)
                }

                LabeledContent("Order Index") {
                    Text("\(currentSpace.orderIndex)")
                }
            }

            Section("Node URLs") {
                if currentSpace.urls.isEmpty {
                    Text("No URLs configured")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(Array(currentSpace.urls.enumerated()), id: \.offset) { index, url in
                        LabeledContent(index == 0 ? "Primary" : "Peer \(index)") {
                            Text(url)
                                .font(.caption)
                                .fontDesign(.monospaced)
                                .textSelection(.enabled)
                        }
                    }
                }
            }

            Section("IDs") {
                LabeledContent("Space ID") {
                    Text(currentSpace.id.uuidString)
                        .font(.caption)
                        .fontDesign(.monospaced)
                        .textSelection(.enabled)
                }

                if let defaultIdentityID = currentSpace.defaultIdentityID {
                    LabeledContent("Default Identity ID") {
                        Text(defaultIdentityID.uuidString)
                            .font(.caption)
                            .fontDesign(.monospaced)
                            .textSelection(.enabled)
                    }
                } else {
                    LabeledContent("Default Identity") {
                        Text("None")
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section("Timestamps") {
                LabeledContent("Created At") {
                    Text(currentSpace.createdAt, format: .dateTime)
                }

                LabeledContent("Updated At") {
                    Text(currentSpace.updatedAt, format: .dateTime)
                }
            }
        }
        .navigationTitle("Space Details")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .onCloudKitImport {
            reloadSpace()
        }
    }

    private func reloadSpace() {
        let useCase = GetSpaceUseCaseImpl(spaceRepository: deps.spaceRepository)
        do {
            currentSpace = try useCase.execute(id: space.id)
        } catch SpaceRepositoryError.spaceNotFound {
            dismiss()
        } catch {
            Logger.space.error("Failed to reload space: \(error, privacy: .public)")
        }
    }
}

#Preview("Space Detail Settings") {
    let space = Space(
        id: UUID(),
        name: "Preview Space",
        urls: ["https://node-a.example.com", "https://node-b.example.com"],
        defaultIdentityID: UUID(),
        orderIndex: 1,
        createdAt: .now,
        updatedAt: .now
    )

    NavigationStack {
        SpaceDetailSettingsView(space: space)
    }
}
