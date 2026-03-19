//
//  VerifySignatureUseCase.swift
//  Wevo
//
//  Created by hidemune on 3/9/26.
//

import Foundation
import os

enum VerifySignatureUseCaseError: Error {
    case verificationFailed
    case invalidSignature
}

protocol VerifySignatureUseCase {
    func execute(signature: String, message: String, publicKey: String) throws -> Bool
}

struct VerifySignatureUseCaseImpl {
    let keychainRepository: KeychainRepository

    init(keychainRepository: KeychainRepository) {
        self.keychainRepository = keychainRepository
    }
}

extension VerifySignatureUseCaseImpl: VerifySignatureUseCase {
    /// Verifies a signature
    /// - Parameters:
    ///   - signature: Base64-encoded signature string
    ///   - message: The message string that was signed
    ///   - publicKey: Public key string (JWK format)
    /// - Returns: true if the signature is valid, false if invalid
    func execute(signature: String, message: String, publicKey: String) throws -> Bool {
        do {
            let isValid = try keychainRepository.verifySignature(
                signature,
                for: message,
                withPublicKeyString: publicKey
            )
            
            if isValid {
                Logger.propose.info("Signature verification succeeded")
            } else {
                Logger.propose.warning("Signature verification failed - invalid signature")
            }

            return isValid
        } catch {
            Logger.propose.error("Failed to verify signature: \(error, privacy: .public)")
            throw VerifySignatureUseCaseError.verificationFailed
        }
    }
}
