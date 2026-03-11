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

    /// 有効なP256秘密鍵のBase64文字列を生成
    static func validPrivateKeyBase64() -> String {
        let key = P256.Signing.PrivateKey()
        return key.rawRepresentation.base64EncodedString()
    }

    @Test("正常にインポートできる")
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

    @Test("既存のIdentityがある場合は削除してからインポートする")
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

    @Test("Base64デコードに失敗した場合エラーが返る")
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

    @Test("P256として無効なデータの場合エラーが返る")
    func executeFailsWithInvalidP256Key() {
        mockKeychainRepository.getIdentityError = KeychainError.itemNotFound

        let exportData = IdentityPlainExport(
            id: UUID(),
            nickname: "Test",
            publicKey: "PK",
<<<<<<< HEAD
            privateKey: Data("not-a-valid-p256-key".utf8).base64EncodedString(),
=======
            privateKey: Data("short".utf8).base64EncodedString(),
>>>>>>> origin/main
            exportedAt: .now
        )

        let useCase = ImportIdentityFromExportUseCaseImpl(keychainRepository: mockKeychainRepository)

        #expect(throws: ImportIdentityFromExportUseCaseError.invalidPrivateKeyFormat) {
            try useCase.execute(exportData: exportData)
        }
    }

    @Test("秘密鍵のDataが正しくデコードされてcreateIdentityに渡される")
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
