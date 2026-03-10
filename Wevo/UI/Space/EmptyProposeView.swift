//
//  EmptyProposeView.swift
//  Wevo
//
//  Created by hidemune on 3/10/26.
//

import SwiftUI

struct EmptyProposeView: View {
    let hasDefaultIdentity: Bool

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("No proposes found")
                .foregroundStyle(.secondary)
            if !hasDefaultIdentity {
                Text("Please set a default key for this space")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
    }
}

#Preview("Empty Propose") {
    EmptyProposeView(hasDefaultIdentity: false)
}
