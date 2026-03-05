//
//  KeychainRepository.swift
//  Wevo
//
//  Created by hidemune on 3/5/26.
//

import Foundation
import Security
import CryptoKit

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

enum KeychainError: Error {
    case duplicateItem
    case itemNotFound
    case invalidData
    case unhandledError(status: OSStatus)
}

final class KeychainRepository {
    
    static let shared = KeychainRepository()
    
    private let service = "com.wevo.identitykeys"
    
    private init() {}
    
    // MARK: - Save
    
    /// IdentityKeyをKeychainに保存
    func saveIdentityKey(_ item: IdentityKeyChainItem) throws {
        // 保存するデータをエンコード（公開鍵は保存しない）
        let encoder = JSONEncoder()
        let keyData = try encoder.encode(KeychainData(
            id: item.id,
            nickname: item.nickname,
            privateKey: item.privateKey
        ))
        
        // Keychainに保存するクエリ
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: item.id.uuidString,
            kSecValueData as String: keyData,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
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
    
    /// 特定のIDのIdentityKeyを取得
    func getIdentityKey(id: UUID) throws -> IdentityKeyChainItem {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
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
        let keychainData = try decoder.decode(KeychainData.self, from: data)
        
        return IdentityKeyChainItem(
            id: keychainData.id,
            nickname: keychainData.nickname,
            privateKey: keychainData.privateKey
        )
    }
    
    /// すべてのIdentityKeyを取得
    func getAllIdentityKeys() throws -> [IdentityKeyChainItem] {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
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
            let keychainData = try decoder.decode(KeychainData.self, from: data)
            return IdentityKeyChainItem(
                id: keychainData.id,
                nickname: keychainData.nickname,
                privateKey: keychainData.privateKey
            )
        }
    }
    
    // MARK: - Update
    
    /// IdentityKeyのニックネームを更新
    func updateNickname(id: UUID, newNickname: String) throws {
        // 既存のアイテムを取得
        let existingItem = try getIdentityKey(id: id)
        
        // 新しいデータを作成
        let encoder = JSONEncoder()
        let updatedData = try encoder.encode(KeychainData(
            id: existingItem.id,
            nickname: newNickname,
            privateKey: existingItem.privateKey
        ))
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: id.uuidString
        ]
        
        let attributesToUpdate: [String: Any] = [
            kSecValueData as String: updatedData
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
    
    /// 特定のIDのIdentityKeyを削除
    func deleteIdentityKey(id: UUID) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: id.uuidString
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unhandledError(status: status)
        }
    }
    
    /// すべてのIdentityKeyを削除
    func deleteAllIdentityKeys() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unhandledError(status: status)
        }
    }
}

// MARK: - Private Helper

private struct KeychainData: Codable {
    let id: UUID
    let nickname: String
    let privateKey: Data
}
