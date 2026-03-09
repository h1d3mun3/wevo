//
//  DeleteIdentityUseCase.swift
//  Wevo
//
//  Created by hidemune on 3/9/26.
//

import Foundation

protocol DeleteIdentityUseCase {
    func execute(id: UUID) throws
}

struct DeleteIdentityUseCaseImpl {
    let keychainRepository: KeychainRepository

    init(keychainRepository: KeychainRepository) {
        self.keychainRepository = keychainRepository
    }
}

extension DeleteIdentityUseCaseImpl: DeleteIdentityUseCase {
    func execute(id: UUID) throws {
        try keychainRepository.deleteIdentityKey(id: id)
    }
}
