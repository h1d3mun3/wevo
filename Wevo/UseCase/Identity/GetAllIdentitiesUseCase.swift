//
//  GetAllIdentityUseCase.swift
//  Wevo
//
//  Created by hidemune on 3/9/26.
//

import Foundation

protocol GetAllIdentitiesUseCase {
    func execute() throws -> [Identity]
}

struct GetAllIdentitiesUseCaseImpl {
    let keychainRepository: KeychainRepository

    init(keychainRepository: KeychainRepository) {
        self.keychainRepository = keychainRepository
    }
}

extension GetAllIdentitiesUseCaseImpl: GetAllIdentitiesUseCase {
    func execute() throws -> [Identity] {
        try keychainRepository.getAllIdentities()
    }
}
