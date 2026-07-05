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
        let export = IdentityEncryptedExport(
            version: IdentityEncryptedExport.currentVersion,
            id: id,
            nickname: nickname,
            publicKey: "PK",
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
        let (export, priv) = try Self.makeEncryptedExport(passphrase: "pass1234")

        try ImportIdentityFromExportUseCaseImpl(keychainRepository: mockKeychainRepository)
            .execute(exportData: export, passphrase: "pass1234")

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
                .execute(exportData: export, passphrase: "wrong-pass")
        }
        #expect(!mockKeychainRepository.createIdentityCalled)
    }

    @Test("Tampered ciphertext fails AES-GCM authentication")
    func executeFailsWhenTampered() throws {
        mockKeychainRepository.getIdentityError = KeychainError.itemNotFound
        let (original, _) = try Self.makeEncryptedExport(passphrase: "pass1234")
        var sealed = Data(base64Encoded: original.sealed)!
        sealed[sealed.count - 1] ^= 0xFF  // flip a byte of the tag/ciphertext
        let tampered = IdentityEncryptedExport(
            version: original.version, id: original.id, nickname: original.nickname,
            publicKey: original.publicKey, exportedAt: original.exportedAt, kdf: original.kdf,
            iterations: original.iterations, salt: original.salt, sealed: sealed.base64EncodedString()
        )

        #expect(throws: ImportIdentityFromExportUseCaseError.decryptionFailed) {
            try ImportIdentityFromExportUseCaseImpl(keychainRepository: mockKeychainRepository)
                .execute(exportData: tampered, passphrase: "pass1234")
        }
    }

    @Test("Decrypts but rejects non-P256 key material")
    func executeFailsWithInvalidP256Key() throws {
        mockKeychainRepository.getIdentityError = KeychainError.itemNotFound
        // 16 bytes decrypt fine but are not a valid 32-byte P256 raw key.
        let (export, _) = try Self.makeEncryptedExport(passphrase: "pass1234", privateKey: Data(repeating: 0x01, count: 16))

        #expect(throws: ImportIdentityFromExportUseCaseError.invalidPrivateKeyFormat) {
            try ImportIdentityFromExportUseCaseImpl(keychainRepository: mockKeychainRepository)
                .execute(exportData: export, passphrase: "pass1234")
        }
    }

    @Test("Deletes existing Identity before importing when one exists")
    func executeOverwritesExisting() throws {
        let id = UUID()
        mockKeychainRepository.getIdentityResult = Identity(id: id, nickname: "Old Key", publicKey: "OldPublicKey")
        let (export, _) = try Self.makeEncryptedExport(id: id, nickname: "New Key", passphrase: "pass1234")

        try ImportIdentityFromExportUseCaseImpl(keychainRepository: mockKeychainRepository)
            .execute(exportData: export, passphrase: "pass1234")

        #expect(mockKeychainRepository.deleteIdentityKeyCalled)
        #expect(mockKeychainRepository.deletedIdentityID == id)
        #expect(mockKeychainRepository.createIdentityCalled)
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
        let (export, _) = try Self.makeEncryptedExport(passphrase: "pass1234")
        let encoder = JSONEncoder(); encoder.dateEncodingStrategy = .iso8601
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("enc-\(UUID()).wevo-identity")
        try encoder.encode(export).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        let read = try ImportIdentityFromExportUseCaseImpl(keychainRepository: mockKeychainRepository).readFromFile(url: url)
        #expect(read.id == export.id)
        #expect(read.version == IdentityEncryptedExport.currentVersion)
    }
}
