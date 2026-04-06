//
//  ExportIdentityUseCase.swift
//  Wevo
//
//  Created on 3/11/26.
//

import Foundation

protocol ExportIdentityUseCase {
    func execute(identity: Identity) throws -> URL
}

struct ExportIdentityUseCaseImpl: ExportIdentityUseCase {
    let keychainRepository: KeychainRepository

    func execute(identity: Identity) throws -> URL {
        let privateKeyData = try keychainRepository.getPrivateKey(id: identity.id)
        let export = IdentityPlainExport(
            id: identity.id,
            nickname: identity.nickname,
            publicKey: identity.publicKey,
            privateKey: privateKeyData.base64EncodedString(),
            exportedAt: Date()
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(export)
        let fileName = "identity-\(identity.id.uuidString).wevo-identity"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        try data.write(to: url)
        return url
    }
}
