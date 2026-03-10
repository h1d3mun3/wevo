//
//  GetIdentityUseCase.swift
//  Wevo
//
//  Created by hidemune on 3/9/26.
//

import Foundation

protocol GetIdentityUseCase {
    func execute(id: UUID) throws -> Identity
}

struct GetIdentityUseCaseImpl {
    let keychainRepository: KeychainRepository

    init(keychainRepository: KeychainRepository) {
        self.keychainRepository = keychainRepository
    }
}

extension GetIdentityUseCaseImpl: GetIdentityUseCase {
    func execute(id: UUID) throws -> Identity {
        try keychainRepository.getIdentity(id: id)
    }
}

