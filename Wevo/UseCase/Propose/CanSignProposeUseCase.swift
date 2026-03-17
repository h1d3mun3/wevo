//
//  CanSignProposeUseCase.swift
//  Wevo
//
//  Created on 3/17/26.
//

import Foundation

protocol CanSignProposeUseCase {
    /// Returns true if the given identity can sign the given propose
    /// Condition: identity.publicKey == propose.counterpartyPublicKey && propose.localStatus == .proposed
    func execute(identity: Identity, propose: Propose) -> Bool
}

struct CanSignProposeUseCaseImpl {}

extension CanSignProposeUseCaseImpl: CanSignProposeUseCase {
    func execute(identity: Identity, propose: Propose) -> Bool {
        identity.publicKey == propose.counterpartyPublicKey && propose.localStatus == .proposed
    }
}
