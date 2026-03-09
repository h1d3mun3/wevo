//
//  GetAllIdentityUseCase.swift
//  Wevo
//
//  Created by hidemune on 3/9/26.
//

import Foundation

protocol GetAllIdentityUseCase {
    func execute() throws -> [Identity]
}

struct GetAllIdentityUseCaseImpl {
    let keychainRepository: KeychainRepository

    init(keychainRepository: KeychainRepository) {
        self.keychainRepository = keychainRepository
    }
}

extension GetAllIdentityUseCaseImpl: GetAllIdentityUseCase {
    func execute() throws -> [Identity] {
        try keychainRepository.getAllIdentities()
    }
}
