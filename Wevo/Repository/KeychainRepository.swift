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
    let publicKey: String // JWK string
}

/// Metadata only
private struct IdentityMetadataKeychainItem: Codable {
    let id: UUID
    let nickname: String
    let publicKey: String // JWK string
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
        // Save in JWK format
        let publicKey = key.publicKey.jwkString
        
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
            Identity(id: metadata.id, nickname: metadata.nickname, publicKey: metadata.publicKey)
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

        return Identity(id: metadata.id, nickname: metadata.nickname, publicKey: metadata.publicKey)
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
    private func verifyCore(_ signatureData: Data, for messageData: Data, jwkString: String) throws -> Bool {
        guard let publicKey = P256.Signing.PublicKey.fromJWKString(jwkString) else {
            throw KeychainError.invalidData
        }
        let signatureObject = try P256.Signing.ECDSASignature(derRepresentation: signatureData)
        return publicKey.isValidSignature(signatureObject, for: messageData)
    }

    /// Verify a signature (public key retrieved from Identity ID)
    func verifySignature(_ signature: String, for message: String, withIdentityId identityId: UUID) throws -> Bool {
        let metadata = try getIdentityMetadata(id: identityId)
        return try verifySignature(signature, for: message, withPublicKeyString: metadata.publicKey)
    }

    /// Verify a signature (using a JWK public key string)
    func verifySignature(_ signature: String, for message: String, withPublicKeyString publicKeyString: String) throws -> Bool {
        guard let signatureData = Data(base64Encoded: signature) else {
            throw KeychainError.invalidData
        }
        guard let messageData = message.data(using: .utf8) else {
            throw KeychainError.invalidData
        }
        return try verifyCore(signatureData, for: messageData, jwkString: publicKeyString)
    }
}

extension KeychainRepositoryImpl {
    func migrateKey(id: UUID) throws {
        let oldMetadata = try getIdentityMetadata(id: id)

        // Read raw bytes from Keychain without JSON decoding
        let storedData = try readRawKeychainData(service: servicePrivateKey, account: id.uuidString)

        // Convert to raw representation (32 bytes) regardless of X963 or raw format
        let rawPrivateKey = try resolveToRawPrivateKey(storedData)

        // Re-derive JWK public key from raw representation
        let key = try P256.Signing.PrivateKey(rawRepresentation: rawPrivateKey)
        let newPublicKey = key.publicKey.jwkString

        try deleteIdentityKey(id: id)
        try saveIdentityKey(
            .init(
                id: oldMetadata.id,
                nickname: oldMetadata.nickname,
                privateKey: rawPrivateKey,
                publicKey: newPublicKey
            )
        )
    }

    /// Reads raw bytes from Keychain without JSON decoding
    private func readRawKeychainData(service: String, account: String) throws -> Data {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecAttrSynchronizable as String: kSecAttrSynchronizableAny
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess else {
            if status == errSecItemNotFound { throw KeychainError.itemNotFound }
            throw KeychainError.unhandledError(status: status)
        }
        guard let data = result as? Data else { throw KeychainError.invalidData }
        return data
    }

    /// Extracts the raw representation (32 bytes) from stored data in any format (X963, raw, JSON-wrapped)
    private func resolveToRawPrivateKey(_ storedData: Data) throws -> Data {
        // 1. Try JSON-wrapped format (handles both old and new formats)
        if let wrapper = try? JSONDecoder().decode(PrivateKeyData.self, from: storedData) {
            // 1a. Inner data is already raw (32 bytes)
            if (try? P256.Signing.PrivateKey(rawRepresentation: wrapper.privateKey)) != nil {
                return wrapper.privateKey
            }
            // 1b. Inner data is X963 (97 bytes)
            if let key = try? P256.Signing.PrivateKey(x963Representation: wrapper.privateKey) {
                return key.rawRepresentation
            }
        }

        // 2. Plain X963 bytes without JSON wrapper (legacy format)
        if let key = try? P256.Signing.PrivateKey(x963Representation: storedData) {
            return key.rawRepresentation
        }

        // 3. Plain raw bytes without JSON wrapper
        if (try? P256.Signing.PrivateKey(rawRepresentation: storedData)) != nil {
            return storedData
        }

        throw KeychainError.invalidData
    }
}

// MARK: - JWK Helpers

private struct JWKPublicKeyFields: Decodable {
    let x: String
    let y: String
}

extension P256.Signing.PublicKey {
    /// P-256公開鍵をJWK JSON文字列に変換する
    var jwkString: String {
        let raw = rawRepresentation // 64バイト: x (32) + y (32)
        let x = raw.prefix(32).base64URLEncodedString()
        let y = raw.suffix(32).base64URLEncodedString()
        return #"{"crv":"P-256","kty":"EC","x":"\#(x)","y":"\#(y)"}"#
    }

    /// JWK JSON文字列からP-256公開鍵を生成する
    static func fromJWKString(_ string: String) -> P256.Signing.PublicKey? {
        guard let jsonData = string.data(using: .utf8),
              let jwk = try? JSONDecoder().decode(JWKPublicKeyFields.self, from: jsonData),
              let xData = Data(base64URLEncoded: jwk.x),
              let yData = Data(base64URLEncoded: jwk.y),
              xData.count == 32, yData.count == 32 else { return nil }
        return try? P256.Signing.PublicKey(rawRepresentation: xData + yData)
    }
}

extension Data {
    /// Base64URL エンコード ('+' → '-', '/' → '_', パディングなし)
    func base64URLEncodedString() -> String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    /// Base64URL デコード ('-' → '+', '_' → '/', パディング補完)
    init?(base64URLEncoded string: String) {
        var s = string
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let remainder = s.count % 4
        if remainder > 0 { s += String(repeating: "=", count: 4 - remainder) }
        self.init(base64Encoded: s)
    }
}
