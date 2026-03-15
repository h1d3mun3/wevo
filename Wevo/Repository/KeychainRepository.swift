//
//  KeychainRepository.swift
//  Wevo
//
//  Created by hidemune on 3/5/26.
//

import Foundation
import Security
import CryptoKit

/// Information for the IdentityKey stored in the Keychain
private struct IdentityKeyChainItem {
    let id: UUID
    let nickname: String
    let privateKey: Data
    let publicKey: Data
}

/// Metadata only
private struct IdentityMetadataKeychainItem: Codable {
    let id: UUID
    let nickname: String
    let publicKey: Data
}

enum KeychainError: Error, Equatable {
    case duplicateItem
    case itemNotFound
    case invalidData
    case unhandledError(status: OSStatus)
    case biometricAuthFailed
    case accessControlCreationFailed
}

protocol KeychainRepository {
    func createIdentity(id: UUID, nickname: String, privateKey: Data) throws
    func getAllIdentities() throws -> [Identity]
    func getIdentity(id: UUID) throws -> Identity
    func getPrivateKey(id: UUID) throws -> Data
    func updateNickname(id: UUID, newNickname: String) throws
    func deleteIdentityKey(id: UUID) throws
    func deleteAllIdentityKeys() throws
    func migrateKey(id: UUID) throws
    func signMessage(_ message: String, withIdentityId identityId: UUID) throws -> String
    func verifySignature(_ signature: String, for message: String, withPublicKeyString publicKeyString: String) throws -> Bool
}

final class KeychainRepositoryImpl: KeychainRepository {
    private let serviceMetadata = "com.wevo.identitykeys.metadata"
    private let servicePrivateKey = "com.wevo.identitykeys.privatekey"
    
    init() {}
    
    // MARK: - Save
    
    /// Create and save a new Identity
    func createIdentity(id: UUID, nickname: String, privateKey: Data) throws {
        // Derive public key from private key (using P256 signing key)
        let key = try P256.Signing.PrivateKey(rawRepresentation: privateKey)
        // Save in x963Representation format (for server compatibility)
        let publicKey = key.publicKey.x963Representation
        
        let item = IdentityKeyChainItem(
            id: id,
            nickname: nickname,
            privateKey: privateKey,
            publicKey: publicKey
        )
        try saveIdentityKey(item)
    }

    /// Save an IdentityKey
    private func saveIdentityKey(_ item: IdentityKeyChainItem) throws {
        try saveIdentityMetadata(item)
        try savePrivateKey(item)
    }

    /// Save IdentityKey metadata
    private func saveIdentityMetadata(_ item: IdentityKeyChainItem) throws {
        let encoder = JSONEncoder()
        let metadata = IdentityMetadataKeychainItem(
            id: item.id,
            nickname: item.nickname,
            publicKey: item.publicKey
        )
        let metadataData = try encoder.encode(metadata)
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceMetadata,
            kSecAttrAccount as String: item.id.uuidString,
            kSecValueData as String: metadataData,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
            kSecAttrSynchronizable as String: true
        ]
        
        let status = SecItemAdd(query as CFDictionary, nil)
        
        guard status != errSecDuplicateItem else {
            throw KeychainError.duplicateItem
        }
        
        guard status == errSecSuccess else {
            throw KeychainError.unhandledError(status: status)
        }
    }
    
    /// Save the private key
    private func savePrivateKey(_ item: IdentityKeyChainItem) throws {
        let encoder = JSONEncoder()
        let privateKeyData = try encoder.encode(PrivateKeyData(privateKey: item.privateKey))
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: servicePrivateKey,
            kSecAttrAccount as String: item.id.uuidString,
            kSecValueData as String: privateKeyData,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
            kSecAttrSynchronizable as String: true
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        
        guard status != errSecDuplicateItem else {
            throw KeychainError.duplicateItem
        }
        
        guard status == errSecSuccess else {
            throw KeychainError.unhandledError(status: status)
        }
    }

    // MARK: - Retrieve
    
    /// Retrieve all Identity metadata
    private func getAllIdentityMetadata() throws -> [IdentityMetadataKeychainItem] {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceMetadata,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitAll,
            kSecAttrSynchronizable as String: kSecAttrSynchronizableAny
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess else {
            if status == errSecItemNotFound {
                return []
            }
            throw KeychainError.unhandledError(status: status)
        }
        
        guard let dataArray = result as? [Data] else {
            throw KeychainError.invalidData
        }
        
        let decoder = JSONDecoder()
        return try dataArray.map { data in
            try decoder.decode(IdentityMetadataKeychainItem.self, from: data)
        }
    }
    
    /// Retrieve all Identities
    func getAllIdentities() throws -> [Identity] {
        let metadataList = try getAllIdentityMetadata()
        return metadataList.map { metadata in
            Identity(id: metadata.id, nickname: metadata.nickname, publicKey: metadata.publicKey.base64EncodedString())
        }
    }
    
    /// Retrieve metadata for a specific ID
    fileprivate func getIdentityMetadata(id: UUID) throws -> IdentityMetadataKeychainItem {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceMetadata,
            kSecAttrAccount as String: id.uuidString,
            kSecReturnData as String: kCFBooleanTrue as Any, // Explicit CFBoolean
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecAttrSynchronizable as String: kSecAttrSynchronizableAny // Confirm cast
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess else {
            if status == errSecItemNotFound {
                throw KeychainError.itemNotFound
            }
            throw KeychainError.unhandledError(status: status)
        }
        
        guard let data = result as? Data else {
            throw KeychainError.invalidData
        }
        
        let decoder = JSONDecoder()
        return try decoder.decode(IdentityMetadataKeychainItem.self, from: data)
    }

    func getIdentity(id: UUID) throws -> Identity {
        let metadata = try getIdentityMetadata(id: id)

        return Identity(id: metadata.id, nickname: metadata.nickname, publicKey: metadata.publicKey.base64EncodedString())
    }

    /// Retrieve the private key
    func getPrivateKey(id: UUID) throws -> Data {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: servicePrivateKey,
            kSecAttrAccount as String: id.uuidString,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecAttrSynchronizable as String: kSecAttrSynchronizableAny
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess else {
            if status == errSecItemNotFound {
                throw KeychainError.itemNotFound
            }
            if status == errSecAuthFailed {
                throw KeychainError.biometricAuthFailed
            }
            throw KeychainError.unhandledError(status: status)
        }
        
        guard let data = result as? Data else {
            throw KeychainError.invalidData
        }
        
        let decoder = JSONDecoder()
        let privateKeyData = try decoder.decode(PrivateKeyData.self, from: data)
        return privateKeyData.privateKey
    }
    
    /// Retrieve the IdentityKey for a specific ID
    private func getIdentityKey(id: UUID) throws -> IdentityKeyChainItem {
        let metadata = try getIdentityMetadata(id: id)
        let privateKey = try getPrivateKey(id: id)
        
        return IdentityKeyChainItem(
            id: metadata.id,
            nickname: metadata.nickname,
            privateKey: privateKey,
            publicKey: metadata.publicKey
        )
    }

    // MARK: - Update
    
    /// Update the nickname of an IdentityKey
    func updateNickname(id: UUID, newNickname: String) throws {
        let existingMetadata = try getIdentityMetadata(id: id)

        let encoder = JSONEncoder()
        let updatedMetadata = IdentityMetadataKeychainItem(
            id: id,
            nickname: newNickname,
            publicKey: existingMetadata.publicKey
        )
        let metadataData = try encoder.encode(updatedMetadata)

        // Add synchronization flag to search criteria
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceMetadata,
            kSecAttrAccount as String: id.uuidString,
            kSecAttrSynchronizable as String: kSecAttrSynchronizableAny // Required
        ]

        let attributesToUpdate: [String: Any] = [
            kSecValueData as String: metadataData
        ]

        let status = SecItemUpdate(query as CFDictionary, attributesToUpdate as CFDictionary)

        guard status == errSecSuccess else {
            if status == errSecItemNotFound {
                throw KeychainError.itemNotFound
            }
            throw KeychainError.unhandledError(status: status)
        }
    }
    
    // MARK: - Delete
    
    /// Delete the IdentityKey for a specific ID (both metadata and private key)
    func deleteIdentityKey(id: UUID) throws {
        // Delete metadata
        let metadataQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceMetadata,
            kSecAttrAccount as String: id.uuidString,
            kSecAttrSynchronizable as String: kSecAttrSynchronizableAny
        ]
        
        let metadataStatus = SecItemDelete(metadataQuery as CFDictionary)
        
        // Delete private key
        let privateKeyQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: servicePrivateKey,
            kSecAttrAccount as String: id.uuidString,
            kSecAttrSynchronizable as String: kSecAttrSynchronizableAny
        ]

        let privateKeyStatus = SecItemDelete(privateKeyQuery as CFDictionary)

        // Throw if either operation failed with an error other than "not found"
        guard (metadataStatus == errSecSuccess || metadataStatus == errSecItemNotFound) &&
              (privateKeyStatus == errSecSuccess || privateKeyStatus == errSecItemNotFound) else {
            throw KeychainError.unhandledError(status: metadataStatus)
        }
    }
    
    /// Delete all IdentityKeys (both metadata and private keys)
    func deleteAllIdentityKeys() throws {
        // Delete metadata
        let metadataQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceMetadata,
            kSecAttrSynchronizable as String: kSecAttrSynchronizableAny
        ]

        let metadataStatus = SecItemDelete(metadataQuery as CFDictionary)

        // Delete private keys
        let privateKeyQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: servicePrivateKey,
            kSecAttrSynchronizable as String: kSecAttrSynchronizableAny
        ]
        
        let privateKeyStatus = SecItemDelete(privateKeyQuery as CFDictionary)
        
        guard (metadataStatus == errSecSuccess || metadataStatus == errSecItemNotFound) &&
              (privateKeyStatus == errSecSuccess || privateKeyStatus == errSecItemNotFound) else {
            throw KeychainError.unhandledError(status: metadataStatus)
        }
    }
}

// MARK: - Private Helper

private struct PrivateKeyData: Codable {
    let privateKey: Data
}
// MARK: - Signing Extension

extension KeychainRepositoryImpl {
    
    /// Sign a String using the private key of the specified Identity
    /// - Parameters:
    ///   - message: The string to sign
    ///   - identityId: ID of the Identity to use
    /// - Returns: Base64-encoded signature string
    func signMessage(_ message: String, withIdentityId identityId: UUID) throws -> String {
        // Retrieve the private key
        let privateKeyData = try getPrivateKey(id: identityId)

        // Convert private key to P256.Signing.PrivateKey
        let privateKey = try P256.Signing.PrivateKey(rawRepresentation: privateKeyData)

        // Convert message to Data
        guard let messageData = message.data(using: .utf8) else {
            throw KeychainError.invalidData
        }

        // Generate signature
        let signature = try privateKey.signature(for: messageData)

        // Return Base64-encoded DER representation (for server compatibility)
        return signature.derRepresentation.base64EncodedString()
    }
    
    /// Core signature verification logic (private)
    private func verifySignatureData(_ signatureData: Data, for messageData: Data, withPublicKey publicKeyData: Data) throws -> Bool {
        let publicKey = try P256.Signing.PublicKey(x963Representation: publicKeyData)
        let signatureObject = try P256.Signing.ECDSASignature(derRepresentation: signatureData)
        return publicKey.isValidSignature(signatureObject, for: messageData)
    }
    
    /// Verify a signature (public key provided directly)
    /// - Parameters:
    ///   - signature: Base64-encoded signature string
    ///   - message: The string that was signed
    ///   - publicKey: Public key to use for verification (Data in x963Representation format)
    /// - Returns: true if the signature is valid
    func verifySignature(_ signature: String, for message: String, withPublicKey publicKey: Data) throws -> Bool {
        // Base64-decode to get signature data
        guard let signatureData = Data(base64Encoded: signature) else {
            throw KeychainError.invalidData
        }
        // Convert message to Data
        guard let messageData = message.data(using: .utf8) else {
            throw KeychainError.invalidData
        }
        return try verifySignatureData(signatureData, for: messageData, withPublicKey: publicKey)
    }
    
    /// Verify a signature (public key retrieved from Identity ID)
    /// - Parameters:
    ///   - signature: Base64-encoded signature string
    ///   - message: The string that was signed
    ///   - identityId: ID of the Identity to use for verification
    /// - Returns: true if the signature is valid
    func verifySignature(_ signature: String, for message: String, withIdentityId identityId: UUID) throws -> Bool {
        // Retrieve public key from metadata
        let metadata = try getIdentityMetadata(id: identityId)
        return try verifySignature(signature, for: message, withPublicKey: metadata.publicKey)
    }
    
    /// Verify a signature (using a Base64-encoded public key string)
    /// - Parameters:
    ///   - signature: Base64-encoded signature string
    ///   - message: The string that was signed
    ///   - publicKeyString: Base64-encoded public key string (x963Representation format)
    /// - Returns: true if the signature is valid
    func verifySignature(_ signature: String, for message: String, withPublicKeyString publicKeyString: String) throws -> Bool {
        // Base64-decode to get public key Data
        guard let publicKeyData = Data(base64Encoded: publicKeyString) else {
            throw KeychainError.invalidData
        }
        return try verifySignature(signature, for: message, withPublicKey: publicKeyData)
    }
}

extension KeychainRepositoryImpl {
    func migrateKey(id: UUID) throws {
        /// Retrieve old Identity and private key
        let oldMetadata = try getIdentity(id: id)
        let oldPrivateKey = try getPrivateKey(id: id)

        // Derive public key from private key (using P256 signing key)
        let key = try P256.Signing.PrivateKey(rawRepresentation: oldPrivateKey)
        // Save in x963Representation format (for server compatibility)
        let oldPublicKey = key.publicKey.x963Representation


        try deleteIdentityKey(id: id)

        try saveIdentityKey(
            .init(
                id: oldMetadata.id,
                nickname: oldMetadata.nickname,
                privateKey: oldPrivateKey,
                publicKey: oldPublicKey
            )
        )
    }
}
