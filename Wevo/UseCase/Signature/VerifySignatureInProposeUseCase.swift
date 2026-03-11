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
    /// 署名IDからProposeを見つけ、署名を検証する
    /// - Parameters:
    ///   - signatureID: 検証対象の署名ID
    ///   - signatureData: Base64エンコードされた署名文字列
    ///   - publicKey: Base64エンコードされた公開鍵文字列
    /// - Returns: 署名が有効な場合はtrue
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
