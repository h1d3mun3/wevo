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

    @Environment(\.dependencies) private var deps
    @Environment(\.dismiss) private var dismiss
    @State private var currentPropose: Propose

    init(propose: Propose, space: Space) {
        self.propose = propose
        self.space = space
        _currentPropose = State(initialValue: propose)
    }

    var body: some View {
        ProposeSettingsDetailView(propose: currentPropose)
#if os(macOS)
            .frame(minWidth: 400, minHeight: 500)
#endif
            .onCloudKitImport {
                reloadPropose()
            }
    }

    private func reloadPropose() {
        let useCase = GetProposeUseCaseImpl(proposeRepository: deps.proposeRepository)
        do {
            currentPropose = try useCase.execute(id: propose.id)
        } catch ProposeRepositoryError.proposeNotFound {
            dismiss()
        } catch {
            print("Failed to reload propose: \(error)")
        }
    }
}

#Preview("Propose Detail") {
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
        creatorPublicKey: "creatorPublicKey",
        creatorSignature: "creatorSignature",
        counterpartyPublicKey: "counterpartyPublicKey",
        counterpartySignSignature: nil,
        createdAt: .now,
        updatedAt: .now
    )

    ProposeDetailView(propose: propose, space: space)
}
