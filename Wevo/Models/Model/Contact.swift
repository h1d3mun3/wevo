//
//  Contact.swift
//  Wevo
//
//  Created by hidemune on 3/12/26.
//

import Foundation
import CryptoKit

struct Contact: Identifiable {
    let id: UUID
    var nickname: String
    var publicKey: String // JWK format
    let createdAt: Date

    /// First 16 bytes (128 bits) of SHA256(rawRepresentation) displayed as colon-separated hex.
    /// The fingerprint is the out-of-band anchor for verifying a contact's key, so it must be wide
    /// enough that forging a key with a matching fingerprint is infeasible. 8 bytes / 64 bits was
    /// brute-forceable; this matches `Identity.fingerprintDisplay` and `GetFingerprintUseCase`.
    var fingerprintDisplay: String {
        guard let key = P256.Signing.PublicKey.fromJWKString(publicKey) else {
            return String(publicKey.prefix(16)) + "..."
        }
        let hash = SHA256.hash(data: key.rawRepresentation)
        return Array(hash.prefix(16))
            .map { String(format: "%02X", $0) }
            .joined(separator: ":")
    }

    /// Base64-encoded raw representation of the public key
    var publicKeyBase64: String? {
        guard let key = P256.Signing.PublicKey.fromJWKString(publicKey) else { return nil }
        return key.rawRepresentation.base64EncodedString()
    }
}
