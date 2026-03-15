//
//  VerifySignatureInProposeUseCase.swift
//  Wevo
//
//  Created on 3/11/26.
//

import Foundation

protocol VerifySignatureInProposeUseCase {
    func execute(signatureID: UUID, signatureData: String, publicKey: String) throws -> Bool
}

struct VerifySignatureInProposeUseCaseImpl {
    let signatureRepository: SignatureRepository
    let keychainRepository: KeychainRepository

    init(signatureRepository: SignatureRepository, keychainRepository: KeychainRepository) {
        self.signatureRepository = signatureRepository
        self.keychainRepository = keychainRepository
    }
}

extension VerifySignatureInProposeUseCaseImpl: VerifySignatureInProposeUseCase {
    /// Finds the Propose from the signature ID and verifies the signature
    /// - Parameters:
    ///   - signatureID: The signature ID to verify
    ///   - signatureData: Base64-encoded signature string
    ///   - publicKey: Base64-encoded public key string
    /// - Returns: true if the signature is valid
    func execute(signatureID: UUID, signatureData: String, publicKey: String) throws -> Bool {
        let payloadHash = try signatureRepository.fetchPayloadHash(forSignatureID: signatureID)

        let isValid = try keychainRepository.verifySignature(
            signatureData,
            for: payloadHash,
            withPublicKeyString: publicKey
        )

        if isValid {
            print("✅ Signature verification succeeded: \(signatureID)")
        } else {
            print("⚠️ Signature verification failed: \(signatureID)")
        }

        return isValid
    }
}
