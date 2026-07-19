//
//  IdentityExportCrypto.swift
//  Wevo
//

import Foundation
import CryptoKit
import CommonCrypto

/// Passphrase-based encryption for identity exports: PBKDF2-HMAC-SHA256 key derivation + AES-GCM.
enum IdentityExportCrypto {
    /// PBKDF2 iteration count for NEW exports (OWASP-recommended floor for PBKDF2-HMAC-SHA256).
    /// Note: 210,000 is OWASP's HMAC-*SHA512* figure; the HMAC-SHA256 floor is 600,000. Since the
    /// export envelope records the iteration count used (`IdentityEncryptedExport.iterations`) and
    /// `decrypt` derives the key with that stored value, raising this only affects newly-written
    /// files — older 210,000-iteration exports still decrypt (their count is read from the file and
    /// is within `minIterations...maxIterations`).
    static let iterations = 600_000
    static let saltLength = 16
    /// Minimum passphrase length for NEW exports. The private signing key is the crown jewel and a
    /// leaked `.wevo-identity` can be brute-forced offline, so short passphrases are rejected;
    /// iteration count alone cannot compensate for a low-entropy passphrase.
    static let minPassphraseLength = 12
    /// Accepted iteration range on import. Bounds untrusted envelope values so they can never
    /// overflow the UInt32 conversion (crash) or make PBKDF2 run for an abusive amount of time.
    static let minIterations = 100_000
    static let maxIterations = 2_000_000

    enum CryptoError: Error, LocalizedError {
        case emptyPassphrase
        case passphraseTooShort
        case keyDerivationFailed
        case sealFailed

        var errorDescription: String? {
            switch self {
            case .emptyPassphrase: return "A passphrase is required."
            case .passphraseTooShort: return "Passphrase must be at least \(IdentityExportCrypto.minPassphraseLength) characters."
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
        // Non-trapping conversion: a negative or out-of-UInt32-range value (from an untrusted
        // envelope) surfaces as a catchable error instead of a fatal runtime trap.
        guard let rounds = UInt32(exactly: iterations), rounds >= 1 else {
            throw CryptoError.keyDerivationFailed
        }
        let passData = Data(passphrase.utf8)
        var derived = [UInt8](repeating: 0, count: 32)
        let status: Int32 = passData.withUnsafeBytes { rawPass in
            salt.withUnsafeBytes { rawSalt in
                CCKeyDerivationPBKDF(
                    CCPBKDFAlgorithm(kCCPBKDF2),
                    rawPass.bindMemory(to: CChar.self).baseAddress, passData.count,
                    rawSalt.bindMemory(to: UInt8.self).baseAddress, salt.count,
                    CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256),
                    rounds,
                    &derived, derived.count
                )
            }
        }
        guard status == kCCSuccess else { throw CryptoError.keyDerivationFailed }
        return SymmetricKey(data: Data(derived))
    }

    /// Encrypts `plaintext` with a passphrase. Returns (salt, sealedCombined) for the envelope.
    static func encrypt(_ plaintext: Data, passphrase: String) throws -> (salt: Data, sealed: Data) {
        guard passphrase.count >= minPassphraseLength else { throw CryptoError.passphraseTooShort }
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
