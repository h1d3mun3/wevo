//
//  ImportIdentityFromExportUseCaseTests.swift
//  WevoTests
//
//  Created on 3/11/26.
//

import Testing
import Foundation
import CryptoKit
@testable import Wevo

@MainActor
struct ImportIdentityFromExportUseCaseTests {

    let mockKeychainRepository = MockKeychainRepository()

    /// Generates a valid P256 private key Base64 string
    static func validPrivateKeyBase64() -> String {
        let key = P256.Signing.PrivateKey()
        return key.rawRepresentation.base64EncodedString()
    }

    @Test("Can import successfully when no existing identity")
    func executeSuccess() throws {
        mockKeychainRepository.getIdentityError = KeychainError.itemNotFound

        let exportData = IdentityPlainExport(
            id: UUID(),
            nickname: "Test Key",
            publicKey: "TestPublicKey",
            privateKey: Self.validPrivateKeyBase64(),
            exportedAt: .now
        )

        let useCase = ImportIdentityFromExportUseCaseImpl(keychainRepository: mockKeychainRepository)
        try useCase.execute(exportData: exportData, overwriteConfirmed: false)

        #expect(mockKeychainRepository.createIdentityCalled)
        #expect(mockKeychainRepository.createdIdentityID == exportData.id)
        #expect(mockKeychainRepository.createdNickname == exportData.nickname)
    }

    @Test("Replaces existing identity only when overwrite is confirmed")
    func executeOverwritesExistingWhenConfirmed() throws {
        let id = UUID()
        mockKeychainRepository.getIdentityResult = Identity(id: id, nickname: "Old Key", publicKey: "OldPublicKey")

        let exportData = IdentityPlainExport(
            id: id,
            nickname: "New Key",
            publicKey: "NewPublicKey",
            privateKey: Self.validPrivateKeyBase64(),
            exportedAt: .now
        )

        let useCase = ImportIdentityFromExportUseCaseImpl(keychainRepository: mockKeychainRepository)
        try useCase.execute(exportData: exportData, overwriteConfirmed: true)

        #expect(mockKeychainRepository.deleteIdentityKeyCalled)
        #expect(mockKeychainRepository.deletedIdentityID == id)
        #expect(mockKeychainRepository.createIdentityCalled)
    }

    @Test("Throws (and does not overwrite) when an identity exists and overwrite is not confirmed")
    func executeThrowsWhenExistsWithoutConfirmation() {
        let id = UUID()
        mockKeychainRepository.getIdentityResult = Identity(id: id, nickname: "Old Key", publicKey: "OldPublicKey")

        let exportData = IdentityPlainExport(
            id: id,
            nickname: "New Key",
            publicKey: "NewPublicKey",
            privateKey: Self.validPrivateKeyBase64(),
            exportedAt: .now
        )

        let useCase = ImportIdentityFromExportUseCaseImpl(keychainRepository: mockKeychainRepository)

        #expect(throws: ImportIdentityFromExportUseCaseError.identityAlreadyExists) {
            try useCase.execute(exportData: exportData, overwriteConfirmed: false)
        }
        #expect(!mockKeychainRepository.deleteIdentityKeyCalled)
        #expect(!mockKeychainRepository.createIdentityCalled)
    }

    @Test("Returns error when Base64 decoding fails")
    func executeFailsWithInvalidBase64() {
        mockKeychainRepository.getIdentityError = KeychainError.itemNotFound

        let exportData = IdentityPlainExport(
            id: UUID(),
            nickname: "Test",
            publicKey: "PK",
            privateKey: "!!!invalid-base64!!!",
            exportedAt: .now
        )

        let useCase = ImportIdentityFromExportUseCaseImpl(keychainRepository: mockKeychainRepository)

        #expect(throws: ImportIdentityFromExportUseCaseError.invalidPrivateKeyEncoding) {
            try useCase.execute(exportData: exportData, overwriteConfirmed: false)
        }
    }

    @Test("Returns error when data is invalid as P256 key")
    func executeFailsWithInvalidP256Key() {
        mockKeychainRepository.getIdentityError = KeychainError.itemNotFound

        let exportData = IdentityPlainExport(
            id: UUID(),
            nickname: "Test",
            publicKey: "PK",
            privateKey: Data("not-a-valid-p256-key".utf8).base64EncodedString(),
            exportedAt: .now
        )

        let useCase = ImportIdentityFromExportUseCaseImpl(keychainRepository: mockKeychainRepository)

        #expect(throws: ImportIdentityFromExportUseCaseError.invalidPrivateKeyFormat) {
            try useCase.execute(exportData: exportData, overwriteConfirmed: false)
        }
    }

    @Test("Does not delete an existing identity when the import is invalid")
    func executeDoesNotDeleteOnInvalidImport() {
        let id = UUID()
        mockKeychainRepository.getIdentityResult = Identity(id: id, nickname: "Old", publicKey: "OldPK")

        let exportData = IdentityPlainExport(
            id: id,
            nickname: "Test",
            publicKey: "PK",
            privateKey: "!!!invalid-base64!!!",
            exportedAt: .now
        )

        let useCase = ImportIdentityFromExportUseCaseImpl(keychainRepository: mockKeychainRepository)

        #expect(throws: ImportIdentityFromExportUseCaseError.invalidPrivateKeyEncoding) {
            try useCase.execute(exportData: exportData, overwriteConfirmed: true)
        }
        // The existing identity must remain untouched when the incoming data is invalid.
        #expect(!mockKeychainRepository.deleteIdentityKeyCalled)
        #expect(!mockKeychainRepository.createIdentityCalled)
    }

    @Test("Private key Data is correctly decoded and passed to createIdentity")
    func executeDecodesPrivateKeyCorrectly() throws {
        mockKeychainRepository.getIdentityError = KeychainError.itemNotFound

        let base64 = Self.validPrivateKeyBase64()
        let exportData = IdentityPlainExport(
            id: UUID(),
            nickname: "Test Key",
            publicKey: "PK",
            privateKey: base64,
            exportedAt: .now
        )

        let useCase = ImportIdentityFromExportUseCaseImpl(keychainRepository: mockKeychainRepository)
        try useCase.execute(exportData: exportData, overwriteConfirmed: false)

        let expectedData = Data(base64Encoded: base64)
        #expect(mockKeychainRepository.createdPrivateKey == expectedData)
    }
}
