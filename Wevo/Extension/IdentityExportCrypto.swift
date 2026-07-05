//
//  IdentityExportCrypto.swift
//  Wevo
//

import Foundation
import CryptoKit
import CommonCrypto

/// Passphrase-based encryption for identity exports: PBKDF2-HMAC-SHA256 key derivation + AES-GCM.
enum IdentityExportCrypto {
    /// PBKDF2 iteration count (OWASP-recommended floor for PBKDF2-HMAC-SHA256).
    static let iterations = 210_000
    static let saltLength = 16

    enum CryptoError: Error, LocalizedError {
        case emptyPassphrase
        case keyDerivationFailed
        case sealFailed

        var errorDescription: String? {
            switch self {
            case .emptyPassphrase: return "A passphrase is required."
            case .keyDerivationFailed: return "Failed to derive the encryption key."
            case .sealFailed: return "Failed to encrypt the identity."
            }
        }
    }

    /// 16 cryptographically random bytes (from CryptoKit's CSPRNG).
    static func randomSalt() -> Data {
        SymmetricKey(size: .bits128).withUnsafeBytes { Data($0) }
    }

    /// Derives a 256-bit AES key from `passphrase` using PBKDF2-HMAC-SHA256.
    static func deriveKey(passphrase: String, salt: Data, iterations: Int) throws -> SymmetricKey {
        guard !passphrase.isEmpty else { throw CryptoError.emptyPassphrase }
        let passData = Data(passphrase.utf8)
        var derived = [UInt8](repeating: 0, count: 32)
        let status: Int32 = passData.withUnsafeBytes { rawPass in
            salt.withUnsafeBytes { rawSalt in
                CCKeyDerivationPBKDF(
                    CCPBKDFAlgorithm(kCCPBKDF2),
                    rawPass.bindMemory(to: CChar.self).baseAddress, passData.count,
                    rawSalt.bindMemory(to: UInt8.self).baseAddress, salt.count,
                    CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256),
                    UInt32(iterations),
                    &derived, derived.count
                )
            }
        }
        guard status == kCCSuccess else { throw CryptoError.keyDerivationFailed }
        return SymmetricKey(data: Data(derived))
    }

    /// Encrypts `plaintext` with a passphrase. Returns (salt, sealedCombined) for the envelope.
    static func encrypt(_ plaintext: Data, passphrase: String) throws -> (salt: Data, sealed: Data) {
        let salt = randomSalt()
        let key = try deriveKey(passphrase: passphrase, salt: salt, iterations: iterations)
        let box = try AES.GCM.seal(plaintext, using: key)
        guard let combined = box.combined else { throw CryptoError.sealFailed }
        return (salt, combined)
    }

    /// Decrypts a sealed box produced by `encrypt`. Throws on a wrong passphrase or tampering
    /// (AES-GCM authentication failure).
    static func decrypt(sealed: Data, salt: Data, iterations: Int, passphrase: String) throws -> Data {
        let key = try deriveKey(passphrase: passphrase, salt: salt, iterations: iterations)
        let box = try AES.GCM.SealedBox(combined: sealed)
        return try AES.GCM.open(box, using: key)
    }
}
