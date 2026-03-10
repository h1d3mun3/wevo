//
//  ImportIdentityUseCase.swift
//  Wevo
//
//  Created by hidemune on 3/10/26.
//

import Foundation

protocol ImportIdentityUseCase {
    func execute(id: UUID, nickname: String, privateKey: Data) throws
}

struct ImportIdentityUseCaseImpl {
    let keychainRepository: KeychainRepository

    init(keychainRepository: KeychainRepository) {
        self.keychainRepository = keychainRepository
    }
}

extension ImportIdentityUseCaseImpl: ImportIdentityUseCase {
    func execute(id: UUID, nickname: String, privateKey: Data) throws {
        try keychainRepository.createIdentity(
            id: id,
            nickname: nickname,
            privateKey: privateKey
        )
        print("✅ Identity imported successfully")
        print("ID: \(id)")
        print("Nickname: \(nickname)")
    }
}
