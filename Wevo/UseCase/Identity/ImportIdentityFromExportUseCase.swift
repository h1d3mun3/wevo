//
//  ImportIdentityFromExportUseCase.swift
//  Wevo
//
//  Created on 3/11/26.
//

import Foundation
import CryptoKit

enum ImportIdentityFromExportUseCaseError: Error, LocalizedError {
    case invalidPrivateKeyEncoding
    case invalidPrivateKeyFormat

    var errorDescription: String? {
        switch self {
        case .invalidPrivateKeyEncoding:
            return "Invalid private key encoding."
        case .invalidPrivateKeyFormat:
            return "Invalid private key format. Not a valid P256 key."
        }
    }
}

protocol ImportIdentityFromExportUseCase {
    func execute(exportData: IdentityPlainExport) throws
}

struct ImportIdentityFromExportUseCaseImpl: ImportIdentityFromExportUseCase {
    let keychainRepository: KeychainRepository

    func execute(exportData: IdentityPlainExport) throws {
        // 既存のIdentityがあれば削除
        do {
            _ = try keychainRepository.getIdentity(id: exportData.id)
            try keychainRepository.deleteIdentityKey(id: exportData.id)
        } catch {
            // Not found or not deletable; continue
        }

        // Base64デコード
        guard let privateKeyData = Data(base64Encoded: exportData.privateKey) else {
            throw ImportIdentityFromExportUseCaseError.invalidPrivateKeyEncoding
        }

        // P256秘密鍵として有効か検証
        do {
            _ = try P256.Signing.PrivateKey(rawRepresentation: privateKeyData)
        } catch {
            throw ImportIdentityFromExportUseCaseError.invalidPrivateKeyFormat
        }

        // インポート
        try keychainRepository.createIdentity(
            id: exportData.id,
            nickname: exportData.nickname,
            privateKey: privateKeyData
        )
    }
}
