//
//  SpaceHeaderView.swift
//  Wevo
//
//  Created by hidemune on 3/10/26.
//

import SwiftUI

struct SpaceHeaderView: View {
    let space: Space
    let defaultIdentity: Identity?
    let onEditTapped: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(space.name)
                        .font(.title)
                        .fontWeight(.bold)

                    Text(space.url)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if let identity = defaultIdentity {
                        Text("Default Key: \(identity.nickname)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                Button {
                    onEditTapped()
                } label: {
                    Text("Edit Space")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
    }
}

#Preview("Space Header") {
    SpaceHeaderView(
        space: Space(
            id: UUID(),
            name: "Preview Space",
            url: "https://example.com",
            defaultIdentityID: nil,
            orderIndex: 0,
            createdAt: .now,
            updatedAt: .now
        ),
        defaultIdentity: Identity(
            id: UUID(),
            nickname: "My Identity",
            publicKey: "PUBLIC_KEY"
        ),
        onEditTapped: {}
    )
}
