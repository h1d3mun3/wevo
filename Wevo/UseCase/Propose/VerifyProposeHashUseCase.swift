//
//  VerifyProposeHashUseCase.swift
//  Wevo
//
//  Created on 3/11/26.
//

import Foundation
import os

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
            Logger.propose.info("Hash valid: message hash matches payloadHash")
        } else {
            Logger.propose.warning("Hash invalid: message hash does not match payloadHash")
        }

        return isValid
    }
}
