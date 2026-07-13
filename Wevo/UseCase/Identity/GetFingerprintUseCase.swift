//
//  GetFingerprintUseCase.swift
//  Wevo
//

import Foundation
import CryptoKit

protocol GetFingerprintUseCase {
    func execute(jwkPublicKey: String) -> String
}

struct GetFingerprintUseCaseImpl: GetFingerprintUseCase {
    func execute(jwkPublicKey: String) -> String {
        guard let key = P256.Signing.PublicKey.fromJWKString(jwkPublicKey) else {
            return String(jwkPublicKey.prefix(16)) + "..."
        }
        // First 16 bytes (128 bits) of the SHA-256 — enough to make a collision/second-preimage
        // infeasible for a spoofed contact key. (8 bytes / 64 bits was brute-forceable.)
        let hash = SHA256.hash(data: key.rawRepresentation)
        return Array(hash.prefix(16))
            .map { String(format: "%02X", $0) }
            .joined(separator: ":")
    }
}
