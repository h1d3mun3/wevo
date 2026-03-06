//
//  KeychainRepository.swift
//  Wevo
//
//  Created by hidemune on 3/5/26.
//

import Foundation
import Security
import CryptoKit
import LocalAuthentication

/// Keychainに保存するIdentityKeyの情報
struct IdentityKeyChainItem {
    let id: UUID
    let nickname: String
    let privateKey: Data
    
    /// 秘密鍵から公開鍵を導出
    var publicKey: Data {
        get throws {
            let privateKey = try Curve25519.KeyAgreement.PrivateKey(rawRepresentation: self.privateKey)
            return privateKey.publicKey.rawRepresentation
        }
    }
}

/// メタデータのみ（認証不要でアクセス可能）
struct IdentityMetadataKeychainItem: Codable {
    let id: UUID
    let nickname: String
}

enum KeychainError: Error {
    case duplicateItem
    case itemNotFound
    case invalidData
    case unhandledError(status: OSStatus)
    case biometricAuthFailed
    case accessControlCreationFailed
}

final class KeychainRepository {
    
    static let shared = KeychainRepository()
    
    private let serviceMetadata = "com.wevo.identitykeys.metadata"
    private let servicePrivateKey = "com.wevo.identitykeys.privatekey"
    
    private init() {}
    
    // MARK: - Save
    
    /// IdentityKeyのメタデータを保存（認証不要）
    func saveIdentityMetadata(_ item: IdentityKeyChainItem) throws {
        let encoder = JSONEncoder()
        let metadata = IdentityMetadataKeychainItem(id: item.id, nickname: item.nickname)
        let metadataData = try encoder.encode(metadata)
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceMetadata,
            kSecAttrAccount as String: item.id.uuidString,
            kSecValueData as String: metadataData,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked,
            kSecAttrSynchronizable as String: false
        ]
        
        let status = SecItemAdd(query as CFDictionary, nil)
        
        guard status != errSecDuplicateItem else {
            throw KeychainError.duplicateItem
        }
        
        guard status == errSecSuccess else {
            throw KeychainError.unhandledError(status: status)
        }
    }
    
    /// 秘密鍵を保存（生体認証必須）
    func savePrivateKey(_ item: IdentityKeyChainItem) throws {
        // アクセス制御の作成：生体認証またはパスコード必須
        guard let access = SecAccessControlCreateWithFlags(
            nil,
            kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            .userPresence, // Face ID / Touch ID / パスコード
            nil
        ) else {
            throw KeychainError.accessControlCreationFailed
        }
        
        let encoder = JSONEncoder()
        let privateKeyData = try encoder.encode(PrivateKeyData(privateKey: item.privateKey))
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: servicePrivateKey,
            kSecAttrAccount as String: item.id.uuidString,
            kSecValueData as String: privateKeyData,
            kSecAttrAccessControl as String: access,
            kSecAttrSynchronizable as String: false // 生体認証使用時は同期不可
        ]
        
        let status = SecItemAdd(query as CFDictionary, nil)
        
        guard status != errSecDuplicateItem else {
            throw KeychainError.duplicateItem
        }
        
        guard status == errSecSuccess else {
            throw KeychainError.unhandledError(status: status)
        }
    }
    
    /// IdentityKeyを保存（メタデータと秘密鍵の両方）
    func saveIdentityKey(_ item: IdentityKeyChainItem) throws {
        try saveIdentityMetadata(item)
        try savePrivateKey(item)
    }
    
    // MARK: - Retrieve
    
    /// すべてのIdentityメタデータを取得（認証不要）
    func getAllIdentityMetadata() throws -> [IdentityMetadataKeychainItem] {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceMetadata,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitAll
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
    
    /// すべてのIdentityを取得（認証不要、ドメインモデルを返す）
    func getAllIdentities() throws -> [Identity] {
        let metadataList = try getAllIdentityMetadata()
        return KeychainItemConverter.toIdentities(from: metadataList)
    }
    
    /// 特定のIDのメタデータを取得（認証不要）
    func getIdentityMetadata(id: UUID) throws -> IdentityMetadataKeychainItem {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceMetadata,
            kSecAttrAccount as String: id.uuidString,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
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
    
    /// 秘密鍵を取得（生体認証必須）
    func getPrivateKey(id: UUID, context: LAContext? = nil) throws -> Data {
        let authContext = context ?? LAContext()
        authContext.localizedReason = "秘密鍵にアクセスするために認証が必要です"
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: servicePrivateKey,
            kSecAttrAccount as String: id.uuidString,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecUseAuthenticationContext as String: authContext
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
    
    /// 特定のIDのIdentityKeyを取得（生体認証必須）
    func getIdentityKey(id: UUID, context: LAContext? = nil) throws -> IdentityKeyChainItem {
        let metadata = try getIdentityMetadata(id: id)
        let privateKey = try getPrivateKey(id: id, context: context)
        
        return IdentityKeyChainItem(
            id: metadata.id,
            nickname: metadata.nickname,
            privateKey: privateKey
        )
    }
    
    /// すべてのIdentityKeyを取得（生体認証必須）
    @available(*, deprecated, message: "Use getAllIdentityMetadata() for listing, and getPrivateKey(id:) when needed")
    func getAllIdentityKeys() throws -> [IdentityKeyChainItem] {
        let metadataList = try getAllIdentityMetadata()
        return try metadataList.map { metadata in
            let privateKey = try getPrivateKey(id: metadata.id)
            return IdentityKeyChainItem(
                id: metadata.id,
                nickname: metadata.nickname,
                privateKey: privateKey
            )
        }
    }
    
    // MARK: - Update
    
    /// IdentityKeyのニックネームを更新
    func updateNickname(id: UUID, newNickname: String) throws {
        // メタデータを更新
        let encoder = JSONEncoder()
        let updatedMetadata = IdentityMetadataKeychainItem(id: id, nickname: newNickname)
        let metadataData = try encoder.encode(updatedMetadata)
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceMetadata,
            kSecAttrAccount as String: id.uuidString
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
    
    /// 特定のIDのIdentityKeyを削除（メタデータと秘密鍵の両方）
    func deleteIdentityKey(id: UUID) throws {
        // メタデータを削除
        let metadataQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceMetadata,
            kSecAttrAccount as String: id.uuidString
        ]
        
        let metadataStatus = SecItemDelete(metadataQuery as CFDictionary)
        
        // 秘密鍵を削除
        let privateKeyQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: servicePrivateKey,
            kSecAttrAccount as String: id.uuidString
        ]
        
        let privateKeyStatus = SecItemDelete(privateKeyQuery as CFDictionary)
        
        // どちらかが失敗していて、かつ「見つからない」以外のエラーなら例外を投げる
        guard (metadataStatus == errSecSuccess || metadataStatus == errSecItemNotFound) &&
              (privateKeyStatus == errSecSuccess || privateKeyStatus == errSecItemNotFound) else {
            throw KeychainError.unhandledError(status: metadataStatus)
        }
    }
    
    /// すべてのIdentityKeyを削除（メタデータと秘密鍵の両方）
    func deleteAllIdentityKeys() throws {
        // メタデータを削除
        let metadataQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceMetadata
        ]
        
        let metadataStatus = SecItemDelete(metadataQuery as CFDictionary)
        
        // 秘密鍵を削除
        let privateKeyQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: servicePrivateKey
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
