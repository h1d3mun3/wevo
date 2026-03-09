//
//  VerifySignatureUseCase.swift
//  Wevo
//
//  Created by hidemune on 3/9/26.
//

import Foundation

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
    /// 署名を検証する
    /// - Parameters:
    ///   - signature: Base64エンコードされた署名文字列
    ///   - message: 署名対象のメッセージ文字列
    ///   - publicKey: Base64エンコードされた公開鍵文字列（x963Representation形式）
    /// - Returns: 署名が有効な場合はtrue、無効な場合はfalse
    func execute(signature: String, message: String, publicKey: String) throws -> Bool {
        do {
            let isValid = try keychainRepository.verifySignature(
                signature,
                for: message,
                withPublicKeyString: publicKey
            )
            
            if isValid {
                print("✅ Signature verification succeeded")
            } else {
                print("⚠️ Signature verification failed - invalid signature")
            }
            
            return isValid
        } catch {
            print("❌ Failed to verify signature: \(error)")
            throw VerifySignatureUseCaseError.verificationFailed
        }
    }
}
