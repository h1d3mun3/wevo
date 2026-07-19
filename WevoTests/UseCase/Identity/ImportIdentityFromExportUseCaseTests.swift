//
//  ImportIdentityFromExportUseCaseTests.swift
//  WevoTests
//

import Testing
import Foundation
import CryptoKit
@testable import Wevo

@MainActor
struct ImportIdentityFromExportUseCaseTests {

    let mockKeychainRepository = MockKeychainRepository()

    /// Builds a valid encrypted export for a P256 key sealed with `passphrase`.
    static func makeEncryptedExport(
        id: UUID = UUID(),
        nickname: String = "Test Key",
        passphrase: String,
        privateKey: Data? = nil
    ) throws -> (export: IdentityEncryptedExport, privateKey: Data) {
        let priv = privateKey ?? P256.Signing.PrivateKey().rawRepresentation
        let (salt, sealed) = try IdentityExportCrypto.encrypt(priv, passphrase: passphrase)
        // Derive the matching JWK public key when the material is a valid P256 key (import now
        // verifies the decrypted key against this field); fall back for deliberately-invalid keys.
        let pubJWK = (try? P256.Signing.PrivateKey(rawRepresentation: priv).publicKey.jwkString) ?? "PK"
        let export = IdentityEncryptedExport(
            version: IdentityEncryptedExport.currentVersion,
            id: id,
            nickname: nickname,
            publicKey: pubJWK,
            exportedAt: .now,
            kdf: IdentityEncryptedExport.kdfName,
            iterations: IdentityExportCrypto.iterations,
            salt: salt.base64EncodedString(),
            sealed: sealed.base64EncodedString()
        )
        return (export, priv)
    }

    @Test("Imports successfully with the correct passphrase")
    func executeSuccess() throws {
        mockKeychainRepository.getIdentityError = KeychainError.itemNotFound
        let (export, priv) = try Self.makeEncryptedExport(passphrase: "pass1234abcd")

        try ImportIdentityFromExportUseCaseImpl(keychainRepository: mockKeychainRepository)
            .execute(exportData: export, passphrase: "pass1234abcd", overwriteConfirmed: false)

        #expect(mockKeychainRepository.createIdentityCalled)
        #expect(mockKeychainRepository.createdIdentityID == export.id)
        #expect(mockKeychainRepository.createdNickname == export.nickname)
        #expect(mockKeychainRepository.createdPrivateKey == priv)
    }

    @Test("Wrong passphrase fails with decryptionFailed and does not import")
    func executeFailsWithWrongPassphrase() throws {
        mockKeychainRepository.getIdentityError = KeychainError.itemNotFound
        let (export, _) = try Self.makeEncryptedExport(passphrase: "correct-pass")

        #expect(throws: ImportIdentityFromExportUseCaseError.decryptionFailed) {
            try ImportIdentityFromExportUseCaseImpl(keychainRepository: mockKeychainRepository)
                .execute(exportData: export, passphrase: "wrong-pass", overwriteConfirmed: false)
        }
        #expect(!mockKeychainRepository.createIdentityCalled)
    }

    @Test("Tampered ciphertext fails AES-GCM authentication")
    func executeFailsWhenTampered() throws {
        mockKeychainRepository.getIdentityError = KeychainError.itemNotFound
        let (original, _) = try Self.makeEncryptedExport(passphrase: "pass1234abcd")
        var sealed = Data(base64Encoded: original.sealed)!
        sealed[sealed.count - 1] ^= 0xFF  // flip a byte of the tag/ciphertext
        let tampered = IdentityEncryptedExport(
            version: original.version, id: original.id, nickname: original.nickname,
            publicKey: original.publicKey, exportedAt: original.exportedAt, kdf: original.kdf,
            iterations: original.iterations, salt: original.salt, sealed: sealed.base64EncodedString()
        )

        #expect(throws: ImportIdentityFromExportUseCaseError.decryptionFailed) {
            try ImportIdentityFromExportUseCaseImpl(keychainRepository: mockKeychainRepository)
                .execute(exportData: tampered, passphrase: "pass1234abcd", overwriteConfirmed: false)
        }
    }

    @Test("Decrypts but rejects non-P256 key material")
    func executeFailsWithInvalidP256Key() throws {
        mockKeychainRepository.getIdentityError = KeychainError.itemNotFound
        // 16 bytes decrypt fine but are not a valid 32-byte P256 raw key.
        let (export, _) = try Self.makeEncryptedExport(passphrase: "pass1234abcd", privateKey: Data(repeating: 0x01, count: 16))

        #expect(throws: ImportIdentityFromExportUseCaseError.invalidPrivateKeyFormat) {
            try ImportIdentityFromExportUseCaseImpl(keychainRepository: mockKeychainRepository)
                .execute(exportData: export, passphrase: "pass1234abcd", overwriteConfirmed: false)
        }
    }

    @Test("Replaces an existing Identity only when overwrite is confirmed")
    func executeOverwritesExistingWhenConfirmed() throws {
        let id = UUID()
        mockKeychainRepository.getIdentityResult = Identity(id: id, nickname: "Old Key", publicKey: "OldPublicKey")
        let (export, _) = try Self.makeEncryptedExport(id: id, nickname: "New Key", passphrase: "pass1234abcd")

        try ImportIdentityFromExportUseCaseImpl(keychainRepository: mockKeychainRepository)
            .execute(exportData: export, passphrase: "pass1234abcd", overwriteConfirmed: true)

        #expect(mockKeychainRepository.deleteIdentityKeyCalled)
        #expect(mockKeychainRepository.deletedIdentityID == id)
        #expect(mockKeychainRepository.createIdentityCalled)
    }

    @Test("Throws identityAlreadyExists (and does not overwrite) when one exists and overwrite is not confirmed")
    func executeThrowsWhenExistsWithoutConfirmation() throws {
        let id = UUID()
        mockKeychainRepository.getIdentityResult = Identity(id: id, nickname: "Old Key", publicKey: "OldPublicKey")
        let (export, _) = try Self.makeEncryptedExport(id: id, nickname: "New Key", passphrase: "pass1234abcd")

        let useCase = ImportIdentityFromExportUseCaseImpl(keychainRepository: mockKeychainRepository)
        #expect(throws: ImportIdentityFromExportUseCaseError.identityAlreadyExists) {
            try useCase.execute(exportData: export, passphrase: "pass1234abcd", overwriteConfirmed: false)
        }
        // The existing identity must remain untouched when overwrite is not confirmed.
        #expect(!mockKeychainRepository.deleteIdentityKeyCalled)
        #expect(!mockKeychainRepository.createIdentityCalled)
    }

    @Test("readFromFile rejects the legacy plaintext format (B案)")
    func readFromFileRejectsLegacy() throws {
        let legacy = IdentityPlainExport(id: UUID(), nickname: "Old", publicKey: "PK", privateKey: "AAAA", exportedAt: .now)
        let encoder = JSONEncoder(); encoder.dateEncodingStrategy = .iso8601
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("legacy-\(UUID()).wevo-identity")
        try encoder.encode(legacy).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        #expect(throws: ImportIdentityFromExportUseCaseError.legacyPlaintextUnsupported) {
            _ = try ImportIdentityFromExportUseCaseImpl(keychainRepository: mockKeychainRepository).readFromFile(url: url)
        }
    }

    @Test("readFromFile accepts a valid encrypted envelope")
    func readFromFileAcceptsEncrypted() throws {
        let (export, _) = try Self.makeEncryptedExport(passphrase: "pass1234abcd")
        let encoder = JSONEncoder(); encoder.dateEncodingStrategy = .iso8601
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("enc-\(UUID()).wevo-identity")
        try encoder.encode(export).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        let read = try ImportIdentityFromExportUseCaseImpl(keychainRepository: mockKeychainRepository).readFromFile(url: url)
        #expect(read.id == export.id)
        #expect(read.version == IdentityEncryptedExport.currentVersion)
    }

    @Test("Rejects when the decrypted key does not match the stated publicKey")
    func executeRejectsPublicKeyMismatch() throws {
        mockKeychainRepository.getIdentityError = KeychainError.itemNotFound
        let (valid, _) = try Self.makeEncryptedExport(passphrase: "pass1234abcd")
        // Same ciphertext/salt/passphrase, but a wrong cleartext publicKey.
        let tampered = IdentityEncryptedExport(
            version: valid.version, id: valid.id, nickname: valid.nickname,
            publicKey: "WRONG-PUBLIC-KEY", exportedAt: valid.exportedAt, kdf: valid.kdf,
            iterations: valid.iterations, salt: valid.salt, sealed: valid.sealed
        )

        #expect(throws: ImportIdentityFromExportUseCaseError.publicKeyMismatch) {
            try ImportIdentityFromExportUseCaseImpl(keychainRepository: mockKeychainRepository)
                .execute(exportData: tampered, passphrase: "pass1234abcd", overwriteConfirmed: false)
        }
        #expect(!mockKeychainRepository.createIdentityCalled)
    }

    @Test("readFromFile rejects an out-of-range iteration count (crash / PBKDF2 DoS guard)")
    func readFromFileRejectsBadIterations() throws {
        let (valid, _) = try Self.makeEncryptedExport(passphrase: "pass1234abcd")
        // 5e9 exceeds UInt32.max (would trap in deriveKey) and the accepted range.
        let bad = IdentityEncryptedExport(
            version: valid.version, id: valid.id, nickname: valid.nickname,
            publicKey: valid.publicKey, exportedAt: valid.exportedAt, kdf: valid.kdf,
            iterations: 5_000_000_000, salt: valid.salt, sealed: valid.sealed
        )
        let encoder = JSONEncoder(); encoder.dateEncodingStrategy = .iso8601
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("baditer-\(UUID()).wevo-identity")
        try encoder.encode(bad).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        #expect(throws: ImportIdentityFromExportUseCaseError.unsupportedFormat) {
            _ = try ImportIdentityFromExportUseCaseImpl(keychainRepository: mockKeychainRepository).readFromFile(url: url)
        }
    }
}
