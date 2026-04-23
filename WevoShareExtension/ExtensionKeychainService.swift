//
//  ExtensionKeychainService.swift
//  WevoShareExtension
//

import Foundation
import Security
import CryptoKit

// MARK: - Domain

struct ExtensionIdentity {
    let id: UUID
    let nickname: String
    let publicKeyJWK: String
}

enum KeychainAccessError: Error, LocalizedError {
    case identityNotFound
    case invalidData
    case keychainError(OSStatus)

    var errorDescription: String? {
        switch self {
        case .identityNotFound: return "Identity not found"
        case .invalidData: return "Invalid data"
        case .keychainError(let s): return "Keychain error: \(s)"
        }
    }
}

// MARK: - Protocols

protocol IdentitySigningService {
    func getAllIdentities() throws -> [ExtensionIdentity]
    func signText(_ text: String, withIdentityId id: UUID) throws -> String
    func getPublicKeyRawBase64(forIdentityId id: UUID) throws -> String
}

protocol SignatureVerifyingService {
    func verifyText(_ text: String, publicKeyBase64: String, signatureBase64: String) throws -> Bool
}

// MARK: - Service

final class ExtensionKeychainService {
    private let serviceMetadata = "com.wevo.identitykeys.metadata"
    private let servicePrivateKey = "com.wevo.identitykeys.privatekey"

    // MARK: Read

    func getAllIdentities() throws -> [ExtensionIdentity] {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceMetadata,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitAll,
            kSecAttrSynchronizable as String: kSecAttrSynchronizableAny
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return [] }
        guard status == errSecSuccess else { throw KeychainAccessError.keychainError(status) }
        guard let dataArray = result as? [Data] else { throw KeychainAccessError.invalidData }

        struct MetadataItem: Decodable {
            let id: UUID
            let nickname: String
            let publicKey: String
        }
        return dataArray.compactMap { data in
            guard let item = try? JSONDecoder().decode(MetadataItem.self, from: data) else { return nil }
            return ExtensionIdentity(id: item.id, nickname: item.nickname, publicKeyJWK: item.publicKey)
        }
    }

    // MARK: Sign

    func signText(_ text: String, withIdentityId id: UUID) throws -> String {
        let rawKey = try getPrivateKey(id: id)
        let privateKey = try P256.Signing.PrivateKey(rawRepresentation: rawKey)
        guard let data = text.data(using: .utf8) else { throw KeychainAccessError.invalidData }
        let sig = try privateKey.signature(for: data)
        return sig.derRepresentation.base64EncodedString()
    }

    func getPublicKeyRawBase64(forIdentityId id: UUID) throws -> String {
        let identities = try getAllIdentities()
        guard let identity = identities.first(where: { $0.id == id }) else {
            throw KeychainAccessError.identityNotFound
        }
        guard let pk = P256.Signing.PublicKey(jwkString: identity.publicKeyJWK) else {
            throw KeychainAccessError.invalidData
        }
        return pk.rawRepresentation.base64EncodedString()
    }

    // MARK: Verify

    func verifyText(_ text: String, publicKeyBase64: String, signatureBase64: String) throws -> Bool {
        guard let sigData = Data(base64Encoded: signatureBase64),
              let msgData = text.data(using: .utf8),
              let pkData = Data(base64Encoded: publicKeyBase64),
              pkData.count == 64
        else { throw KeychainAccessError.invalidData }

        let pk = try P256.Signing.PublicKey(rawRepresentation: pkData)
        let sig = try P256.Signing.ECDSASignature(derRepresentation: sigData)
        return pk.isValidSignature(sig, for: msgData)
    }

    // MARK: Signer Check

    /// Returns true if the public key matches one of your own identities in Keychain.
    func isSelfPublicKey(rawBase64: String) throws -> Bool {
        let identities = try getAllIdentities()
        return identities.contains { identity in
            guard let pk = P256.Signing.PublicKey(jwkString: identity.publicKeyJWK) else { return false }
            return pk.rawRepresentation.base64EncodedString() == rawBase64
        }
    }

    // MARK: Fingerprint

    static func fingerprint(rawPublicKeyBase64: String) -> String {
        guard let data = Data(base64Encoded: rawPublicKeyBase64), data.count == 64 else {
            return String(rawPublicKeyBase64.prefix(16)) + "..."
        }
        let hash = SHA256.hash(data: data)
        return Array(hash.prefix(8))
            .map { String(format: "%02X", $0) }
            .joined(separator: ":")
    }

    static func fingerprint(jwkPublicKey: String) -> String {
        guard let pk = P256.Signing.PublicKey(jwkString: jwkPublicKey) else { return "---" }
        let hash = SHA256.hash(data: pk.rawRepresentation)
        return Array(hash.prefix(8))
            .map { String(format: "%02X", $0) }
            .joined(separator: ":")
    }

    // MARK: Private

    private func getPrivateKey(id: UUID) throws -> Data {
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
            if status == errSecItemNotFound { throw KeychainAccessError.identityNotFound }
            throw KeychainAccessError.keychainError(status)
        }
        guard let data = result as? Data else { throw KeychainAccessError.invalidData }

        struct PrivateKeyData: Decodable { let privateKey: Data }
        let decoded = try JSONDecoder().decode(PrivateKeyData.self, from: data)
        return decoded.privateKey
    }
}

// MARK: - CryptoKit helpers (scoped to this module)

extension P256.Signing.PublicKey {
    init?(jwkString: String) {
        struct JWK: Decodable { let x, y: String }
        guard let jsonData = jwkString.data(using: .utf8),
              let jwk = try? JSONDecoder().decode(JWK.self, from: jsonData),
              let xData = Data(base64url: jwk.x),
              let yData = Data(base64url: jwk.y),
              xData.count == 32, yData.count == 32,
              let key = try? P256.Signing.PublicKey(rawRepresentation: xData + yData)
        else { return nil }
        self = key
    }
}

extension Data {
    init?(base64url string: String) {
        var s = string
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let rem = s.count % 4
        if rem > 0 { s += String(repeating: "=", count: 4 - rem) }
        self.init(base64Encoded: s)
    }
}

// MARK: - Protocol Conformance

extension ExtensionKeychainService: SelfKeyChecking {}
extension ExtensionKeychainService: IdentitySigningService {}
extension ExtensionKeychainService: SignatureVerifyingService {}
