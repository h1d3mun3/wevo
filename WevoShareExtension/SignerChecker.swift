//
//  SignerChecker.swift
//  WevoShareExtension
//

import Foundation

// MARK: - SignerType

enum SignerType: Equatable {
    case selfSigned
    case known
    case unknown
}

// MARK: - Protocols

protocol SelfKeyChecking {
    func isSelfPublicKey(rawBase64: String) throws -> Bool
}

protocol ContactChecking {
    func isKnownContact(rawPublicKeyBase64: String) -> Bool
}

protocol SignerResolving {
    func resolve(rawPublicKeyBase64: String) -> SignerType
}

// MARK: - Implementation

final class SignerChecker: SignerResolving {
    private let selfChecker: any SelfKeyChecking
    private let contactChecker: any ContactChecking

    init(
        selfChecker: any SelfKeyChecking = ExtensionKeychainService(),
        contactChecker: any ContactChecking = ExtensionContactStore()
    ) {
        self.selfChecker = selfChecker
        self.contactChecker = contactChecker
    }

    func resolve(rawPublicKeyBase64: String) -> SignerType {
        if (try? selfChecker.isSelfPublicKey(rawBase64: rawPublicKeyBase64)) ?? false {
            return .selfSigned
        }
        if contactChecker.isKnownContact(rawPublicKeyBase64: rawPublicKeyBase64) {
            return .known
        }
        return .unknown
    }
}
