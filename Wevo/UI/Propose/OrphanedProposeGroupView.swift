//
//  OrphanedProposeGroupView.swift
//  Wevo
//
//  Created by hidemune on 3/10/26.
//

import SwiftUI

struct OrphanedProposeGroupView: View {
    let spaceID: UUID
    let proposes: [Propose]

    /// Synthetic stand-in for the deleted parent Space. Uses a fixed timestamp (not `.now`)
    /// so its `updatedAt` is stable across renders — otherwise every re-render would look
    /// like a Space edit to ProposeRowView's `onChange(of: space.updatedAt)`.
    private var placeholderSpace: Space {
        Space(
            id: spaceID,
            name: "Unknown Space",
            url: "",
            defaultIdentityID: nil,
            orderIndex: 0,
            createdAt: Date(timeIntervalSince1970: 0),
            updatedAt: Date(timeIntervalSince1970: 0)
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            SpaceHeaderView(
                space: placeholderSpace,
                defaultIdentity: nil,
                onEditTapped: {}
            )

            Divider()

            // Content
            if proposes.isEmpty {
                Spacer()
                EmptyProposeView(hasDefaultIdentity: false)
                Spacer()
            } else {
                List {
                    ForEach(proposes) { propose in
                        ProposeRowView(propose: propose, space: placeholderSpace) {
                            // Refresh on signing
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("Unknown Space")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}

#Preview("Orphaned Propose Group") {
    let spaceID = UUID()
    let proposes = [
        Propose(
            id: UUID(),
            spaceID: spaceID,
            message: "Preview orphaned message 1",
            creatorPublicKey: "creatorKey",
            creatorSignature: "creatorSig",
            counterpartyPublicKey: "counterpartyKey",
            counterpartySignSignature: nil,
            createdAt: .now,
            updatedAt: .now
        ),
        Propose(
            id: UUID(),
            spaceID: spaceID,
            message: "Preview orphaned message 2",
            creatorPublicKey: "creatorKey",
            creatorSignature: "creatorSig",
            counterpartyPublicKey: "counterpartyKey",
            counterpartySignSignature: nil,
            createdAt: .now,
            updatedAt: .now
        )
    ]

    NavigationStack {
        OrphanedProposeGroupView(spaceID: UUID(), proposes: proposes)
    }
}
