//
//  VerifyProposeHashUseCase.swift
//  Wevo
//
//  Created on 3/11/26.
//

import Foundation

protocol VerifyProposeHashUseCase {
    func execute(message: String, payloadHash: String) -> Bool
}

struct VerifyProposeHashUseCaseImpl {
    init() {}
}

extension VerifyProposeHashUseCaseImpl: VerifyProposeHashUseCase {
    /// Verifies that the SHA256 hash of the message matches the payloadHash
    func execute(message: String, payloadHash: String) -> Bool {
        let messageHash = message.sha256HashedString
        let isValid = messageHash == payloadHash

        if isValid {
            print("✅ Hash valid: message hash matches payloadHash")
        } else {
            print("❌ Hash invalid: message hash (\(messageHash)) does not match payloadHash (\(payloadHash))")
        }

        return isValid
    }
}
