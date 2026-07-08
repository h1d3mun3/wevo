//
//  ExportIdentityUseCaseTests.swift
//  WevoTests
//

import Testing
import Foundation
import CryptoKit
@testable import Wevo

@MainActor
struct ExportIdentityUseCaseTests {

    let mockKeychainRepository = MockKeychainRepository()

    let identity = Identity(
        id: UUID(),
        nickname: "Test Key",
        publicKey: "TestPublicKey"
    )

    @Test("Exports an encrypted envelope that does NOT contain the plaintext private key")
    func executeProducesEncryptedFile() throws {
        let privateKeyData = P256.Signing.PrivateKey().rawRepresentation
        mockKeychainRepository.getPrivateKeyResult = privateKeyData

        let useCase = ExportIdentityUseCaseImpl(keychainRepository: mockKeychainRepository)
        let url = try useCase.execute(identity: identity, passphrase: "correct-horse-battery")
        defer { try? FileManager.default.removeItem(at: url) }

        #expect(url.pathExtension == "wevo-identity")
        #expect(FileManager.default.fileExists(atPath: url.path))

        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let export = try decoder.decode(IdentityEncryptedExport.self, from: data)
        #expect(export.version == IdentityEncryptedExport.currentVersion)
        #expect(export.id == identity.id)
        #expect(export.publicKey == identity.publicKey)

        // The plaintext private key must not appear anywhere in the file.
        let content = String(data: data, encoding: .utf8)!
        #expect(!content.contains(privateKeyData.base64EncodedString()))
    }

    @Test("Round-trips: export then decrypt recovers the same private key")
    func exportRoundTrips() throws {
        let privateKeyData = P256.Signing.PrivateKey().rawRepresentation
        mockKeychainRepository.getPrivateKeyResult = privateKeyData

        let url = try ExportIdentityUseCaseImpl(keychainRepository: mockKeychainRepository)
            .execute(identity: identity, passphrase: "s3cr3t-pass")
        defer { try? FileManager.default.removeItem(at: url) }

        let export = try ImportIdentityFromExportUseCaseImpl(keychainRepository: mockKeychainRepository)
            .readFromFile(url: url)
        let salt = Data(base64Encoded: export.salt)!
        let sealed = Data(base64Encoded: export.sealed)!
        let recovered = try IdentityExportCrypto.decrypt(
            sealed: sealed, salt: salt, iterations: export.iterations, passphrase: "s3cr3t-pass"
        )
        #expect(recovered == privateKeyData)
    }

    @Test("Returns error when private key retrieval fails")
    func executeFailsWhenPrivateKeyNotFound() {
        mockKeychainRepository.getPrivateKeyError = KeychainError.itemNotFound

        let useCase = ExportIdentityUseCaseImpl(keychainRepository: mockKeychainRepository)

        #expect(throws: KeychainError.self) {
            _ = try useCase.execute(identity: identity, passphrase: "whatever")
        }
    }
}
