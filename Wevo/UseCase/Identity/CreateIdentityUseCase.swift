//
//  CreateIdentityUseCase.swift
//  Wevo
//
//  Created by hidemune on 3/9/26.
//

import Foundation
import CryptoKit

protocol CreateIdentityUseCase {
    func execute(nickname: String) throws
}

struct CreateIdentityUseCaseImpl {
    let keychainRepository: KeychainRepository
    
    init(keychainRepository: KeychainRepository) {
        self.keychainRepository = keychainRepository
    }
}

extension CreateIdentityUseCaseImpl: CreateIdentityUseCase {
    func execute(nickname: String) throws {
        // Generate P256 key pair (for SecureEnclave compatibility)
        let privateKey = P256.Signing.PrivateKey()
        let privateKeyData = privateKey.rawRepresentation
        
        // Save to Keychain
        let id = UUID()
        let trimmedNickname = nickname.trimmingCharacters(in: .whitespacesAndNewlines)
        try keychainRepository.createIdentity(
            id: id,
            nickname: trimmedNickname,
            privateKey: privateKeyData
        )
        
        // Log the public key (for debugging)
        let publicKeyData = privateKey.publicKey.rawRepresentation
        
        print("✅ Identity Key saved successfully")
        print("ID: \(id)")
        print("Nickname: \(trimmedNickname)")
        print("Public Key: \(publicKeyData.base64EncodedString())")
    }
}
