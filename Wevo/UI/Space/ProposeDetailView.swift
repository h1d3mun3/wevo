//
//  ProposeDetailView.swift
//  Wevo
//
//  Created by hidemune on 3/10/26.
//

import SwiftUI

struct ProposeDetailView: View {
    let propose: Propose
    let space: Space

    var body: some View {
        ProposeSettingsDetailView(propose: propose)
#if os(macOS)
            .frame(minWidth: 400, minHeight: 500)
#endif
    }
}

#Preview("Propose Detail") {
    let signature = Signature(
        id: UUID(),
        publicKey: "PreviewPublicKey",
        signature: "PreviewSignature",
        createdAt: .now
    )

    let space = Space(
        id: UUID(),
        name: "Preview Space",
        url: "https://example.com",
        defaultIdentityID: nil,
        orderIndex: 0,
        createdAt: .now,
        updatedAt: .now
    )

    let propose = Propose(
        id: UUID(),
        spaceID: space.id,
        message: "Preview message",
        signatures: [signature],
        createdAt: .now,
        updatedAt: .now
    )

    ProposeDetailView(propose: propose, space: space)
}
