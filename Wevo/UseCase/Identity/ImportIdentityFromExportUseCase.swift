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
    case publicKeyMismatch

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
        case .publicKeyMismatch:
            return "The file is inconsistent: the decrypted key does not match its stated public key."
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
        let privateKey: P256.Signing.PrivateKey
        do {
            privateKey = try P256.Signing.PrivateKey(rawRepresentation: privateKeyData)
        } catch {
            throw ImportIdentityFromExportUseCaseError.invalidPrivateKeyFormat
        }

        // The decrypted key is GCM-authenticated, but the cleartext publicKey is not. Reject if the
        // key does not match the previewed public key, so a tampered envelope cannot import a key
        // under a mismatched identity/preview.
        guard privateKey.publicKey.jwkString == exportData.publicKey else {
            throw ImportIdentityFromExportUseCaseError.publicKeyMismatch
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
            // Bound the untrusted iteration count: prevents a UInt32 overflow trap (crash) and an
            // abusively slow PBKDF2 (CPU/UI DoS) when deriving the key below.
            guard (IdentityExportCrypto.minIterations...IdentityExportCrypto.maxIterations).contains(export.iterations) else {
                throw ImportIdentityFromExportUseCaseError.unsupportedFormat
            }
            return export
        }
        // Give a clear message for the old plaintext format instead of a generic decode error.
        if (try? decoder.decode(IdentityPlainExport.self, from: data)) != nil {
            throw ImportIdentityFromExportUseCaseError.legacyPlaintextUnsupported
        }
        throw ImportIdentityFromExportUseCaseError.unsupportedFormat
    }
}
