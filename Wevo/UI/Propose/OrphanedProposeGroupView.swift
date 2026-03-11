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

    var body: some View {
        VStack(spacing: 0) {
            // Header
            SpaceHeaderView(
                space: Space(
                    id: spaceID,
                    name: "Unknown Space",
                    url: "",
                    defaultIdentityID: nil,
                    orderIndex: 0,
                    createdAt: .now,
                    updatedAt: .now
                ),
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
                        ProposeRowView(propose: propose, space: Space(
                            id: spaceID,
                            name: "Unknown Space",
                            url: "",
                            defaultIdentityID: nil,
                            orderIndex: 0,
                            createdAt: .now,
                            updatedAt: .now
                        )) {
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
    let signature = Signature(
        id: UUID(),
        publicKey: "PreviewPk",
        signature: "PreviewSig",
        createdAt: .now
    )

    let spaceID = UUID()
    let proposes = [
        Propose(id: UUID(), spaceID: spaceID, message: "Preview orphaned message 1", signatures: [signature], createdAt: .now, updatedAt: .now),
        Propose(id: UUID(), spaceID: spaceID, message: "Preview orphaned message 2", signatures: [signature], createdAt: .now, updatedAt: .now)
    ]

    NavigationStack {
        OrphanedProposeGroupView(spaceID: UUID(), proposes: proposes)
    }
}
