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

    @Test("Can import successfully")
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
        try useCase.execute(exportData: exportData)

        #expect(mockKeychainRepository.createIdentityCalled)
        #expect(mockKeychainRepository.createdIdentityID == exportData.id)
        #expect(mockKeychainRepository.createdNickname == exportData.nickname)
    }

    @Test("Deletes existing Identity before importing when one exists")
    func executeOverwritesExisting() throws {
        let id = UUID()
        let existingIdentity = Identity(id: id, nickname: "Old Key", publicKey: "OldPublicKey")
        mockKeychainRepository.getIdentityResult = existingIdentity

        let exportData = IdentityPlainExport(
            id: id,
            nickname: "New Key",
            publicKey: "NewPublicKey",
            privateKey: Self.validPrivateKeyBase64(),
            exportedAt: .now
        )

        let useCase = ImportIdentityFromExportUseCaseImpl(keychainRepository: mockKeychainRepository)
        try useCase.execute(exportData: exportData)

        #expect(mockKeychainRepository.deleteIdentityKeyCalled)
        #expect(mockKeychainRepository.deletedIdentityID == id)
        #expect(mockKeychainRepository.createIdentityCalled)
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
            try useCase.execute(exportData: exportData)
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
            try useCase.execute(exportData: exportData)
        }
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
        try useCase.execute(exportData: exportData)

        let expectedData = Data(base64Encoded: base64)
        #expect(mockKeychainRepository.createdPrivateKey == expectedData)
    }
}
