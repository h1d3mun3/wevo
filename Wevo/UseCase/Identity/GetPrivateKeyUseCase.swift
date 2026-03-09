//
//  GetPrivateKeyUseCase.swift
//  Wevo
//
//  Created by hidemune on 3/9/26.
//

import Foundation
import LocalAuthentication

protocol GetPrivateKeyUseCase {
    func execute(id: UUID, context: LAContext?) throws -> Data
}

struct GetPrivateKeyUseCaseImpl {
    private let keychainRepository: KeychainRepository

    init(keychainRepository: KeychainRepository) {
        self.keychainRepository = keychainRepository
    }
}

extension GetPrivateKeyUseCaseImpl: GetPrivateKeyUseCase {
    func execute(id: UUID, context: LAContext? = nil) throws -> Data {
        try keychainRepository.getPrivateKey(id: id, context: context)
    }
}
