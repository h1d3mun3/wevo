//
//  HasIdentitySignedProposeUseCase.swift
//  Wevo
//
//  Created on 3/11/26.
//

import Foundation

protocol HasIdentitySignedProposeUseCase {
    func execute(identity: Identity, proposeSignatures: [Signature], serverSignatures: [Signature]) -> Bool
}

struct HasIdentitySignedProposeUseCaseImpl: HasIdentitySignedProposeUseCase {
    func execute(identity: Identity, proposeSignatures: [Signature], serverSignatures: [Signature]) -> Bool {
        let myPublicKey = identity.publicKey
        let allSignatures = proposeSignatures + serverSignatures
        return allSignatures.contains { $0.publicKey == myPublicKey }
    }
}
