//
//  ExportIdentityUseCase.swift
//  Wevo
//
//  Created on 3/11/26.
//

import Foundation

protocol ExportIdentityUseCase {
    func execute(identity: Identity, passphrase: String) throws -> URL
}

struct ExportIdentityUseCaseImpl: ExportIdentityUseCase {
    let keychainRepository: KeychainRepository

    /// Exports the identity as a passphrase-encrypted `.wevo-identity` envelope. The private key
    /// is AES-GCM sealed under a PBKDF2 key derived from `passphrase`; metadata stays cleartext.
    func execute(identity: Identity, passphrase: String) throws -> URL {
        let privateKeyData = try keychainRepository.getPrivateKey(id: identity.id)
        let (salt, sealed) = try IdentityExportCrypto.encrypt(privateKeyData, passphrase: passphrase)

        let export = IdentityEncryptedExport(
            version: IdentityEncryptedExport.currentVersion,
            id: identity.id,
            nickname: identity.nickname,
            publicKey: identity.publicKey,
            exportedAt: Date(),
            kdf: IdentityEncryptedExport.kdfName,
            iterations: IdentityExportCrypto.iterations,
            salt: salt.base64EncodedString(),
            sealed: sealed.base64EncodedString()
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(export)
        let fileName = "identity-\(identity.id.uuidString).wevo-identity"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        // Unreadable while the device is locked; the plaintext key never touches disk.
        try data.write(to: url, options: [.completeFileProtection, .atomic])
        return url
    }
}
