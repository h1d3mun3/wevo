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
private struct IdentityKeyChainItem {
    let id: UUID
    let nickname: String
    let privateKey: Data
    let publicKey: Data
}

/// メタデータのみ
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
    func getPrivateKey(id: UUID, context: LAContext?) throws -> Data
    func updateNickname(id: UUID, newNickname: String) throws
    func deleteIdentityKey(id: UUID) throws
    func deleteAllIdentityKeys() throws
    func migrateKey(id: UUID) throws
    func signMessage(_ message: String, withIdentityId identityId: UUID, context: LAContext?) throws -> String
    func verifySignature(_ signature: String, for message: String, withPublicKeyString publicKeyString: String) throws -> Bool
}

final class KeychainRepositoryImpl: KeychainRepository {
    private let serviceMetadata = "com.wevo.identitykeys.metadata"
    private let servicePrivateKey = "com.wevo.identitykeys.privatekey"
    
    init() {}
    
    // MARK: - Save
    
    /// 新しいIdentityを作成して保存
    func createIdentity(id: UUID, nickname: String, privateKey: Data) throws {
        // 秘密鍵から公開鍵を導出（P256署名鍵を使用）
        let key = try P256.Signing.PrivateKey(rawRepresentation: privateKey)
        // x963Representation形式で保存（サーバーと互換性を持たせるため）
        let publicKey = key.publicKey.x963Representation
        
        let item = IdentityKeyChainItem(
            id: id,
            nickname: nickname,
            privateKey: privateKey,
            publicKey: publicKey
        )
        try saveIdentityKey(item)
    }

    /// IdentityKeyを保存
    private func saveIdentityKey(_ item: IdentityKeyChainItem) throws {
        try saveIdentityMetadata(item)
        try savePrivateKey(item)
    }

    /// IdentityKeyのメタデータを保存
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
    
    /// 秘密鍵を保存
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
    
    /// すべてのIdentityメタデータを取得
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
    
    /// すべてのIdentityを取得
    func getAllIdentities() throws -> [Identity] {
        let metadataList = try getAllIdentityMetadata()
        return metadataList.map { metadata in
            Identity(id: metadata.id, nickname: metadata.nickname, publicKey: metadata.publicKey.base64EncodedString())
        }
    }
    
    /// 特定のIDのメタデータを取得
    fileprivate func getIdentityMetadata(id: UUID) throws -> IdentityMetadataKeychainItem {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceMetadata,
            kSecAttrAccount as String: id.uuidString,
            kSecReturnData as String: kCFBooleanTrue as Any, // 明示的にCFBoolean
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecAttrSynchronizable as String: kSecAttrSynchronizableAny // キャストを確認
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

    /// 秘密鍵を取得
    func getPrivateKey(id: UUID, context: LAContext? = nil) throws -> Data {
        let authContext = context ?? LAContext()
        authContext.localizedReason = "Authentication is required to access the private key"
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: servicePrivateKey,
            kSecAttrAccount as String: id.uuidString,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecUseAuthenticationContext as String: authContext,
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
    
    /// 特定のIDのIdentityKeyを取得
    private func getIdentityKey(id: UUID, context: LAContext? = nil) throws -> IdentityKeyChainItem {
        let metadata = try getIdentityMetadata(id: id)
        let privateKey = try getPrivateKey(id: id, context: context)
        
        return IdentityKeyChainItem(
            id: metadata.id,
            nickname: metadata.nickname,
            privateKey: privateKey,
            publicKey: metadata.publicKey
        )
    }

    // MARK: - Update
    
    /// IdentityKeyのニックネームを更新
    func updateNickname(id: UUID, newNickname: String) throws {
        let existingMetadata = try getIdentityMetadata(id: id)

        let encoder = JSONEncoder()
        let updatedMetadata = IdentityMetadataKeychainItem(
            id: id,
            nickname: newNickname,
            publicKey: existingMetadata.publicKey
        )
        let metadataData = try encoder.encode(updatedMetadata)

        // 💡 検索条件に同期フラグを追加
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceMetadata,
            kSecAttrAccount as String: id.uuidString,
            kSecAttrSynchronizable as String: kSecAttrSynchronizableAny // これが必要！
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
            kSecAttrAccount as String: id.uuidString,
            kSecAttrSynchronizable as String: kSecAttrSynchronizableAny
        ]
        
        let metadataStatus = SecItemDelete(metadataQuery as CFDictionary)
        
        // 秘密鍵を削除
        let privateKeyQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: servicePrivateKey,
            kSecAttrAccount as String: id.uuidString,
            kSecAttrSynchronizable as String: kSecAttrSynchronizableAny
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
// MARK: - Signing Extension

extension KeychainRepositoryImpl {
    
    /// 指定されたIdentityの秘密鍵でStringに署名する
    /// - Parameters:
    ///   - message: 署名対象の文字列
    ///   - identityId: 使用するIdentityのID
    ///   - context: オプションのLAContext（複数回の署名操作で認証を再利用する場合）
    /// - Returns: Base64エンコードされた署名文字列
    func signMessage(_ message: String, withIdentityId identityId: UUID, context: LAContext? = nil) throws -> String {
        // 秘密鍵を取得
        let privateKeyData = try getPrivateKey(id: identityId, context: context)
        
        // 秘密鍵をP256.Signing.PrivateKeyに変換
        let privateKey = try P256.Signing.PrivateKey(rawRepresentation: privateKeyData)
        
        // メッセージをDataに変換
        guard let messageData = message.data(using: .utf8) else {
            throw KeychainError.invalidData
        }
        
        // 署名を生成
        let signature = try privateKey.signature(for: messageData)
        
        // DER形式でBase64エンコードして返す（サーバーと互換性を持たせるため）
        return signature.derRepresentation.base64EncodedString()
    }
    
    /// 署名の検証のコア処理（プライベート）
    private func verifySignatureData(_ signatureData: Data, for messageData: Data, withPublicKey publicKeyData: Data) throws -> Bool {
        let publicKey = try P256.Signing.PublicKey(x963Representation: publicKeyData)
        let signatureObject = try P256.Signing.ECDSASignature(derRepresentation: signatureData)
        return publicKey.isValidSignature(signatureObject, for: messageData)
    }
    
    /// 署名を検証する（公開鍵を直接指定）
    /// - Parameters:
    ///   - signature: Base64エンコードされた署名文字列
    ///   - message: 署名対象の文字列
    ///   - publicKey: 検証に使用する公開鍵（x963Representation形式のData）
    /// - Returns: 署名が有効な場合はtrue
    func verifySignature(_ signature: String, for message: String, withPublicKey publicKey: Data) throws -> Bool {
        // Base64デコードして署名データに変換
        guard let signatureData = Data(base64Encoded: signature) else {
            throw KeychainError.invalidData
        }
        // メッセージをDataに変換
        guard let messageData = message.data(using: .utf8) else {
            throw KeychainError.invalidData
        }
        return try verifySignatureData(signatureData, for: messageData, withPublicKey: publicKey)
    }
    
    /// 署名を検証する（IdentityIdから公開鍵を取得）
    /// - Parameters:
    ///   - signature: Base64エンコードされた署名文字列
    ///   - message: 署名対象の文字列
    ///   - identityId: 検証に使用するIdentityのID
    /// - Returns: 署名が有効な場合はtrue
    func verifySignature(_ signature: String, for message: String, withIdentityId identityId: UUID) throws -> Bool {
        // メタデータから公開鍵を取得
        let metadata = try getIdentityMetadata(id: identityId)
        return try verifySignature(signature, for: message, withPublicKey: metadata.publicKey)
    }
    
    /// 署名を検証する（Base64エンコードされた公開鍵文字列を使用）
    /// - Parameters:
    ///   - signature: Base64エンコードされた署名文字列
    ///   - message: 署名対象の文字列
    ///   - publicKeyString: Base64エンコードされた公開鍵文字列（x963Representation形式）
    /// - Returns: 署名が有効な場合はtrue
    func verifySignature(_ signature: String, for message: String, withPublicKeyString publicKeyString: String) throws -> Bool {
        // Base64デコードして公開鍵Dataに変換
        guard let publicKeyData = Data(base64Encoded: publicKeyString) else {
            throw KeychainError.invalidData
        }
        return try verifySignature(signature, for: message, withPublicKey: publicKeyData)
    }
}

extension KeychainRepositoryImpl {
    func migrateKey(id: UUID) throws {
        /// 古いIdentityと秘密鍵を取得
        let oldMetadata = try getIdentity(id: id)
        let oldPrivateKey = try getPrivateKey(id: id)

        // 秘密鍵から公開鍵を導出（P256署名鍵を使用）
        let key = try P256.Signing.PrivateKey(rawRepresentation: oldPrivateKey)
        // x963Representation形式で保存（サーバーと互換性を持たせるため）
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
