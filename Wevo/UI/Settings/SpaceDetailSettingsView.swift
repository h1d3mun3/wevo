//
//  SpaceDetailSettingsView.swift
//  Wevo
//
//  Created by hidemune on 3/10/26.
//

import SwiftUI
import SwiftData

struct SpaceDetailSettingsView: View {
    let space: SpaceSwiftData

    var body: some View {
        List {
            Section("Information") {
                LabeledContent("Name") {
                    Text(space.name)
                        .textSelection(.enabled)
                }

                LabeledContent("URL") {
                    Text(space.urlString)
                        .font(.caption)
                        .textSelection(.enabled)
                }

                LabeledContent("Order Index") {
                    Text("\(space.orderIndex)")
                }
            }

            Section("IDs") {
                LabeledContent("Space ID") {
                    Text(space.id.uuidString)
                        .font(.caption)
                        .fontDesign(.monospaced)
                        .textSelection(.enabled)
                }

                if let defaultIdentityID = space.defaultIdentityID {
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
                    Text(space.createdAt, format: .dateTime)
                }

                LabeledContent("Updated At") {
                    Text(space.updatedAt, format: .dateTime)
                }
            }
        }
        .navigationTitle("Space Details")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}
