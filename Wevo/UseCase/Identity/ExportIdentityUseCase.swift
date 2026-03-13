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
        let base64 = privateKeyData.base64EncodedString()
        let url = try IdentityPlainTransfer.exportPlainToFile(identity: identity, privateKeyBase64: base64)
        return url
    }
}
