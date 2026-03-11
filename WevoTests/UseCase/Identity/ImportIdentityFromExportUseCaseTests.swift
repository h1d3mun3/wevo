//
//  ImportIdentityFromExportUseCaseTests.swift
//  WevoTests
//
//  Created on 3/11/26.
//

import Testing
import Foundation
@testable import Wevo

@MainActor
struct ImportIdentityFromExportUseCaseTests {

    let mockKeychainRepository = MockKeychainRepository()

    let validExportData = IdentityPlainExport(
        id: UUID(),
        nickname: "Test Key",
        publicKey: "TestPublicKey",
        privateKey: Data("test-private-key".utf8).base64EncodedString(),
        exportedAt: .now
    )

    @Test("正常にインポートできる")
    func executeSuccess() throws {
        mockKeychainRepository.getIdentityError = KeychainError.itemNotFound

        let useCase = ImportIdentityFromExportUseCaseImpl(keychainRepository: mockKeychainRepository)
        try useCase.execute(exportData: validExportData)

        #expect(mockKeychainRepository.createIdentityCalled)
        #expect(mockKeychainRepository.createdIdentityID == validExportData.id)
        #expect(mockKeychainRepository.createdNickname == validExportData.nickname)
    }

    @Test("既存のIdentityがある場合は削除してからインポートする")
    func executeOverwritesExisting() throws {
        let existingIdentity = Identity(
            id: validExportData.id,
            nickname: "Old Key",
            publicKey: "OldPublicKey"
        )
        mockKeychainRepository.getIdentityResult = existingIdentity

        let useCase = ImportIdentityFromExportUseCaseImpl(keychainRepository: mockKeychainRepository)
        try useCase.execute(exportData: validExportData)

        #expect(mockKeychainRepository.deleteIdentityKeyCalled)
        #expect(mockKeychainRepository.deletedIdentityID == validExportData.id)
        #expect(mockKeychainRepository.createIdentityCalled)
    }

    @Test("Base64デコードに失敗した場合エラーが返る")
    func executeFailsWithInvalidBase64() {
        mockKeychainRepository.getIdentityError = KeychainError.itemNotFound

        let invalidExportData = IdentityPlainExport(
            id: UUID(),
            nickname: "Test",
            publicKey: "PK",
            privateKey: "!!!invalid-base64!!!",
            exportedAt: .now
        )

        let useCase = ImportIdentityFromExportUseCaseImpl(keychainRepository: mockKeychainRepository)

        #expect(throws: ImportIdentityFromExportUseCaseError.self) {
            try useCase.execute(exportData: invalidExportData)
        }
    }

    @Test("秘密鍵のDataが正しくデコードされてcreateIdentityに渡される")
    func executeDecodesPrivateKeyCorrectly() throws {
        mockKeychainRepository.getIdentityError = KeychainError.itemNotFound

        let useCase = ImportIdentityFromExportUseCaseImpl(keychainRepository: mockKeychainRepository)
        try useCase.execute(exportData: validExportData)

        let expectedData = Data(base64Encoded: validExportData.privateKey)
        #expect(mockKeychainRepository.createdPrivateKey == expectedData)
    }
}
