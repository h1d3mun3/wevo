//
//  SpaceSelectorView.swift
//  Wevo
//
//  Created by hidemune on 3/5/26.
//

import SwiftUI

struct SpaceSelectorView: View {
    let propose: Propose
    let originalSpaceID: UUID
    let spaces: [Space]
    let onSelect: (Space) -> Void
    let onCancel: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Propose to Import")
                            .font(.headline)

                        Text(propose.message)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(3)

                        HStack {
                            Image(systemName: "signature")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                            Text(propose.localStatus.rawValue.capitalized)
                                .font(.caption)
                                .foregroundStyle(.tertiary)

                            Spacer()

                            Text(propose.createdAt, format: .dateTime.month().day().hour().minute())
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section("Select Space") {
                    ForEach(spaces) { space in
                        Button {
                            onSelect(space)
                            dismiss()
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(space.name)
                                        .font(.body)
                                        .foregroundStyle(.primary)

                                    Text(space.url)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                if space.id == originalSpaceID {
                                    Image(systemName: "arrow.down.circle.fill")
                                        .foregroundStyle(.blue)
                                        .font(.title3)
                                    Text("Original")
                                        .font(.caption)
                                        .foregroundStyle(.blue)
                                        .fontWeight(.medium)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .navigationTitle("Import Propose")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onCancel()
                        dismiss()
                    }
                }
            }
        }
#if os(macOS)
        .frame(minWidth: 400, minHeight: 400)
#endif
    }
}
