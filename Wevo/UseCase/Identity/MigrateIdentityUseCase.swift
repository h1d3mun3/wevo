//
//  MigrateIdentityUseCase.swift
//  Wevo
//
//  Created by hidemune on 3/9/26.
//

import Foundation

protocol MigrateIdentityUseCase {
    func execute(id: UUID) throws
}

struct MigrateIdentityUseCaseImpl {
    let keychainRepository: KeychainRepository

    init(keychainRepository: KeychainRepository) {
        self.keychainRepository = keychainRepository
    }
}

extension MigrateIdentityUseCaseImpl: MigrateIdentityUseCase {
    func execute(id: UUID) throws {
        try keychainRepository.migrateKey(id: id)
    }
}
