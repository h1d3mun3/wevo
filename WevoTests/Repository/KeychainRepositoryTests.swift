//
//  KeychainRepositoryTests.swift
//  WevoTests
//

import Testing
import Foundation
import CryptoKit
@testable import Wevo

@Suite(.serialized)
struct KeychainRepositoryTests {

    private func makeRepository() -> KeychainRepositoryImpl {
        KeychainRepositoryImpl()
    }

    private func makePrivateKey() -> P256.Signing.PrivateKey {
        P256.Signing.PrivateKey()
    }

    /// テスト後にKeychainをクリーンアップするヘルパー
    private func cleanUp(repo: KeychainRepositoryImpl, ids: [UUID]) {
        for id in ids {
            try? repo.deleteIdentityKey(id: id)
        }
    }

    // MARK: - CreateIdentity

    @Test func testCreateIdentityAndGetIdentity() throws {
        let repo = makeRepository()
        let id = UUID()
        let key = makePrivateKey()

        defer { cleanUp(repo: repo, ids: [id]) }

        try repo.createIdentity(id: id, nickname: "Alice", privateKey: key.rawRepresentation)

        let identity = try repo.getIdentity(id: id)
        #expect(identity.id == id)
        #expect(identity.nickname == "Alice")
        #expect(!identity.publicKey.isEmpty)
    }

    @Test func testCreateIdentityDuplicateThrows() throws {
        let repo = makeRepository()
        let id = UUID()
        let key = makePrivateKey()

        defer { cleanUp(repo: repo, ids: [id]) }

        try repo.createIdentity(id: id, nickname: "Alice", privateKey: key.rawRepresentation)

        #expect(throws: KeychainError.self) {
            try repo.createIdentity(id: id, nickname: "Alice", privateKey: key.rawRepresentation)
        }
    }

    // MARK: - GetAllIdentities

    @Test func testGetAllIdentitiesReturnsCreatedIdentities() throws {
        let repo = makeRepository()
        let id1 = UUID()
        let id2 = UUID()
        let key1 = makePrivateKey()
        let key2 = makePrivateKey()

        defer { cleanUp(repo: repo, ids: [id1, id2]) }

        try repo.createIdentity(id: id1, nickname: "Alice", privateKey: key1.rawRepresentation)
        try repo.createIdentity(id: id2, nickname: "Bob", privateKey: key2.rawRepresentation)

        let all = try repo.getAllIdentities()
        let ids = all.map(\.id)

        #expect(ids.contains(id1))
        #expect(ids.contains(id2))
    }

    // MARK: - GetIdentity

    @Test func testGetIdentityThrowsWhenNotFound() throws {
        let repo = makeRepository()

        #expect(throws: KeychainError.self) {
            try repo.getIdentity(id: UUID())
        }
    }

    // MARK: - GetPrivateKey

    @Test func testGetPrivateKeyReturnsCorrectKey() throws {
        let repo = makeRepository()
        let id = UUID()
        let key = makePrivateKey()

        defer { cleanUp(repo: repo, ids: [id]) }

        try repo.createIdentity(id: id, nickname: "Alice", privateKey: key.rawRepresentation)

        let retrievedKey = try repo.getPrivateKey(id: id)
        #expect(retrievedKey == key.rawRepresentation)
    }

    @Test func testGetPrivateKeyThrowsWhenNotFound() throws {
        let repo = makeRepository()

        #expect(throws: KeychainError.self) {
            try repo.getPrivateKey(id: UUID())
        }
    }

    // MARK: - UpdateNickname

    @Test func testUpdateNicknameChangesNickname() throws {
        let repo = makeRepository()
        let id = UUID()
        let key = makePrivateKey()

        defer { cleanUp(repo: repo, ids: [id]) }

        try repo.createIdentity(id: id, nickname: "Alice", privateKey: key.rawRepresentation)
        try repo.updateNickname(id: id, newNickname: "Bob")

        let identity = try repo.getIdentity(id: id)
        #expect(identity.nickname == "Bob")
    }

    @Test func testUpdateNicknameThrowsWhenNotFound() throws {
        let repo = makeRepository()

        #expect(throws: KeychainError.self) {
            try repo.updateNickname(id: UUID(), newNickname: "Bob")
        }
    }

    // MARK: - DeleteIdentityKey

    @Test func testDeleteIdentityKeyRemovesIdentity() throws {
        let repo = makeRepository()
        let id = UUID()
        let key = makePrivateKey()

        try repo.createIdentity(id: id, nickname: "Alice", privateKey: key.rawRepresentation)
        try repo.deleteIdentityKey(id: id)

        #expect(throws: KeychainError.self) {
            try repo.getIdentity(id: id)
        }
    }

    @Test func testDeleteIdentityKeyAlsoRemovesPrivateKey() throws {
        let repo = makeRepository()
        let id = UUID()
        let key = makePrivateKey()

        try repo.createIdentity(id: id, nickname: "Alice", privateKey: key.rawRepresentation)
        try repo.deleteIdentityKey(id: id)

        #expect(throws: KeychainError.self) {
            try repo.getPrivateKey(id: UUID())
        }
    }

    // MARK: - DeleteAllIdentityKeys

    @Test func testDeleteAllIdentityKeysRemovesAll() throws {
        let repo = makeRepository()
        let id1 = UUID()
        let id2 = UUID()
        let key1 = makePrivateKey()
        let key2 = makePrivateKey()

        try repo.createIdentity(id: id1, nickname: "Alice", privateKey: key1.rawRepresentation)
        try repo.createIdentity(id: id2, nickname: "Bob", privateKey: key2.rawRepresentation)

        try repo.deleteAllIdentityKeys()

        // 作成したIdentityが取得できないことを確認
        #expect(throws: KeychainError.self) {
            try repo.getIdentity(id: id1)
        }
        #expect(throws: KeychainError.self) {
            try repo.getIdentity(id: id2)
        }
    }

    // MARK: - SignMessage & VerifySignature

    @Test func testSignAndVerifyRoundTrip() throws {
        let repo = makeRepository()
        let id = UUID()
        let key = makePrivateKey()

        defer { cleanUp(repo: repo, ids: [id]) }

        try repo.createIdentity(id: id, nickname: "Alice", privateKey: key.rawRepresentation)

        let message = "Hello, World!"
        let signature = try repo.signMessage(message, withIdentityId: id)

        // 公開鍵文字列で検証
        let publicKeyString = key.publicKey.x963Representation.base64EncodedString()
        let isValid = try repo.verifySignature(signature, for: message, withPublicKeyString: publicKeyString)

        #expect(isValid)
    }

    @Test func testVerifySignatureReturnsFalseForWrongMessage() throws {
        let repo = makeRepository()
        let id = UUID()
        let key = makePrivateKey()

        defer { cleanUp(repo: repo, ids: [id]) }

        try repo.createIdentity(id: id, nickname: "Alice", privateKey: key.rawRepresentation)

        let signature = try repo.signMessage("original", withIdentityId: id)

        let publicKeyString = key.publicKey.x963Representation.base64EncodedString()
        let isValid = try repo.verifySignature(signature, for: "tampered", withPublicKeyString: publicKeyString)

        #expect(!isValid)
    }

    @Test func testVerifySignatureReturnsFalseForWrongKey() throws {
        let repo = makeRepository()
        let id = UUID()
        let key = makePrivateKey()
        let wrongKey = makePrivateKey()

        defer { cleanUp(repo: repo, ids: [id]) }

        try repo.createIdentity(id: id, nickname: "Alice", privateKey: key.rawRepresentation)

        let message = "Hello"
        let signature = try repo.signMessage(message, withIdentityId: id)

        let wrongPublicKeyString = wrongKey.publicKey.x963Representation.base64EncodedString()
        let isValid = try repo.verifySignature(signature, for: message, withPublicKeyString: wrongPublicKeyString)

        #expect(!isValid)
    }

    @Test func testVerifySignatureWithInvalidBase64Throws() throws {
        let repo = makeRepository()

        #expect(throws: KeychainError.self) {
            try repo.verifySignature("not-valid-base64!!!", for: "message", withPublicKeyString: "also-invalid!!!")
        }
    }

    // MARK: - MigrateKey

    @Test func testMigrateKeyPreservesIdentity() throws {
        let repo = makeRepository()
        let id = UUID()
        let key = makePrivateKey()

        defer { cleanUp(repo: repo, ids: [id]) }

        try repo.createIdentity(id: id, nickname: "Alice", privateKey: key.rawRepresentation)
        try repo.migrateKey(id: id)

        let identity = try repo.getIdentity(id: id)
        #expect(identity.id == id)
        #expect(identity.nickname == "Alice")

        let retrievedKey = try repo.getPrivateKey(id: id)
        #expect(retrievedKey == key.rawRepresentation)
    }
}
