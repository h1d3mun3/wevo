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
    func readFromFile(url: URL) throws -> IdentityPlainExport
    func execute(exportData: IdentityPlainExport) throws
}

struct ImportIdentityFromExportUseCaseImpl: ImportIdentityFromExportUseCase {
    let keychainRepository: KeychainRepository

    func execute(exportData: IdentityPlainExport) throws {
        // Delete existing Identity if present
        do {
            _ = try keychainRepository.getIdentity(id: exportData.id)
            try keychainRepository.deleteIdentityKey(id: exportData.id)
        } catch {
            // Not found or not deletable; continue
        }

        // Base64 decode
        guard let privateKeyData = Data(base64Encoded: exportData.privateKey) else {
            throw ImportIdentityFromExportUseCaseError.invalidPrivateKeyEncoding
        }

        // Validate as a P256 private key
        do {
            _ = try P256.Signing.PrivateKey(rawRepresentation: privateKeyData)
        } catch {
            throw ImportIdentityFromExportUseCaseError.invalidPrivateKeyFormat
        }

        // Import
        try keychainRepository.createIdentity(
            id: exportData.id,
            nickname: exportData.nickname,
            privateKey: privateKeyData
        )
    }

    func readFromFile(url: URL) throws -> IdentityPlainExport {
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(IdentityPlainExport.self, from: data)
    }
}
