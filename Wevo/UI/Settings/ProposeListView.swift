//
//  ProposeListView.swift
//  Wevo
//
//  Created by hidemune on 3/10/26.
//

import SwiftUI
import SwiftData

struct ProposeListView: View {
    let proposes: [ProposeSwiftData]
    @Environment(\.modelContext) private var modelContext

    @State private var proposeToDelete: ProposeSwiftData?
    @State private var showDeleteAlert = false

    var onDelete: () -> Void = {}

    var body: some View {
        List {
            if proposes.isEmpty {
                Text("No proposes in database")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
            } else {
                ForEach(proposes, id: \.id) { propose in
                    NavigationLink {
                        ProposeSettingsDetailView(propose: propose)
                    } label: {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(propose.message)
                                .font(.headline)
                                .lineLimit(2)

                            HStack {
                                Text("Created:")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(propose.createdAt, format: .dateTime.month().day().hour().minute())
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            HStack {
                                Image(systemName: "signature")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text("\((propose.signatures ?? []).count) signature(s)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                }
                .onDelete { indexSet in
                    for index in indexSet {
                        let propose = proposes[index]
                        deletePropose(propose)
                    }
                }
            }
        }
        .listStyle(.plain)
        .alert("Delete Propose", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                if let propose = proposeToDelete {
                    deletePropose(propose)
                }
            }
        } message: {
            if let propose = proposeToDelete {
                Text("Are you sure you want to delete this propose?\n\n\(propose.message)")
            }
        }
    }

    private func deletePropose(_ propose: ProposeSwiftData) {
        let deleteProposeUseCase = DeleteProposeUseCaseImpl(proposeRepository: ProposeRepositoryImpl(modelContext: modelContext))
        do {
            try deleteProposeUseCase.execute(id: propose.id)
            print("✅ Propose deleted: \(propose.id)")
            onDelete()
        } catch {
            print("❌ Error deleting propose: \(error)")
        }
    }
}

#Preview("Propose List") {
    let signature = SignatureSwiftData(
        id: UUID(),
        publicKey: "SamplePublicKey",
        signatureData: "SampleSignature",
        createdAt: .now
    )

    let propose = ProposeSwiftData(
        id: UUID(),
        message: "Preview propose",
        payloadHash: "samplehash",
        spaceID: UUID(),
        signatures: [signature],
        createdAt: .now,
        updatedAt: .now
    )

    ProposeListView(proposes: [propose])
        .modelContainer(for: [SpaceSwiftData.self, ProposeSwiftData.self, SignatureSwiftData.self], inMemory: true)
}
