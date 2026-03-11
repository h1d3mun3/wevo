//
//  ExportIdentityUseCaseTests.swift
//  WevoTests
//
//  Created on 3/11/26.
//

import Testing
import Foundation
@testable import Wevo

@MainActor
struct ExportIdentityUseCaseTests {

    let mockKeychainRepository = MockKeychainRepository()

    let identity = Identity(
        id: UUID(),
        nickname: "Test Key",
        publicKey: "TestPublicKey"
    )

    @Test("秘密鍵を取得してBase64エンコードしファイルにエクスポートできる")
    func executeSuccess() throws {
        let privateKeyData = Data("test-private-key".utf8)
        mockKeychainRepository.getPrivateKeyResult = privateKeyData

        let useCase = ExportIdentityUseCaseImpl(keychainRepository: mockKeychainRepository)
        let url = try useCase.execute(identity: identity)

        #expect(url.pathExtension == "wevo-identity")
        #expect(FileManager.default.fileExists(atPath: url.path))

        // ファイル内容にBase64エンコードされた秘密鍵が含まれる
        let data = try Data(contentsOf: url)
        let fileContent = String(data: data, encoding: .utf8)!
        #expect(fileContent.contains(privateKeyData.base64EncodedString()))

        // クリーンアップ
        try? FileManager.default.removeItem(at: url)
    }

    @Test("秘密鍵の取得に失敗した場合エラーが返る")
    func executeFailsWhenPrivateKeyNotFound() {
        mockKeychainRepository.getPrivateKeyError = KeychainError.itemNotFound

        let useCase = ExportIdentityUseCaseImpl(keychainRepository: mockKeychainRepository)

        #expect(throws: KeychainError.self) {
            _ = try useCase.execute(identity: identity)
        }
    }
}
