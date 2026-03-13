//
//  SettingsView.swift
//  Wevo
//
//  Created by hidemune on 3/7/26.
//

import SwiftUI
import CloudKit

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                NavigationLink {
                    DataBrowserView()
                } label: {
                    Label("Data Browser", systemImage: "cylinder.split.1x2")
                }

                Section("CloudKit") {
                    LabeledContent("Container Identifier") {
                        if let identifier = CKContainer.default().containerIdentifier {
                            Text(identifier)
                        } else {
                            Text("Unknown")
                                .foregroundStyle(.orange)
                        }
                    }
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
            }
        }
#if os(macOS)
        .frame(minWidth: 400, minHeight: 500)
#endif
    }
}

#Preview("Settings") {
    SettingsView()
}
