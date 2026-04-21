//
//  GetFingerprintUseCase.swift
//  Wevo
//

import CryptoKit

protocol GetFingerprintUseCase {
    func execute(jwkPublicKey: String) -> String
}

struct GetFingerprintUseCaseImpl: GetFingerprintUseCase {
    func execute(jwkPublicKey: String) -> String {
        guard let key = P256.Signing.PublicKey.fromJWKString(jwkPublicKey) else {
            return String(jwkPublicKey.prefix(16)) + "..."
        }
        let hash = SHA256.hash(data: key.rawRepresentation)
        return Array(hash.prefix(8))
            .map { String(format: "%02X", $0) }
            .joined(separator: ":")
    }
}
