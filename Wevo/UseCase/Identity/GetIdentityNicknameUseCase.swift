//
//  GetIdentityNicknameUseCase.swift
//  Wevo
//
//  Created on 3/11/26.
//

import Foundation

protocol GetIdentityNicknameUseCase {
    func execute(id: UUID) -> String
}

struct GetIdentityNicknameUseCaseImpl: GetIdentityNicknameUseCase {
    let keychainRepository: KeychainRepository

    func execute(id: UUID) -> String {
        do {
            let identity = try keychainRepository.getIdentity(id: id)
            return identity.nickname
        } catch {
            return "Unknown"
        }
    }
}
