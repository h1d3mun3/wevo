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
    case unsupportedFormat
    case legacyPlaintextUnsupported
    case decryptionFailed

    var errorDescription: String? {
        switch self {
        case .invalidPrivateKeyEncoding:
            return "Invalid private key encoding."
        case .invalidPrivateKeyFormat:
            return "Invalid private key format. Not a valid P256 key."
        case .unsupportedFormat:
            return "Unrecognized or unsupported .wevo-identity format."
        case .legacyPlaintextUnsupported:
            return "This is an old, unencrypted identity export and can no longer be imported. Please re-export it from an updated version of the app."
        case .decryptionFailed:
            return "Could not decrypt. The passphrase is incorrect or the file is corrupted."
        }
    }
}

protocol ImportIdentityFromExportUseCase {
    func readFromFile(url: URL) throws -> IdentityEncryptedExport
    func execute(exportData: IdentityEncryptedExport, passphrase: String) throws
}

struct ImportIdentityFromExportUseCaseImpl: ImportIdentityFromExportUseCase {
    let keychainRepository: KeychainRepository

    func execute(exportData: IdentityEncryptedExport, passphrase: String) throws {
        // Decode the encrypted envelope's fields.
        guard let salt = Data(base64Encoded: exportData.salt),
              let sealed = Data(base64Encoded: exportData.sealed) else {
            throw ImportIdentityFromExportUseCaseError.invalidPrivateKeyEncoding
        }

        // Decrypt the private key. A wrong passphrase or any tampering fails AES-GCM authentication.
        let privateKeyData: Data
        do {
            privateKeyData = try IdentityExportCrypto.decrypt(
                sealed: sealed, salt: salt, iterations: exportData.iterations, passphrase: passphrase
            )
        } catch {
            throw ImportIdentityFromExportUseCaseError.decryptionFailed
        }

        // Validate as a P256 private key.
        do {
            _ = try P256.Signing.PrivateKey(rawRepresentation: privateKeyData)
        } catch {
            throw ImportIdentityFromExportUseCaseError.invalidPrivateKeyFormat
        }

        // Delete existing Identity if present, then import.
        do {
            _ = try keychainRepository.getIdentity(id: exportData.id)
            try keychainRepository.deleteIdentityKey(id: exportData.id)
        } catch {
            // Not found or not deletable; continue
        }
        try keychainRepository.createIdentity(
            id: exportData.id,
            nickname: exportData.nickname,
            privateKey: privateKeyData
        )
    }

    func readFromFile(url: URL) throws -> IdentityEncryptedExport {
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        if let export = try? decoder.decode(IdentityEncryptedExport.self, from: data),
           export.version == IdentityEncryptedExport.currentVersion,
           export.kdf == IdentityEncryptedExport.kdfName {
            return export
        }
        // Give a clear message for the old plaintext format instead of a generic decode error.
        if (try? decoder.decode(IdentityPlainExport.self, from: data)) != nil {
            throw ImportIdentityFromExportUseCaseError.legacyPlaintextUnsupported
        }
        throw ImportIdentityFromExportUseCaseError.unsupportedFormat
    }
}
