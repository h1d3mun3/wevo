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

    /// SHA256(rawRepresentation) の先頭8バイトをコロン区切り16進数で表示
    var fingerprintDisplay: String {
        guard let key = P256.Signing.PublicKey.fromJWKString(publicKey) else {
            return String(publicKey.prefix(16)) + "..."
        }
        let hash = SHA256.hash(data: key.rawRepresentation)
        return Array(hash.prefix(8))
            .map { String(format: "%02X", $0) }
            .joined(separator: ":")
    }
}
