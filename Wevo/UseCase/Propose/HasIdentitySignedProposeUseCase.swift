//
//  HasIdentitySignedProposeUseCase.swift
//  Wevo
//
//  Created on 3/11/26.
//

import Foundation

protocol HasIdentitySignedProposeUseCase {
    /// Returns whether the specified Identity has signed the Propose
    /// - Creator: always true (Creator always signs at Propose creation time)
    /// - Counterparty: true when counterpartySignSignature exists
    func execute(identity: Identity, propose: Propose) -> Bool
}

struct HasIdentitySignedProposeUseCaseImpl: HasIdentitySignedProposeUseCase {
    func execute(identity: Identity, propose: Propose) -> Bool {
        let myPublicKey = identity.publicKey

        // Creator is always signed (they always sign when creating a Propose)
        if myPublicKey == propose.creatorPublicKey {
            return true
        }

        // Counterparty is determined by the presence of counterpartySignSignature
        if myPublicKey == propose.counterpartyPublicKey {
            return propose.counterpartySignSignature != nil
        }

        // Not a participant, return false
        return false
    }
}
