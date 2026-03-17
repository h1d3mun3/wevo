//
//  ProposeListView.swift
//  Wevo
//
//  Created by hidemune on 3/10/26.
//

import SwiftUI
import os

struct ProposeListView: View {
    let proposes: [Propose]
    @Environment(\.dependencies) private var deps

    @State private var proposeToDelete: Propose?
    @State private var showDeleteAlert = false

    var onDelete: () -> Void = {}

    var body: some View {
        List {
            if proposes.isEmpty {
                Text("No proposes in database")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
            } else {
                ForEach(proposes) { propose in
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
                                // Local status icon (proposed=⏳, signed=✅)
                                Image(systemName: propose.localStatus == .proposed ? "clock" : "checkmark.circle.fill")
                                    .font(.caption)
                                    .foregroundStyle(propose.localStatus == .proposed ? .orange : .green)
                                Text(propose.localStatus.rawValue.capitalized)
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

    private func deletePropose(_ propose: Propose) {
        let deleteProposeUseCase = DeleteProposeUseCaseImpl(proposeRepository: deps.proposeRepository)
        do {
            try deleteProposeUseCase.execute(id: propose.id)
            Logger.propose.info("Propose deleted: \(propose.id, privacy: .private)")
            onDelete()
        } catch {
            Logger.propose.error("Error deleting propose: \(error, privacy: .public)")
        }
    }
}

#Preview("Propose List") {
    let propose = Propose(
        id: UUID(),
        spaceID: UUID(),
        message: "Preview propose",
        creatorPublicKey: "creatorPublicKey",
        creatorSignature: "creatorSignature",
        counterpartyPublicKey: "counterpartyPublicKey",
        counterpartySignSignature: nil,
        createdAt: .now,
        updatedAt: .now
    )

    ProposeListView(proposes: [propose])
}
