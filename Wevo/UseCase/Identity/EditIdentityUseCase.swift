//
//  EditIdentityUseCase.swift
//  Wevo
//
//  Created by hidemune on 3/9/26.
//

import Foundation
import CryptoKit

protocol EditIdentityUseCase {
    func execute(id: UUID, newNickname: String) throws
}

struct EditIdentityUseCaseImpl {
    private let keychainRepository: KeychainRepository
    
    init(keychainRepository: KeychainRepository) {
        self.keychainRepository = keychainRepository
    }
}

extension EditIdentityUseCaseImpl: EditIdentityUseCase {
    func execute(id: UUID, newNickname: String) throws {
        let trimmedNickname = newNickname.trimmingCharacters(in: .whitespacesAndNewlines)
        try KeychainRepositoryImpl().updateNickname(id: id, newNickname: trimmedNickname)
    }
}
