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
    case identityAlreadyExists

    var errorDescription: String? {
        switch self {
        case .invalidPrivateKeyEncoding:
            return "Invalid private key encoding."
        case .invalidPrivateKeyFormat:
            return "Invalid private key format. Not a valid P256 key."
        case .identityAlreadyExists:
            return "An identity with this ID already exists on this device."
        }
    }
}

protocol ImportIdentityFromExportUseCase {
    func readFromFile(url: URL) throws -> IdentityPlainExport
    func execute(exportData: IdentityPlainExport, overwriteConfirmed: Bool) throws
}

struct ImportIdentityFromExportUseCaseImpl: ImportIdentityFromExportUseCase {
    let keychainRepository: KeychainRepository

    func execute(exportData: IdentityPlainExport, overwriteConfirmed: Bool) throws {
        // If an identity with this ID already exists, require explicit confirmation before
        // replacing it — importing must never silently overwrite an existing private key.
        let existing = try? keychainRepository.getIdentity(id: exportData.id)
        if existing != nil, !overwriteConfirmed {
            throw ImportIdentityFromExportUseCaseError.identityAlreadyExists
        }

        // Validate BEFORE deleting anything, so a malformed import can never destroy an existing
        // identity and then fail to replace it.
        guard let privateKeyData = Data(base64Encoded: exportData.privateKey) else {
            throw ImportIdentityFromExportUseCaseError.invalidPrivateKeyEncoding
        }
        do {
            _ = try P256.Signing.PrivateKey(rawRepresentation: privateKeyData)
        } catch {
            throw ImportIdentityFromExportUseCaseError.invalidPrivateKeyFormat
        }

        // Replace the existing key (confirmed above) then import.
        if existing != nil {
            try? keychainRepository.deleteIdentityKey(id: exportData.id)
        }
        try keychainRepository.createIdentity(
            id: exportData.id,
            nickname: exportData.nickname,
            privateKey: privateKeyData
        )
    }

    func readFromFile(url: URL) throws -> IdentityPlainExport {
        let data = try readImportData(from: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(IdentityPlainExport.self, from: data)
    }
}
