//
//  MockKeychainRepositoryWithCallCount.swift
//  WevoTests
//

import Foundation
@testable import Wevo

/// Wraps a `MockKeychainRepository` and returns different `verifySignature` results per call,
/// forwarding everything else unchanged. Composition rather than subclassing, so this type's
/// isolation doesn't have to match its base's (see ADR 0007).
final class MockKeychainRepositoryWithCallCount: KeychainRepository {
    private let base = MockKeychainRepository()
    var resultsPerCall: [Bool] = []
    private var callIndex = 0

    var verifySignatureError: Error? {
        get { base.verifySignatureError }
        set { base.verifySignatureError = newValue }
    }

    func createIdentity(id: UUID, nickname: String, privateKey: Data) throws {
        try base.createIdentity(id: id, nickname: nickname, privateKey: privateKey)
    }

    func getAllIdentities() throws -> [Identity] {
        try base.getAllIdentities()
    }

    func getIdentity(id: UUID) throws -> Identity {
        try base.getIdentity(id: id)
    }

    func getPrivateKey(id: UUID) throws -> Data {
        try base.getPrivateKey(id: id)
    }

    func updateNickname(id: UUID, newNickname: String) throws {
        try base.updateNickname(id: id, newNickname: newNickname)
    }

    func deleteIdentityKey(id: UUID) throws {
        try base.deleteIdentityKey(id: id)
    }

    func deleteAllIdentityKeys() throws {
        try base.deleteAllIdentityKeys()
    }

    func migrateKey(id: UUID) throws {
        try base.migrateKey(id: id)
    }

    func signMessage(_ message: String, withIdentityId identityId: UUID) throws -> String {
        try base.signMessage(message, withIdentityId: identityId)
    }

    func verifySignature(_ signature: String, for message: String, withPublicKeyString publicKeyString: String) throws -> Bool {
        if let error = verifySignatureError { throw error }
        defer { callIndex += 1 }
        guard callIndex < resultsPerCall.count else { return base.verifySignatureResult }
        return resultsPerCall[callIndex]
    }
}
