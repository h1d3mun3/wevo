//
//  IdentityEncryptedExport.swift
//  Wevo
//

import Foundation

/// Passphrase-encrypted `.wevo-identity` export envelope (format version 1).
///
/// Metadata (`id`, `nickname`, `publicKey`) is stored in cleartext — none of it is secret, and it
/// lets the import screen show a preview before the passphrase is entered. Only the P-256 private
/// key is encrypted: it is sealed with AES-GCM under a key derived from the user's passphrase via
/// PBKDF2-HMAC-SHA256 (see `IdentityExportCrypto`). This replaces the previous plaintext export,
/// which wrote the raw private key to disk with no protection.
struct IdentityEncryptedExport: Codable {
    let version: Int
    let id: UUID
    let nickname: String
    let publicKey: String
    let exportedAt: Date
    let kdf: String
    let iterations: Int
    let salt: String      // base64
    let sealed: String    // base64 of AES-GCM combined box (nonce + ciphertext + tag)

    static let currentVersion = 1
    static let kdfName = "PBKDF2-SHA256"
}
